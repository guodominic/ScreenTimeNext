//  ScreenTimeState.swift
//  ScreenTimeNext
//
//  PRD §11, §12 — session state. See DECISIONS.md D-002.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

/// Where the child is in the session. PRD §11, §12.
///
/// This is one of two independent axes. The other is `ProtectionState`, which answers
/// "is content currently enforced?". They change at different times and from different
/// processes — the extension can write `ProtectionState` while the app is not running
/// (PRD §14). See docs/DECISIONS.md D-002. Do not merge them.
public enum ScreenTimeState: String, Codable, CaseIterable, Sendable {
    case idle
    case active
    case warning10
    case warning5
    case warning1
    case finished
    case extended

    /// True for the three warning stages.
    public var isWarning: Bool {
        self == .warning10 || self == .warning5 || self == .warning1
    }
}
