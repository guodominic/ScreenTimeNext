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
    /// D-018 — what the parent ticks on "Pick apps and categories". Owned here so the counts on
    /// the step, the draft and the Start button never disagree.
    var picker: ContentPickerModel

    var authorization: ScreenTimeAuthorizationStatus = .notDetermined
    var authorizationMessage: String?
    var isRequestingAuthorization = false
    var commitError: String?

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
        // D-019/D-021 — a re-run of setup opens on what the parent already picked and arranged.
        picker = ContentPickerModel.loaded(from: services.storage)
        // Task 005 — a re-run of setup keeps whatever Apple's picker produced before.
        picker.realSelection = try? services.selection.loadSelection()
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

    /// Mirror the picker into the draft after every tap, so `startNow()` never has to reach back
    /// into a view for state.
    func selectionChanged() {
        draft.selection = picker.snapshot(basedOn: draft.selection)
    }

    // MARK: Start

    /// Saves the setup and opens the session in one step — the parent hands over a running timer.
    func startNow() -> Bool {
        do {
            selectionChanged()
            try draft.commit(using: services)
            picker.persist(to: services.storage)
            _ = try services.makeSessionController().start()
            commitError = nil
            return true
        } catch {
            commitError = "Couldn't start. Please try again."
            return false
        }
    }
}
