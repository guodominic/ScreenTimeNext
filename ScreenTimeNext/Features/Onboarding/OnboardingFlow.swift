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

/// Consistent layout for every onboarding step: icon, title, optional subtitle, content, pill button.
struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String = "sparkles"
    var color: Color = Theme.sky
    let buttonTitle: String
    var buttonEnabled: Bool = true
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(colors: [color.opacity(0.25), Color(.systemGroupedBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color))
                        .padding(.bottom, 4)
                        .bounceIn()
                    Text(title)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .bounceIn(delay: 0.06)
                    if let subtitle {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .bounceIn(delay: 0.1)
                    }
                    content()
                        .padding(.top, 8)
                        .bounceIn(delay: 0.16)
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: action) { Text(buttonTitle) }
                    .buttonStyle(PillButtonStyle(color: color))
                    .disabled(!buttonEnabled)
                    .opacity(buttonEnabled ? 1 : 0.5)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Flow") {
    OnboardingFlow(services: .mocks()) {}
}
