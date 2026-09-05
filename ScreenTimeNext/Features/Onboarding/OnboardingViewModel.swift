//  OnboardingViewModel.swift
//  ScreenTimeNext
//
//  Task 003. Owns the draft and the navigation path for the 8-step parent onboarding.
//  Talks to services through protocols only (Rules 1, 2). Nothing is persisted until `finish()`.

import SwiftUI
import Observation
import ScreenTimeNextCore

enum OnboardingStep: Hashable {
    case childProfile
    case permission
    case appSelection
    case budget
    case warnings
    case whatsNext
    case ready
}

@Observable
final class OnboardingViewModel {

    var path: [OnboardingStep] = []
    var draft = OnboardingDraft()

    var authorization: ScreenTimeAuthorizationStatus = .notDetermined
    var authorizationMessage: String?
    var isRequestingAuthorization = false

    var commitError: String?

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    // MARK: Navigation

    func advance(to step: OnboardingStep) {
        path.append(step)
    }

    // MARK: §6.3 Permission

    func loadAuthorizationStatus() async {
        authorization = await services.authorization.status
    }

    func requestAuthorization() async {
        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }
        do {
            authorization = try await services.authorization.requestAuthorization()
            authorizationMessage = nil
        } catch ScreenTimeAuthorizationError.denied {
            authorization = .denied
            authorizationMessage = "Screen Time access was declined. You can allow it in Settings › Screen Time, then try again."
        } catch ScreenTimeAuthorizationError.entitlementUnavailable {
            authorization = await services.authorization.status
            authorizationMessage = "Screen Time access isn't available in this build yet."
        } catch {
            authorization = await services.authorization.status
            authorizationMessage = "Something went wrong requesting access. Please try again."
        }
    }

    var canContinuePastPermission: Bool { authorization == .approved }

    // MARK: §6.4 Selection (Phase 0: mocked — Task 005 replaces the presenter, not this model)

    func applySelection(_ snapshot: SelectionSnapshot) {
        draft.selection = snapshot
    }

    func clearSelection() {
        draft.selection = nil
    }

    // MARK: §6.8 Finish

    /// Returns true when everything was persisted.
    func finish() -> Bool {
        do {
            try draft.commit(using: services)
            commitError = nil
            return true
        } catch {
            commitError = "Couldn't save the setup. Please try again."
            return false
        }
    }
}
