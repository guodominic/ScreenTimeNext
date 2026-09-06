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
}
