//  ScreenTimeState.swift
//  ScreenTimeNextCore
//
//  PRD §11, §12 — session state. D-013: the three warning states are ROLES (earliest, middle,
//  last of the configured warnings), not fixed minutes. With two warnings configured the middle
//  role is skipped; with one, that warning is `firstWarning` (it carries the activity chooser).
//  See DECISIONS.md D-002 for why this is separate from ProtectionState.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

public enum ScreenTimeState: String, Codable, CaseIterable, Sendable {
    case idle
    case active
    case firstWarning
    case secondWarning
    case finalWarning
    case finished
    case extended

    public var isWarning: Bool {
        self == .firstWarning || self == .secondWarning || self == .finalWarning
    }
}
