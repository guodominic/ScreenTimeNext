//  DeviceActivityMonitoringService.swift
//  ScreenTimeNext
//
//  Task 010 — the real `ScreenTimeMonitoringService`. PRD §14.
//
//  Rule 3 — DeviceActivity is NOT a per-second timer. Nothing here counts seconds, and nothing
//  assumes the app is alive. The countdown the child sees comes from `SessionWindow` timestamps
//  (D-006); this registers ONE daily schedule with ONE threshold, and the system wakes the
//  extension when the threshold is crossed, app running or not.
//
//  API verified against Apple's documentation (2026-09-06), per Rule 8:
//      DeviceActivityCenter()                        — init, no arguments
//      .startMonitoring(_:during:events:) throws     — DeviceActivityName, schedule, event map
//      .stopMonitoring(_: [DeviceActivityName])      — does NOT throw
//      .activities: [DeviceActivityName]             — what is registered right now
//      .events(for:) / .schedule(for:)               — read back what was registered
//      DeviceActivitySchedule(intervalStart:intervalEnd:repeats:warningTime:)
//      DeviceActivityEvent(applications:categories:webDomains:threshold:includesPastActivity:)
//      MonitoringError: .excessiveActivities .intervalTooLong .intervalTooShort
//                       .invalidDateComponents .unauthorized

import DeviceActivity
import FamilyControls
import Foundation
import ScreenTimeNextCore

extension DeviceActivityName {
    /// One name, forever. Apple overwrites a schedule registered under a name already in use, which
    /// is exactly the behaviour we want on a restart and exactly the bug we would get from a name
    /// that varied per session.
    /// `nonisolated` because the app module defaults to main-actor isolation: without it these
    /// names are main-actor properties, and reading one from `DeviceActivityCenter` (which is not)
    /// turns every use into an `await`.
    nonisolated static let daily = Self(MonitoringName.dailyActivity)
}

extension DeviceActivityEvent.Name {
    nonisolated static let budgetReached = Self(MonitoringName.budgetThreshold)
}

final class DeviceActivityMonitoringService: ScreenTimeMonitoringService, @unchecked Sendable {

    /// D-037 — midnight to one minute before midnight, repeating. The budget is a DAY's budget, and
    /// the app's own idea of "today" is `Calendar.startOfDay` (Rule 4), so the two boundaries have
    /// to be the same one or a child gets a second budget at whatever other hour we picked.
    /// 23:59 rather than 24:00: `intervalEnd` is a time of day, and 24:00 is not one.
    nonisolated static let intervalStart = DateComponents(hour: 0, minute: 0)
    nonisolated static let intervalEnd = DateComponents(hour: 23, minute: 59)

    private let center = DeviceActivityCenter()

    var isMonitoring: Bool {
        get async { center.activities.contains(.daily) }
    }

    // MARK: ScreenTimeMonitoringService

    func startMonitoring(budgetSeconds: Int,
                         warningOffsetsSeconds: [Int],
                         selection: SelectionSnapshot) async throws {
        let events = try makeEvents(budgetSeconds: budgetSeconds,
                                    warningOffsetsSeconds: warningOffsetsSeconds,
                                    selection: selection)
        let schedule = DeviceActivitySchedule(intervalStart: Self.intervalStart,
                                              intervalEnd: Self.intervalEnd,
                                              repeats: true)
        do {
            try center.startMonitoring(.daily, during: schedule, events: events)
        } catch let error as DeviceActivityCenter.MonitoringError {
            throw Self.mapped(error)
        } catch {
            throw ScreenTimeMonitoringError.unknown(String(describing: error))
        }
    }

    func stopMonitoring() async throws {
        center.stopMonitoring([.daily])
    }

    /// D-037 — a restart is a real cost, so it happens only when the registration would actually
    /// differ. Re-registering resets the event's accrued time, and `includesPastActivity` is what
    /// stops that costing the child the minutes they already spent — but a restart still throws
    /// away the system's own bookkeeping, so doing it on every incidental save is worth avoiding.
    func restartMonitoring(budgetSeconds: Int,
                           warningOffsetsSeconds: [Int],
                           selection: SelectionSnapshot) async throws {
        let wanted = try makeEvents(budgetSeconds: budgetSeconds,
                                    warningOffsetsSeconds: warningOffsetsSeconds,
                                    selection: selection)
        if center.activities.contains(.daily), Self.sameRegistration(center.events(for: .daily), wanted) {
            return
        }
        center.stopMonitoring([.daily])
        try await startMonitoring(budgetSeconds: budgetSeconds,
                                  warningOffsetsSeconds: warningOffsetsSeconds,
                                  selection: selection)
    }

    // MARK: Building the event

    /// D-043 — the budget's own threshold, plus one per reminder.
    ///
    /// A reminder that only sends a notification is a reminder a child can swipe away without ever
    /// looking up. These extra thresholds are what let the system wake us INSIDE the app they are
    /// using, a few minutes before the end, so the heads-up lands where the screen time is
    /// happening. Well inside the 20-activity platform limit: this is still one activity (D-037).
    private func makeEvents(budgetSeconds: Int,
                            warningOffsetsSeconds: [Int],
                            selection: SelectionSnapshot) throws -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .budgetReached: try makeEvent(budgetSeconds: budgetSeconds, selection: selection)
        ]
        for offset in warningOffsetsSeconds {
            // A reminder longer than the budget has no moment to fire in, and one at zero seconds
            // before the end is the end. Both are dropped rather than registered as noise.
            let atSeconds = budgetSeconds - offset
            guard atSeconds >= 60, offset > 0 else { continue }
            let name = DeviceActivityEvent.Name(MonitoringName.warningThreshold(secondsBefore: offset))
            events[name] = try makeEvent(budgetSeconds: atSeconds, selection: selection)
        }
        return events
    }

    private func makeEvent(budgetSeconds: Int, selection: SelectionSnapshot) throws -> DeviceActivityEvent {
        let picked = try FamilyActivitySelectionCoding.selection(from: selection)
        // A threshold over nothing never fires. Registering one would leave the app believing
        // enforcement is armed when it can never trigger, which is worse than an honest failure.
        guard !FamilyActivitySelectionCoding.isEmpty(picked) else {
            throw ScreenTimeMonitoringError.unknown("Nothing is selected, so there is nothing to monitor.")
        }
        return DeviceActivityEvent(applications: picked.applicationTokens,
                                   categories: picked.categoryTokens,
                                   webDomains: picked.webDomainTokens,
                                   threshold: Self.threshold(forBudgetSeconds: budgetSeconds),
                                   // The child's usage from earlier today counts. Without this a
                                   // parent who edits the budget at 4pm hands back a full budget.
                                   includesPastActivity: true)
    }

    /// Whole minutes, because D-034 made every dial in the app move a minute at a time; anything
    /// below one minute is rounded up rather than to zero, since a zero threshold fires instantly.
    static func threshold(forBudgetSeconds seconds: Int) -> DateComponents {
        DateComponents(minute: max(1, Int((Double(seconds) / 60).rounded(.up))))
    }

    /// Same events, same names, and for each: same apps, categories, domains and threshold — the
    /// things that decide what the system is actually watching.
    static func sameRegistration(_ a: [DeviceActivityEvent.Name: DeviceActivityEvent],
                                 _ b: [DeviceActivityEvent.Name: DeviceActivityEvent]) -> Bool {
        guard Set(a.keys) == Set(b.keys) else { return false }
        return a.allSatisfy { name, event in
            guard let other = b[name] else { return false }
            return event.applications == other.applications
                && event.categories == other.categories
                && event.webDomains == other.webDomains
                && event.threshold == other.threshold
        }
    }

    static func mapped(_ error: DeviceActivityCenter.MonitoringError) -> ScreenTimeMonitoringError {
        switch error {
        case .unauthorized:
            return .notAuthorized
        case .excessiveActivities:
            // Twenty activities per app and its extensions. We register exactly one, so reaching
            // this means something else left registrations behind — worth surfacing, not retrying.
            return .limitExceeded
        case .intervalTooLong, .intervalTooShort, .invalidDateComponents:
            return .unknown(String(describing: error))
        @unknown default:
            return .unknown(String(describing: error))
        }
    }
}
