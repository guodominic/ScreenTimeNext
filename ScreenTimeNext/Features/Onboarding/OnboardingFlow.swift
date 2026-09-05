//  OnboardingFlow.swift
//  ScreenTimeNext
//
//  D-016 — two screens, not eight. The real scene is: a child wants the iPad now, a parent says
//  "fifteen minutes", and picks the device up. Everything that can wait, waits:
//    · the child's name → Settings, optional
//    · which reminders  → Settings, sensible defaults derived from the budget
//    · what to do next  → the CHILD chooses, at the second-to-last reminder
//  What's left is the only thing that is actually decided in that moment: how long, and what counts.

import SwiftUI
import ScreenTimeNextCore

struct OnboardingFlow: View {
    @State private var viewModel: OnboardingViewModel
    let onStart: () -> Void

    init(services: ServiceContainer, onStart: @escaping () -> Void) {
        _viewModel = State(initialValue: OnboardingViewModel(services: services))
        self.onStart = onStart
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            WelcomeStepView(viewModel: viewModel)
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .quickSetup: QuickSetupView(viewModel: viewModel, onStart: onStart)
                    }
                }
        }
    }
}

#Preview("Flow") {
    OnboardingFlow(services: .mocks()) {}
}
