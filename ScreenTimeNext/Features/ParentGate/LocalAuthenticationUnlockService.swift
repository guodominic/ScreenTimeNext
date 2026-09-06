//  LocalAuthenticationUnlockService.swift
//  ScreenTimeNext
//
//  D-045 — the real `ParentUnlockService`.
//
//  One line in here matters more than the rest put together:
//
//      .deviceOwnerAuthenticationWithBiometrics    ← biometrics ONLY
//      .deviceOwnerAuthentication                  ← biometrics, falling back to the DEVICE PASSCODE
//
//  The second one is the obvious choice everywhere else and completely wrong here. The device
//  passcode is the one a child types to unlock their own iPad every day — offering it as the
//  fallback would hand them the parent gate. When Face ID fails, the fallback is OUR PIN, which is
//  the one thing in this app the child has never been told.
//
//  API verified against Apple's documentation (2026-09-06), per Rule 8:
//      LAContext.canEvaluatePolicy(_:error:) · evaluatePolicy(_:localizedReason:) async throws
//      LAContext.biometryType: LABiometryType — .none .touchID .faceID .opticID
//      LAError.Code: .userCancel .userFallback .systemCancel .appCancel
//                    .biometryNotAvailable .biometryNotEnrolled .biometryLockout

import Foundation
import LocalAuthentication
import ScreenTimeNextCore

final class LocalAuthenticationUnlockService: ParentUnlockService, @unchecked Sendable {

    var available: BiometricKind {
        get async {
            // A fresh context every time: `canEvaluatePolicy` caches its answer for the life of the
            // context, so a reused one would keep saying "enrolled" after a parent removed their
            // face — and this app would keep offering a gate that no longer works.
            let context = LAContext()
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                return .none
            }
            switch context.biometryType {
            case .faceID:  return .faceID
            case .touchID: return .touchID
            case .opticID: return .opticID
            default:       return .none
            }
        }
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        // Empty rather than "Enter PIN": iOS draws this as a button on the biometric sheet, and a
        // second PIN entry point there would be OUR keypad's job done badly, without the lockout
        // (D-031). Falling back is done by cancelling, which returns the parent to the real keypad.
        context.localizedFallbackTitle = ""

        var probe: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &probe) else {
            throw ParentUnlockError.biometricsUnavailable
        }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                      localizedReason: reason)
            guard ok else { throw ParentUnlockError.failed }
        } catch let error as LAError {
            throw Self.mapped(error)
        } catch let error as ParentUnlockError {
            throw error
        } catch {
            throw ParentUnlockError.unknown(String(describing: error))
        }
    }

    static func mapped(_ error: LAError) -> ParentUnlockError {
        switch error.code {
        case .userCancel, .userFallback, .systemCancel, .appCancel:
            // Not a failure: the parent chose to type instead, or something else took the screen.
            return .cancelled
        case .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout:
            // Lockout counts as unavailable on purpose — after too many failed attempts only the
            // device passcode can clear it, and that is exactly the door we refuse to open.
            return .biometricsUnavailable
        default:
            return .failed
        }
    }
}
