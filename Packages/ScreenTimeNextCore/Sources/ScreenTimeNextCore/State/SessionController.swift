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
    /// False when the parent disabled this warning (§6.6) — render as plain `active` instead.
    public let presentsWarning: Bool
    public let window: SessionWindow?

    public init(state: ScreenTimeState, remainingSeconds: Int, presentsWarning: Bool, window: SessionWindow?) {
        self.state = state
        self.remainingSeconds = remainingSeconds
        self.presentsWarning = presentsWarning
        self.window = window
    }

    public static let idle = ChildSessionSnapshot(state: .idle, remainingSeconds: 0, presentsWarning: false, window: nil)

    /// The state to *render*: a disabled warning shows as `.active`.
    public var displayState: ScreenTimeState {
        state.isWarning && !presentsWarning ? .active : state
    }

    /// PRD §6.11–§6.14: the child's pick, if any, for this session.
    public var chosenActivity: TransitionActivity? { window?.chosenActivity }
}

public final class SessionController: @unchecked Sendable {

    private let storage: any ScreenTimeStorageService
    private let notifications: (any NotificationScheduling)?
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let lock = NSLock()

    /// Monotonic within a session (never steps back on jitter); reset by start/rollover/end.
    private var lastState: ScreenTimeState = .idle

    public init(storage: any ScreenTimeStorageService,
                notifications: (any NotificationScheduling)? = nil,
                calendar: Calendar = .current,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.storage = storage
        self.notifications = notifications
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
                return try idleSnapshotLocked()
            }
            let current = now()
            // Relaunch: the natural stage is the best knowledge we have.
            lastState = WarningStateEngine.start(remainingSeconds: window.remainingSeconds(at: current))
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
                return ChildSessionSnapshot(state: .finished, remainingSeconds: 0, presentsWarning: false, window: nil)
            }
            let window = SessionWindow(startedAt: current, budgetSeconds: remaining)
            try storage.save(window)
            lastState = WarningStateEngine.start(remainingSeconds: remaining)
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
        return chosen.isEmpty ? TransitionActivity.allCases : chosen
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

    /// Today's window, or nil. A window from another day is finalized and cleared here.
    private func currentWindowLocked() throws -> SessionWindow? {
        guard let window = try storage.loadSessionWindow() else { return nil }
        if calendar.isDate(window.startedAt, inSameDayAs: now()) {
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
    }

    /// Task 016 — (re)derive every pending notification from the window's absolute timestamps.
    private func scheduleNotificationsLocked(for window: SessionWindow) throws {
        guard let notifications else { return }
        let config = try storage.loadConfiguration()
        let name = try storage.loadChildProfile()?.name ?? ""
        let plan = NotificationPlan.make(for: window, configuration: config, childName: name, now: now())
        notifications.replaceAll(with: plan)
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
        return ChildSessionSnapshot(state: state, remainingSeconds: remaining, presentsWarning: false, window: nil)
    }

    private func snapshotLocked(for window: SessionWindow, at current: Date) throws -> ChildSessionSnapshot {
        let remaining = window.remainingSeconds(at: current)
        lastState = WarningStateEngine.next(current: lastState, remainingSeconds: remaining)
        let config = try storage.loadConfiguration()
        return ChildSessionSnapshot(
            state: lastState,
            remainingSeconds: remaining,
            presentsWarning: WarningStateEngine.shouldPresent(lastState, configuration: config),
            window: window
        )
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
