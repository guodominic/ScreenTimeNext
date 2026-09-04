//  ScreenTimeShieldService.swift
//  ScreenTimeNext
//
//  PRD §14, §15 — protocol only. Real adapter: Task 011.
//  Framework-free: imports Foundation only. See ScreenTimeNext/README.md.

import Foundation

public enum ScreenTimeShieldError: Error, Sendable {
    case notAuthorized
    case noSelection
    case unknown(String)
}

/// Applies and removes ManagedSettings shielding for ScreenTimeNext-managed content only.
///
/// Rule 6 — never indiscriminately clear ManagedSettings. The adapter owns a NAMED store dedicated
/// to ScreenTimeNext; clearing it must never touch Apple's own Screen Time settings or another
/// parental-control app's settings on the same device (PRD §15).
///
/// Callable from BOTH the app and the extension, so no implementation may assume a UI exists.
/// Apply and remove must be idempotent: twice equals once. Task 011.
public protocol ScreenTimeShieldService: Sendable {
    func applyShield(for selection: SelectionSnapshot) throws
    func removeShield() throws
    var currentProtectionState: ProtectionState { get }
}
