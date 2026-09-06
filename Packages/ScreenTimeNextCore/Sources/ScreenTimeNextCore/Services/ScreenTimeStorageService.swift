//  ScreenTimeStorageService.swift
//  ScreenTimeNext
//
//  PRD §13 — protocol only. Real adapter: Task 006.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

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

    /// True once a configuration has actually been written. D-016: the child's name is optional,
    /// so "has a profile" no longer answers "has this been set up".
    func hasStoredConfiguration() throws -> Bool

    func loadDailyUsage(for date: Date) throws -> DailyUsage?
    func save(_ usage: DailyUsage) throws

    func loadSessionWindow() throws -> SessionWindow?
    func save(_ window: SessionWindow) throws
    func clearSessionWindow() throws

    /// Re-read on every app foreground — the extension may have changed it. PRD §14.
    func loadProtectionState() throws -> ProtectionState
    func save(_ state: ProtectionState) throws

    /// D-024 — the parent's picker arrangement. Survives `eraseAll`, because it is the parent's
    /// own working setup rather than the child's configuration.
    func loadPickerPreferences() throws -> ParentPickerPreferences
    func save(_ preferences: ParentPickerPreferences) throws

    /// D-031 — the parent gate. nil means no PIN is set and the gate falls back to press-and-hold.
    func loadParentPIN() throws -> ParentPIN?
    func save(_ pin: ParentPIN?) throws

    /// Forget the child's setup: profile, configuration, usage, session, protection state.
    /// Parent-initiated "start over" (and Task 017). Never touches anything outside
    /// ScreenTimeNext's own records, and deliberately KEEPS `ParentPickerPreferences` — see D-024.
    /// It DOES clear the parent PIN: "start over" has to mean start over, and a forgotten PIN that
    /// survived a reset would lock a parent out of their own device with no way back (D-031).
    func eraseAll() throws
}
