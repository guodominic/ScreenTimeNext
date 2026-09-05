//  TransitionActivity.swift
//  ScreenTimeNext
//
//  PRD §6.7, §12 — the fixed V1 activity set.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

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

    /// Time's Up copy (PRD §6.14): "You chose LEGO. Let's go build!" — the second sentence.
    public var invitation: String {
        switch self {
        case .lego:       return "Let's go build!"
        case .drawing:    return "Let's go draw!"
        case .reading:    return "Grab a book!"
        case .outside:    return "Let's head outside!"
        case .snack:      return "Snack time!"
        case .bath:       return "Bath time!"
        case .homework:   return "Let's get it done!"
        case .familyTime: return "Let's find the family!"
        }
    }

    /// SF Symbol for the chooser tiles.
    public var symbolName: String {
        switch self {
        case .lego:       return "square.stack.3d.up.fill"
        case .drawing:    return "paintpalette.fill"
        case .reading:    return "book.fill"
        case .outside:    return "sun.max.fill"
        case .snack:      return "carrot.fill"
        case .bath:       return "drop.fill"
        case .homework:   return "pencil.and.list.clipboard"
        case .familyTime: return "figure.2.and.child.holdinghands"
        }
    }
}
