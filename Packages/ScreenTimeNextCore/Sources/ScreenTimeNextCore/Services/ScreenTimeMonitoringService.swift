//  ScreenTimeMonitoringService.swift
//  ScreenTimeNext
//
//  PRD §14 — protocol only. Real adapter: Task 010.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

public enum ScreenTimeMonitoringError: Error, Sendable {
    case notAuthorized
    /// Platform limit on concurrent activities/events reached. Confirm current limits against
    /// the installed SDK (Task 010) and record findings in docs/DECISIONS.md.
    case limitExceeded
    case unknown(String)
}

/// Registers the daily schedule and the budget threshold with DeviceActivity. PRD §14.
///
/// Rule 3 — DeviceActivity is NOT a per-second timer. Nothing here may assume continuous execution
/// or that the main app is alive. Implemented for real in Task 010; mocked in Task 002.
/// Two different jobs, and D-047 exists because they were being done by one mechanism that only
/// suits the first:
///
///  1. **The daily budget** — how much of the covered apps was used TODAY. Usage-accounted, which
///     is exactly what a `DeviceActivityEvent` threshold measures.
///  2. **This session's moments** — "three minutes before 8:15pm". Wall-clock, and a usage
///     threshold cannot express it: a child who puts the iPad down accrues no usage while the
///     clock keeps running, and an event fires at most ONCE per interval, so the first session of
///     the day would consume every reminder for the rest of it.
///
/// So the session's moments are `DeviceActivitySchedule`s that simply END at the moment we care
/// about. They carry no events and need no tokens: the callback is the clock reaching a time.
public protocol ScreenTimeMonitoringService: Sendable {
    var isMonitoring: Bool { get async }
    func startMonitoring(budgetSeconds: Int, warningOffsetsSeconds: [Int], selection: SelectionSnapshot) async throws
    func stopMonitoring() async throws
    /// Re-register after a configuration or selection change. Task 010 defines when a restart is
    /// warranted — restarting on every trivial change can lose accrued usage.
    func restartMonitoring(budgetSeconds: Int, warningOffsetsSeconds: [Int], selection: SelectionSnapshot) async throws

    /// D-047 — wake us at each reminder and at the end of THIS session. `warningOffsetsSeconds`
    /// are seconds before `endsAt`, earliest first. Replaces any alarms already set.
    func scheduleSessionAlarms(endsAt: Date, warningOffsetsSeconds: [Int]) async throws
    /// No session, or it ended. Leaving alarms behind would fire a shield over a child who has
    /// their device back, and each stale name counts against the 20-activity limit (D-037).
    func clearSessionAlarms() async
}
