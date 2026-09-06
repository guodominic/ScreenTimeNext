//  FamilyControlsAuthorizationService.swift
//  ScreenTimeNext
//
//  Task 004 — the real `AuthorizationCenter` flow. Rule 1: this file and its folder are the ONLY
//  place `import FamilyControls` appears for authorization; everything above it speaks
//  `ScreenTimeAuthorizationStatus` and `ScreenTimeAuthorizationError`.
//
//  API verified against Apple's current documentation (2026-09-06), per Rule 8:
//      AuthorizationCenter.shared
//      try await center.requestAuthorization(for: FamilyControlsMember.individual)   // async throws
//      center.authorizationStatus -> AuthorizationStatus (.notDetermined | .denied | .approved)
//  `requestAuthorization(completionHandler:)` is deprecated and is not used.

import Foundation
import FamilyControls
import ScreenTimeNextCore

nonisolated final class FamilyControlsAuthorizationService: ScreenTimeAuthorizationService, @unchecked Sendable {

    /// D-025 — we enrol as `.individual`, not `.child`.
    ///
    /// `.child` is the stronger gate: it authenticates against a parent's Apple Account, so the
    /// child cannot undo it from Settings. It also REQUIRES the device to be signed into a child
    /// account inside a Family Sharing group, and fails with `invalidAccountType` otherwise — which
    /// on the very common "family iPad signed in with a parent's account" is a dead end presented
    /// to a parent who has twenty seconds and a waiting child (D-016).
    ///
    /// `.individual` enrols whoever is on the device, behind Face ID / Touch ID and a passcode. It
    /// works everywhere, and its weakness — the child can revoke it in Settings — is a weakness the
    /// app already accepts: §17 says ScreenTimeNext is not tamper-proof, and D-011's press-and-hold
    /// "Parents" control is the in-app gate. Revocation is detected rather than prevented (below,
    /// and Task 017 / QA-14).
    ///
    /// Revisit once real families have used it (§21): for households that do have Family Sharing
    /// configured, `.child` is a genuine upgrade and could be offered as a choice.
    private static let member: FamilyControlsMember = .individual

    /// Remembers that authorization was once granted, so a later `.denied` can be reported as
    /// `.revoked` rather than as "never asked". Apple exposes three states; the app needs four, and
    /// this latch is the only difference between them. Stored in the App Group so an extension
    /// reading the same defaults sees the same answer.
    private let defaults: UserDefaults
    private static let approvedOnceKey = "screentimenext.authorization.approvedOnce"

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    // MARK: ScreenTimeAuthorizationService

    var status: ScreenTimeAuthorizationStatus {
        get async {
            let current = await MainActor.run { AuthorizationCenter.shared.authorizationStatus }
            return resolve(current)
        }
    }

    @discardableResult
    func requestAuthorization() async throws -> ScreenTimeAuthorizationStatus {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: Self.member)
        } catch let error as FamilyControlsError {
            throw Self.mapped(error)
        } catch {
            // §16 — the message is Apple's own, never a token or an identifier.
            throw ScreenTimeAuthorizationError.unknown(error.localizedDescription)
        }
        let now = await status
        if now == .approved { defaults.set(true, forKey: Self.approvedOnceKey) }
        return now
    }

    // MARK: Mapping

    /// Apple's three states plus our latch make the four the app renders.
    private func resolve(_ status: AuthorizationStatus) -> ScreenTimeAuthorizationStatus {
        switch status {
        // `.approvedWithDataAccess` exists in the installed SDK but not in the published docs —
        // the compiler is the only place it shows up, which is exactly why Rule 8 says to check
        // against the SDK. It means approved AND allowed to read usage data (the "Family Controls
        // App and Website Usage" capability the App ID carries). For authorization purposes it is
        // simply approved; the extra access matters to Task 010, not here.
        case .approved, .approvedWithDataAccess:
            defaults.set(true, forKey: Self.approvedOnceKey)
            return .approved
        case .denied:
            // Denied AFTER having been approved is a different situation for the parent: nothing is
            // being enforced any more, and the fix is in Settings rather than in this app.
            return defaults.bool(forKey: Self.approvedOnceKey) ? .revoked : .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    /// Every documented `FamilyControlsError`, mapped to something the parent screens can act on.
    /// The cases are Apple's current set (verified 2026-09-06); `@unknown default` covers growth.
    private static func mapped(_ error: FamilyControlsError) -> ScreenTimeAuthorizationError {
        switch error {
        case .authorizationCanceled:
            return .denied
        case .invalidAccountType:
            return .unknown("This device needs to be signed in to iCloud before Screen Time access can be granted.")
        case .authenticationMethodUnavailable:
            return .unknown("Set a passcode on this device, then try again — Screen Time access needs one.")
        case .authorizationConflict:
            return .unknown("Another parental-controls app is already managing Screen Time on this device. Turn it off first.")
        case .networkError:
            return .unknown("This needs a network connection the first time. Connect and try again.")
        case .restricted:
            return .unknown("A restriction on this device blocks Screen Time access.")
        case .unavailable, .invalidArgument:
            return .entitlementUnavailable
        // A plain `default`, not `@unknown default`: this enum has cases the published docs do not
        // list, and an error mapping whose fallback is already a sensible message gains nothing
        // from being told about new ones at compile time — whereas failing to build over one would
        // cost a whole cycle.
        default:
            return .unknown("Screen Time access couldn't be granted. Please try again.")
        }
    }
}
