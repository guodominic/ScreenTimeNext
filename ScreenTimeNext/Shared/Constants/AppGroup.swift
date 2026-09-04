//  AppGroup.swift
//  ScreenTimeNext
//
//  PRD §13 — the single shared-container identifier. Task 001.
//  Framework-free: imports Foundation only. See ScreenTimeNext/README.md.

import Foundation

/// The App Group shared between the main app and the DeviceActivityMonitor extension.
///
/// Rule 5 — this identifier must be declared in exactly one place and referenced by BOTH targets.
public enum AppGroup {

    // TODO(Task 001 / docs/BLOCKERS.md B-002):
    // Replace with the real registered App Group identifier once an Apple Developer Team ID is
    // configured. The value below is a placeholder and will fail to resolve a container at runtime.
    public static let identifier = "group.PLACEHOLDER.screentimenext"

    /// Storage keys for the shared container. Keep them here so the app and the extension cannot
    /// drift apart on a string literal.
    public enum Key {
        public static let childProfile     = "screentimenext.childProfile"
        public static let configuration    = "screentimenext.configuration"
        public static let dailyUsage       = "screentimenext.dailyUsage"
        public static let selection        = "screentimenext.selection"
        public static let sessionWindow    = "screentimenext.sessionWindow"
        public static let protectionState  = "screentimenext.protectionState"
        public static let schemaVersion    = "screentimenext.schemaVersion"
    }

    /// Bump when a stored model changes shape. Task 006 owns migration.
    public static let currentSchemaVersion = 1
}

/// Names used when registering DeviceActivity schedules and events. Task 010 consumes these.
/// Kept framework-free so both targets can share them.
public enum MonitoringName {
    public static let dailyActivity = "screentimenext.daily"
    public static let budgetThreshold = "screentimenext.budgetReached"
}
