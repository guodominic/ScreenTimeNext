//  ScreenTimeAuthorizationService.swift
//  ScreenTimeNext
//
//  PRD §6.3, §8 — protocol only. Real adapter: Task 004.
//  Framework-free: imports Foundation only. See ScreenTimeNext/README.md.

import Foundation

/// The app's own authorization vocabulary.
///
/// Deliberately NOT a re-export of a FamilyControls type: Rule 1 keeps framework types out of the
/// core layer. `ScreenTimeNext/ScreenTime/Authorization/` maps Apple's status onto this. Task 004.
public enum ScreenTimeAuthorizationStatus: String, Codable, CaseIterable, Sendable {
    case notDetermined
    case approved
    case denied
    /// Approved earlier, withdrawn since. Runtime handling is Task 017 (QA-14).
    case revoked
}

public enum ScreenTimeAuthorizationError: Error, Sendable {
    case denied
    /// Family Controls entitlement unavailable. docs/BLOCKERS.md B-001.
    case entitlementUnavailable
    case unknown(String)
}

/// PRD §6.3. Implemented for real in Task 004; mocked in Task 002.
public protocol ScreenTimeAuthorizationService: Sendable {
    var status: ScreenTimeAuthorizationStatus { get async }
    @discardableResult
    func requestAuthorization() async throws -> ScreenTimeAuthorizationStatus
}
