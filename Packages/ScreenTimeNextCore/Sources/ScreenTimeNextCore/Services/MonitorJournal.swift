//  MonitorJournal.swift
//  ScreenTimeNextCore
//
//  Task 010 / Rule 5 — the one-way channel from the DeviceActivityMonitor extension to the app.
//
//  Why `UserDefaults` and not a file: the extension is woken for a moment and may be killed the
//  instant it returns. `UserDefaults` in an App Group suite is a single synchronous write that the
//  system flushes for us; a file write in the same window is a `Data`, a directory that may not
//  exist yet, and an atomic replace, all of which can be interrupted half-done. The app's real
//  records still live in files (`FileStorageService`) — this is a log, not a record.
//
//  Framework-free: Foundation only, so both targets can share it.

import Foundation

/// A short, self-trimming log of the callbacks the extension received.
///
/// Bounded on purpose. It exists to answer "did the callback arrive, and when?", which needs the
/// last few entries; an unbounded log in a shared container is a slow leak nobody ever reads.
/// A class rather than a struct, and `@unchecked Sendable` rather than `Sendable`: it holds a
/// `UserDefaults`, which Apple documents as thread-safe but does not mark `Sendable`. The unchecked
/// conformance is the honest label for "the compiler cannot see this, the framework guarantees it".
public final class MonitorJournal: @unchecked Sendable {

    /// Entries kept. Enough to see a day's worth of interval starts, ends and one threshold.
    public static let capacity = 20

    private let defaults: UserDefaults
    private let key = "screentimenext.monitorJournal"

    /// Fails only when the App Group container cannot be opened — which means provisioning is
    /// wrong and the extension could not have talked to the app anyway.
    public init?(suiteName: String = AppGroup.identifier) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
    }

    /// Test seam: an explicit suite, so a test never writes into the real shared container.
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Append one callback. Called from the extension, where nothing may throw and nothing may
    /// take long, so a failure here is dropped rather than propagated — a lost log line must never
    /// be the reason a threshold callback fails to do its real work.
    public func record(_ event: MonitorReport.Event, activity: String, at date: Date = Date()) {
        var entries = self.entries()
        entries.append(MonitorReport(event: event, activity: activity, at: date))
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    /// Oldest first.
    public func entries() -> [MonitorReport] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MonitorReport].self, from: data) else { return [] }
        return decoded
    }

    /// The most recent entry of one kind — the question the app actually asks ("has the budget
    /// threshold fired today?").
    public func latest(_ event: MonitorReport.Event) -> MonitorReport? {
        entries().last { $0.event == event }
    }

    /// True when that callback has arrived since the given moment. `since` is normally the start of
    /// today, because a threshold that fired yesterday says nothing about today's budget.
    public func hasFired(_ event: MonitorReport.Event, since: Date) -> Bool {
        guard let latest = latest(event) else { return false }
        return latest.at >= since
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }

    // MARK: D-050 — the clock stops while a transition screen is up

    private var pausedAtKey: String { "screentimenext.shieldRaisedAt" }

    /// Longest pause we will give back. A child who walks away with the shield up has not been
    /// robbed of screen time, and crediting an unbounded pause would leave a session that was
    /// interrupted at 8pm still running at midnight — not what anyone meant by "fifteen minutes".
    public static let maximumPauseSeconds = 10 * 60

    /// Called when a shield goes up. Idempotent: a shield raised twice was still only raised once,
    /// and overwriting would restart the clock the child is owed.
    public func markShieldRaised(at date: Date = Date()) {
        guard defaults.object(forKey: pausedAtKey) == nil else { return }
        defaults.set(date.timeIntervalSince1970, forKey: pausedAtKey)
    }

    /// Called when the child dismisses it. Returns the seconds to give back, capped, and forgets
    /// the mark so the next shield starts its own.
    public func claimPausedSeconds(at date: Date = Date()) -> Int {
        guard let raisedAt = defaults.object(forKey: pausedAtKey) as? Double else { return 0 }
        defaults.removeObject(forKey: pausedAtKey)
        let elapsed = Int(date.timeIntervalSince1970 - raisedAt)
        guard elapsed > 0 else { return 0 }
        return min(elapsed, Self.maximumPauseSeconds)
    }

    /// A session ended, so any unclaimed mark belongs to nothing.
    public func forgetShieldRaised() {
        defaults.removeObject(forKey: pausedAtKey)
    }

    /// D-050 — give back the time a transition screen was up, and say how much.
    ///
    /// Deliberately framework-free and deliberately NOT responsible for the session's alarms: this
    /// runs in the shield action extension, which has no `DeviceActivity` of its own. The alarms
    /// are left pointing at the old, earlier end — and that is safe, because the end alarm firing
    /// early finds time remaining and re-arms itself from the new end (D-050). A wrong-but-early
    /// alarm is self-correcting; a missing one is not.
    @discardableResult
    public func creditPause(to storage: any ScreenTimeStorageService, at now: Date = Date()) -> Int {
        let seconds = claimPausedSeconds(at: now)
        guard seconds > 0,
              let window = try? storage.loadSessionWindow(),
              window.remainingSeconds(at: now) > 0 else { return 0 }
        try? storage.save(window.paused(bySeconds: seconds))
        return seconds
    }
}
