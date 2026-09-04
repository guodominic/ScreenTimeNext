//  TransitionActivity.swift
//  Transition
//
//  PRD §6.7, §12 — the fixed V1 activity set.
//  Framework-free: imports Foundation only. See Transition/README.md.

import Foundation

/// The fixed set of transition activities. PRD §6.7.
/// V1 does not support custom or free-text activities.
public enum TransitionActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case lego
    case drawing
    case reading
    case outside
    case snack
    case bath
    case homework
    case familyTime

    public var id: String { rawValue }

    /// Child-facing copy. PRD §7 — keep it warm and concrete.
    public var displayName: String {
        switch self {
        case .lego:       return "LEGO"
        case .drawing:    return "Drawing"
        case .reading:    return "Reading"
        case .outside:    return "Outside"
        case .snack:      return "Snack"
        case .bath:       return "Bath"
        case .homework:   return "Homework"
        case .familyTime: return "Family Time"
        }
    }
}
