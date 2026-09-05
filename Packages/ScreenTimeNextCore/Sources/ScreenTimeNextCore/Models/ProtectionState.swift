//  ProtectionState.swift
//  ScreenTimeNext
//
//  PRD §12 — enforcement state. See DECISIONS.md D-002.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

/// Whether ScreenTimeNext-managed content is currently enforced. PRD §12.
///
/// Written by the DeviceActivityMonitor extension as well as by the app (PRD §14), so the app
/// must re-read it from shared storage on foreground rather than trusting an in-memory copy.
public enum ProtectionState: String, Codable, CaseIterable, Sendable {
    case unshielded
    case shielded
    case temporarilyExtended
}
