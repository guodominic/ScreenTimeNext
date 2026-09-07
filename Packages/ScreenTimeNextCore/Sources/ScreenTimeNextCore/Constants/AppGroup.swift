//  AppGroup.swift
//  ScreenTimeNext
//
//  PRD §13 — the single shared-container identifier. Task 001.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

/// The App Group shared between the main app and the DeviceActivityMonitor extension.
///
/// Rule 5 — this identifier must be declared in exactly one place and referenced by BOTH targets.
public enum AppGroup {

    // Derived from the app's bundle identifier (io.github.guodominic.screentimenext).
    // NOTE (D-007): App Groups are unavailable on a free Personal Team, so this container cannot be
    // resolved in Phase 0. Phase 0 uses a local-container storage implementation (Task 006); the
    // App Group implementation arrives in Phase 1 once the paid membership exists (BLOCKERS B-002).
    public static let identifier = "group.io.github.guodominic.screentimenext"

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

    /// D-047 — one ACTIVITY per wall-clock moment in a session, replacing D-043's usage thresholds.
    ///
    /// The name is all the extension gets back, so it has to carry which moment this is.
    private static let sessionWarningPrefix = "screentimenext.session.warn."

    /// The moment the session runs out.
    public static let sessionEnd = "screentimenext.session.end"

    /// Reminder `index`, earliest first — the same order as `warningOffsetsSeconds`.
    public static func sessionWarning(index: Int) -> String {
        sessionWarningPrefix + String(index)
    }

    public static func isSessionWarning(_ rawName: String) -> Bool {
        rawName.hasPrefix(sessionWarningPrefix)
    }

    /// Everything a session registers, for clearing it in one call. Generous on purpose: a name
    /// left behind counts against the 20-activity limit forever (D-037).
    public static var allSessionActivities: [String] {
        [sessionEnd] + (0..<8).map { sessionWarning(index: $0) }
    }
}
