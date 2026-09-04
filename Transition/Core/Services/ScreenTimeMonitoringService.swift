//  ScreenTimeMonitoringService.swift
//  Transition
//
//  PRD §14 — protocol only. Real adapter: Task 010.
//  Framework-free: imports Foundation only. See Transition/README.md.

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
public protocol ScreenTimeMonitoringService: Sendable {
    var isMonitoring: Bool { get async }
    func startMonitoring(budgetSeconds: Int, selection: SelectionSnapshot) async throws
    func stopMonitoring() async throws
    /// Re-register after a configuration or selection change. Task 010 defines when a restart is
    /// warranted — restarting on every trivial change can lose accrued usage.
    func restartMonitoring(budgetSeconds: Int, selection: SelectionSnapshot) async throws
}
