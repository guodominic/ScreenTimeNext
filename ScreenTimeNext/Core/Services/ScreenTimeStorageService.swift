//  ScreenTimeStorageService.swift
//  ScreenTimeNext
//
//  PRD §13 — protocol only. Real adapter: Task 006.
//  Framework-free: imports Foundation only. See ScreenTimeNext/README.md.

import Foundation

public enum ScreenTimeStorageError: Error, Sendable {
    /// App Group container unreachable — usually a missing entitlement or Team ID.
    /// docs/BLOCKERS.md B-002.
    case containerUnavailable
    case decodingFailed
    case encodingFailed
}

/// The single persistence boundary. PRD §13.
///
/// Rule 5 — everything here lives in the App Group shared container, because the
/// DeviceActivityMonitor extension reads and writes the same state while the app may not be
/// running (PRD §14). Assume concurrent access; write atomically. Task 006.
public protocol ScreenTimeStorageService: Sendable {
    func loadChildProfile() throws -> ChildProfile?
    func save(_ profile: ChildProfile) throws

    /// Returns `ScreenTimeConfiguration.default` when nothing is stored or the store is corrupt.
    func loadConfiguration() throws -> ScreenTimeConfiguration
    func save(_ configuration: ScreenTimeConfiguration) throws

    func loadDailyUsage(for date: Date) throws -> DailyUsage?
    func save(_ usage: DailyUsage) throws

    func loadSessionWindow() throws -> SessionWindow?
    func save(_ window: SessionWindow) throws
    func clearSessionWindow() throws

    /// Re-read on every app foreground — the extension may have changed it. PRD §14.
    func loadProtectionState() throws -> ProtectionState
    func save(_ state: ProtectionState) throws
}
