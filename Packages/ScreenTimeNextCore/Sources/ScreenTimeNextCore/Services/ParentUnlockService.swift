//  ParentUnlockService.swift
//  ScreenTimeNextCore
//
//  D-045 — Face ID as a SHORTCUT past the parent PIN, never as a replacement for it.
//
//  The threat model here is unlike any other biometric login: the person trying to get through the
//  gate is holding the enrolled device, and on the device this app is usually installed on — the
//  child's own iPad — the enrolled face is THEIRS. Face ID on that device is not a gate, it is a
//  door held open. So this is off by default and the parent turns it on knowing what it means.
//
//  Framework-free: `LocalAuthentication` lives in the app adapter. This file is the protocol, the
//  preference, and the reasons a device can refuse — all testable without a face.

import Foundation

public enum ParentUnlockError: Error, Equatable, Sendable {
    /// No Face ID / Touch ID hardware, or nothing enrolled.
    case biometricsUnavailable
    /// The face or finger did not match.
    case failed
    /// The parent dismissed the prompt. Not a failure — they can still type the PIN.
    case cancelled
    case unknown(String)
}

/// What the device can offer, so the UI can name it correctly ("Face ID" vs "Touch ID") rather
/// than saying "biometrics" at a parent.
public enum BiometricKind: String, Codable, Sendable {
    case none, faceID, touchID, opticID

    public var displayName: String {
        switch self {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none:    return "Face ID"      // only ever shown where it is also unavailable
        }
    }
}

/// Proving a parent is present. The PIN is the floor; this is the optional shortcut.
public protocol ParentUnlockService: Sendable {
    /// What this device has, right now. Enrollment can be removed at any time.
    var available: BiometricKind { get async }
    /// Throws rather than returning false, because WHY it failed decides what the UI does:
    /// a cancel returns the parent to the keypad, unavailable turns the setting off.
    func authenticate(reason: String) async throws
}

/// D-045 — the parent's choice, stored with their other preferences so "Start over" keeps it
/// (D-024): a family that turned this on once should not be asked again after a reset.
public struct ParentGatePreference: Codable, Equatable, Sendable {
    /// False by default, and that default is the whole decision. See the note at the top.
    public var usesBiometrics: Bool

    public init(usesBiometrics: Bool = false) {
        self.usesBiometrics = usesBiometrics
    }

    public static let `default` = ParentGatePreference()
}
