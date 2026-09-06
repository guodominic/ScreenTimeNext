//  SessionController.swift
//  ScreenTimeNextCore
//
//  Task 007. The child session under the session-window model (D-006):
//  a session is a wall-clock window that starts when the child taps Start and lasts for whatever
//  is left of today's budget. Every number the child sees is recomputed from that window and the
//  current time (Rule 4) — never from a Timer's accumulated ticks.
//
//  Accounting rule: the persisted window IS the record of in-flight usage. It is only folded into
//  `DailyUsage` when it is finalized — by a new Start, by the parent ending early, or by day
//  rollover. That makes the maths identical whether the app was open or killed when time ran out.
//
//  Framework-free and clock-injected, so every transition is unit-testable.

import Foundation

/// What the child timer renders. Pure data.
public struct ChildSessionSnapshot: Equatable, Sendable {
    public let state: ScreenTimeState
    public let remainingSeconds: Int
    /// Seconds-before-end of the warning currently in force (for "5 minutes left" copy).
    public let activeWarningSeconds: Int?
    /// D-016 — true while the child should be asked what to do next (second-to-last reminder).
    public let isChoosingMoment: Bool
    public let window: SessionWindow?

    public init(state: ScreenTimeState, remainingSeconds: Int, activeWarningSeconds: Int? = nil,
                isChoosingMoment: Bool = false, window: SessionWindow?) {
        self.state = state
        self.remainingSeconds = remainingSeconds
        self.activeWarningSeconds = activeWarningSeconds
        self.isChoosingMoment = isChoosingMoment
        self.window = window
    }

    public static let idle = ChildSessionSnapshot(state: .idle, remainingSeconds: 0, window: nil)

    /// PRD §6.11–§6.14: the child's pick, if any, for this session.
    public var chosenActivity: TransitionActivity? { window?.chosenActivity }

    /// Whole minutes of the active warning, e.g. 5 for a 300-second offset.
    public var activeWarningMinutes: Int? { activeWarningSeconds.map { max(1, $0 / 60) } }
}

public final class SessionController: @unchecked Sendable {

    private let storage: any ScreenTimeStorageService
    private let notifications: (any NotificationScheduling)?
    private let presence: (any SessionPresenting)?
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let lock = NSLock()

    /// Monotonic within a session (never steps back on jitter); reset by start/rollover/end.
    private var lastState: ScreenTimeState = .idle

    public init(storage: any ScreenTimeStorageService,
                notifications: (any NotificationScheduling)? = nil,
                presence: (any SessionPresenting)? = nil,
                calendar: Calendar = .current,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.storage = storage
        self.notifications = notifications
        self.presence = presence
        self.calendar = calendar
        self.now = now
    }

    // MARK: Queries

    /// Today's budget minus recorded usage minus the in-flight window's elapsed time. Never negative.
    public func remainingBudgetSeconds() throws -> Int {
        try lock.withLock { try remainingBudgetSecondsLocked() }
    }

    // MARK: Lifecycle

    /// Call on launch and on foreground. Restores a persisted window or reports idle.
    /// A window from another day is finalized on its own day and discarded (PRD §11 rollover).
    public func restore() throws -> ChildSessionSnapshot {
        try lock.withLock {
            guard let window = try currentWindowLocked() else {
                lastState = .idle
                // D-021 — nothing is running, so nothing should be on the Lock Screen. This is what
                // clears a Live Activity stranded by a force-quit: the app could not end it while it
                // was not running, so the next launch does.
                presence?.hide()
                return try idleSnapshotLocked()
            }
            let current = now()
            // Relaunch: the natural stage is the best knowledge we have.
            lastState = WarningStateEngine.start(remainingSeconds: window.remainingSeconds(at: current),
                                                 warningOffsets: try offsetsLocked(for: window))
            return try snapshotLocked(for: window, at: current)
        }
    }

    /// The child taps Start. Finalizes any previous window, then opens one for the remaining budget.
    /// If nothing is left today, the result is `.finished` with no window.
    @discardableResult
    public func start() throws -> ChildSessionSnapshot {
        try lock.withLock {
            if let previous = try storage.loadSessionWindow() {
                try finalizeLocked(previous)
            }
            let remaining = try remainingBudgetSecondsLocked()
            let current = now()
            guard remaining > 0 else {
                lastState = .finished
                return ChildSessionSnapshot(state: .finished, remainingSeconds: 0, window: nil)
            }
            let window = SessionWindow(startedAt: current, budgetSeconds: remaining)
            try storage.save(window)
            lastState = WarningStateEngine.start(remainingSeconds: remaining, warningOffsets: try offsetsLocked(for: window))
            try scheduleNotificationsLocked(for: window)
            return try snapshotLocked(for: window, at: current)
        }
    }

    /// Recompute from the clock. Call on every redraw and on foreground.
    public func tick() throws -> ChildSessionSnapshot {
        try lock.withLock {
            guard let window = try currentWindowLocked() else {
                return try idleSnapshotLocked()
            }
            return try snapshotLocked(for: window, at: now())
        }
    }

    /// PRD §6.7 / D-009: the activities offered to the child — the parent's picks, or the whole
    /// fixed set when the parent picked none ("no preference" rather than "nothing").
    public func availableActivities() throws -> [TransitionActivity] {
        let chosen = try storage.loadConfiguration().selectedActivities
        guard chosen.isEmpty else { return chosen }
        // D-029 — "no preference" means everything on offer, which now includes whatever the
        // parent invented, not just our eight.
        return (try? storage.loadPickerPreferences().allActivities) ?? TransitionActivity.allCases
    }

    /// The child picks what to do next (PRD §6.11). Persists on the current window.
    /// No window → nothing to attach the choice to; returns the idle snapshot unchanged.
    @discardableResult
    public func choose(_ activity: TransitionActivity) throws -> ChildSessionSnapshot {
        try lock.withLock {
            guard var window = try currentWindowLocked() else {
                return try idleSnapshotLocked()
            }
            window.chosenActivity = activity
            try storage.save(window)
            try scheduleNotificationsLocked(for: window)
            return try snapshotLocked(for: window, at: now())
        }
    }

    /// PRD §6.16 / §15 — a parent grants +N seconds. Only meaningful with a window from today
    /// (running or finished). Returns nil when there is nothing to extend.
    /// State goes through `.extended` and resumes at the natural stage (§11). Stacking is allowed:
    /// each grant adds to the window's end. Notifications are re-derived from the new end.
    @discardableResult
    public func extend(bySeconds seconds: Int) throws -> ChildSessionSnapshot? {
        try lock.withLock {
            guard seconds > 0, let window = try currentWindowLocked() else { return nil }
            let extended = window.extended(bySeconds: seconds)
            try storage.save(extended)
            lastState = WarningStateEngine.grantExtension()
            try scheduleNotificationsLocked(for: extended)
            return try snapshotLocked(for: extended, at: now())
        }
    }

    /// Re-derive notifications for the current window (e.g. after Settings changed the toggles).
    public func rescheduleNotifications() throws {
        try lock.withLock {
            if let window = try currentWindowLocked() {
                try scheduleNotificationsLocked(for: window)
            } else {
                notifications?.cancelAll()
            }
        }
    }

    /// D-019 — the parent changed settings while a session was running. Make the live session obey.
    ///
    /// Reminders and activities were always re-read from storage on every tick, so those followed
    /// on their own. The DAILY BUDGET did not: a window is a wall-clock window (D-006) whose end
    /// was fixed at Start, so raising the budget from 15 to 30 minutes mid-session changed a number
    /// on the dashboard and nothing the child could see. That is the bug.
    ///
    /// The fix keeps `startedAt` (elapsed time is real and already spent) and moves `endsAt` to
    /// `now + whatever the new budget still allows`. Shrinking the budget below what has already
    /// been used ends the session now rather than owing negative time.
    ///
    /// `lastState` is reset so the engine re-derives the stage from the new remaining time: without
    /// this, `WarningStateEngine.next` is monotonic and a session that had reached "1 minute left"
    /// would stay red after the parent granted twenty more minutes.
    ///
    /// Returns the fresh snapshot, or nil when no session is running.
    @discardableResult
    public func applyConfigurationChange() throws -> ChildSessionSnapshot? {
        try lock.withLock {
            guard let window = try currentWindowLocked() else {
                notifications?.cancelAll()
                return nil
            }
            let current = now()
            let config = try storage.loadConfiguration()
            let recorded = try storage.loadDailyUsage(for: current)?.usedSeconds ?? 0
            let elapsed = max(0, window.totalSeconds - window.remainingSeconds(at: current))
            let allowance = config.dailyBudgetSeconds - recorded - elapsed

            // An extension is a deliberate grant beyond the budget (§15) — never claw it back.
            let granted = window.grantedSeconds
            let remaining = max(0, allowance + granted)

            let adjusted = SessionWindow(startedAt: window.startedAt,
                                         endsAt: current.addingTimeInterval(TimeInterval(remaining)),
                                         chosenActivity: window.chosenActivity,
                                         budgetSecondsAtStart: window.budgetSecondsAtStart)
            try storage.save(adjusted)
            lastState = .idle          // let the snapshot re-derive the stage from the new clock
            try scheduleNotificationsLocked(for: adjusted)
            return try snapshotLocked(for: adjusted, at: current)
        }
    }

    /// A parent ends the session early. Records the time actually used and returns to idle.
    @discardableResult
    public func endEarly() throws -> ChildSessionSnapshot {
        try lock.withLock {
            if let window = try storage.loadSessionWindow() {
                try finalizeLocked(window)
            }
            lastState = .idle
            return try idleSnapshotLocked()
        }
    }

    // MARK: Internals (lock held)

    /// The live window, or nil. Task 017 rule: a window is current while it started today OR is
    /// still running — so a session that starts at 23:50 is not cut off at midnight, and a
    /// timezone change cannot end a running session. Only a window that has ended AND belongs to
    /// another day is finalized (its usage lands on the day it started) and cleared.
    private func currentWindowLocked() throws -> SessionWindow? {
        guard let window = try storage.loadSessionWindow() else { return nil }
        let current = now()
        if calendar.isDate(window.startedAt, inSameDayAs: current) || window.remainingSeconds(at: current) > 0 {
            return window
        }
        try finalizeLocked(window)
        lastState = .idle
        return nil
    }

    /// Fold a window's elapsed time into that day's usage and forget the window.
    private func finalizeLocked(_ window: SessionWindow) throws {
        let elapsed = window.totalSeconds - window.remainingSeconds(at: now())
        try recordUsageLocked(seconds: elapsed, on: window.startedAt)
        try storage.clearSessionWindow()
        notifications?.cancelAll()
        presence?.hide()
    }

    /// Task 016 — (re)derive every pending notification from the window's absolute timestamps.
    private func scheduleNotificationsLocked(for window: SessionWindow) throws {
        let config = try storage.loadConfiguration()
        let name = try storage.loadChildProfile()?.name ?? ""
        if let notifications {
            let plan = NotificationPlan.make(for: window, configuration: config, childName: name, now: now())
            notifications.replaceAll(with: plan)
        }
        presence?.show(SessionPresenceState(childName: name,
                                            startedAt: window.startedAt,
                                            endsAt: window.endsAt,
                                            chosenActivity: window.chosenActivity,
                                            stateName: lastState.rawValue))
    }

    /// Hand the presenter a final state to show before it dismisses itself.
    private func presentFinishLocked(for window: SessionWindow) throws {
        guard let presence else { return }
        let name = try storage.loadChildProfile()?.name ?? ""
        presence.finish(SessionPresenceState(childName: name,
                                             startedAt: window.startedAt,
                                             endsAt: window.endsAt,
                                             chosenActivity: window.chosenActivity,
                                             stateName: ScreenTimeState.finished.rawValue))
    }

    private func remainingBudgetSecondsLocked() throws -> Int {
        let current = now()
        let config = try storage.loadConfiguration()
        let recorded = try storage.loadDailyUsage(for: current)?.usedSeconds ?? 0
        var inFlight = 0
        if let window = try storage.loadSessionWindow(), calendar.isDate(window.startedAt, inSameDayAs: current) {
            inFlight = window.totalSeconds - window.remainingSeconds(at: current)
        }
        return max(0, config.dailyBudgetSeconds - recorded - inFlight)
    }

    private func idleSnapshotLocked() throws -> ChildSessionSnapshot {
        let remaining = try remainingBudgetSecondsLocked()
        // No budget left today: the idle screen should say so rather than offer a Start that fails.
        let state: ScreenTimeState = remaining > 0 ? .idle : .finished
        return ChildSessionSnapshot(state: state, remainingSeconds: remaining, window: nil)
    }

    private func snapshotLocked(for window: SessionWindow, at current: Date) throws -> ChildSessionSnapshot {
        let remaining = window.remainingSeconds(at: current)
        let offsets = try offsetsLocked(for: window)
        let previous = lastState
        // A controller that did not open this window (dashboard, root routing, relaunch) must adopt
        // it rather than stay idle — this was the "Session: Not started" bug.
        if lastState == .idle {
            lastState = WarningStateEngine.start(remainingSeconds: remaining, warningOffsets: offsets)
        } else {
            lastState = WarningStateEngine.next(current: lastState, remainingSeconds: remaining, warningOffsets: offsets)
        }
        // D-021 — the moment the window runs out, retire the Live Activity. Once only: this runs
        // every second, and `finish` on every tick would restart the dismissal timer forever.
        if lastState == .finished && previous != .finished {
            try presentFinishLocked(for: window)
        }
        let reached = WarningStateEngine.reachedWarningIndex(remainingSeconds: remaining, warningOffsets: offsets)
        return ChildSessionSnapshot(
            state: lastState,
            remainingSeconds: remaining,
            activeWarningSeconds: lastState.isWarning
                ? WarningStateEngine.activeWarningOffset(remainingSeconds: remaining, warningOffsets: offsets)
                : nil,
            // The chooser appears at the second-to-last reminder and stays available from there on,
            // so a child who ignored it still has a way to pick.
            isChoosingMoment: {
                guard let reached, let chooser = WarningStateEngine.chooserIndex(warningCount: offsets.count) else { return false }
                return reached >= chooser && window.chosenActivity == nil
            }(),
            window: window
        )
    }

    /// Reminders that fit this window (strictly shorter than its total length).
    private func offsetsLocked(for window: SessionWindow) throws -> [Int] {
        try storage.loadConfiguration().effectiveWarningOffsets(forWindowSeconds: window.totalSeconds)
    }

    private func recordUsageLocked(seconds: Int, on date: Date) throws {
        let config = try storage.loadConfiguration()
        let existing = try storage.loadDailyUsage(for: date)
        let usage = DailyUsage(
            date: date,
            budgetSeconds: config.dailyBudgetSeconds,
            usedSeconds: (existing?.usedSeconds ?? 0) + max(0, seconds)
        )
        try storage.save(usage)
    }
}
