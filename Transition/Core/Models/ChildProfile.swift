//  ChildProfile.swift
//  Transition
//
//  PRD §12 — ChildProfile.
//  Framework-free: imports Foundation only. See Transition/README.md.

import Foundation

/// The single child profile supported in V1 (PRD §6.2, §4 — multi-child is a non-goal).
public struct ChildProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    /// First name only. PRD §16 — do not collect child identity beyond this.
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
