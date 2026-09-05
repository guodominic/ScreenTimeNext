//  OnboardingFlow.swift
//  ScreenTimeNext
//
//  Task 003. Welcome → Child → Permission → App Selection → Budget → Warnings → What's Next → Ready.
//  A NavigationStack over the view model's path: native back navigation, and every step reads
//  and writes the same draft, so going back never loses what the parent entered.

import SwiftUI
import ScreenTimeNextCore

struct OnboardingFlow: View {
    @State private var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    init(services: ServiceContainer, onComplete: @escaping () -> Void) {
        _viewModel = State(initialValue: OnboardingViewModel(services: services))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            WelcomeStepView(viewModel: viewModel)
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .childProfile: ChildProfileStepView(viewModel: viewModel)
                    case .permission:   PermissionStepView(viewModel: viewModel)
                    case .appSelection: AppSelectionStepView(viewModel: viewModel)
                    case .budget:       BudgetStepView(viewModel: viewModel)
                    case .warnings:     WarningsStepView(viewModel: viewModel)
                    case .whatsNext:    WhatsNextStepView(viewModel: viewModel)
                    case .ready:        ReadyStepView(viewModel: viewModel, onComplete: onComplete)
                    }
                }
        }
    }
}

// MARK: - Shared step chrome

/// Consistent layout for every onboarding step: title, optional subtitle, content, primary button.
struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let buttonTitle: String
    var buttonEnabled: Bool = true
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title.bold())
            if let subtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            content()
            Spacer(minLength: 0)
            Button(action: action) {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!buttonEnabled)
        }
        .padding(24)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Flow") {
    OnboardingFlow(services: .mocks()) {}
}
