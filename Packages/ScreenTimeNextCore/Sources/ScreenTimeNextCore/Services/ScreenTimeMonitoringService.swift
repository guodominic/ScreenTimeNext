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
/// `warningOffsetsSeconds` are seconds BEFORE the end, exactly as `ScreenTimeConfiguration` stores
/// them. D-043 registers one threshold per reminder alongside the budget's own, because a reminder
/// the child never sees is not a reminder: the app is usually not running at that moment, and only
/// the system can wake us inside the app they are actually using.
public protocol ScreenTimeMonitoringService: Sendable {
    var isMonitoring: Bool { get async }
    func startMonitoring(budgetSeconds: Int, warningOffsetsSeconds: [Int], selection: SelectionSnapshot) async throws
    func stopMonitoring() async throws
    /// Re-register after a configuration or selection change. Task 010 defines when a restart is
    /// warranted — restarting on every trivial change can lose accrued usage.
    func restartMonitoring(budgetSeconds: Int, warningOffsetsSeconds: [Int], selection: SelectionSnapshot) async throws
}
