//  OnboardingViewModel.swift
//  ScreenTimeNext
//
//  D-016 — holds the two decisions made in the moment (how long, what counts) and starts the
//  session. Nothing is persisted until `startNow()`.

import SwiftUI
import Observation
import ScreenTimeNextCore

enum OnboardingStep: Hashable {
    case time          // how long, and when to remind
    case whatCounts    // which apps and categories the budget applies to
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

    func advance(to step: OnboardingStep) { path.append(step) }

    // MARK: Screen Time access — requested when the parent reaches for the picker, not before

    func loadAuthorizationStatus() async {
        authorization = await services.authorization.status
    }

    var needsAuthorization: Bool { authorization != .approved }

    func requestAuthorization() async {
        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }
        do {
            authorization = try await services.authorization.requestAuthorization()
            authorizationMessage = nil
        } catch ScreenTimeAuthorizationError.denied {
            authorization = .denied
            authorizationMessage = "Screen Time access was declined. You can allow it in Settings › Screen Time."
        } catch ScreenTimeAuthorizationError.entitlementUnavailable {
            authorization = await services.authorization.status
            authorizationMessage = "Screen Time access isn't available in this build yet."
        } catch {
            authorization = await services.authorization.status
            authorizationMessage = "Something went wrong. Please try again."
        }
    }

    func applySelection(_ snapshot: SelectionSnapshot) { draft.selection = snapshot }
    func clearSelection() { draft.selection = nil }

    // MARK: Start

    /// Saves the setup and opens the session in one step — the parent hands over a running timer.
    func startNow() -> Bool {
        do {
            try draft.commit(using: services)
            _ = try services.makeSessionController().start()
            commitError = nil
            return true
        } catch {
            commitError = "Couldn't start. Please try again."
            return false
        }
    }
}
