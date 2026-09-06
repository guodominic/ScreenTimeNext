//  TimeStepView.swift — D-016 / D-017
//
//  The decision made in the moment: how long, and when to give a heads-up. No headline — the dial
//  says what it is. Steps are one minute under fifteen, two above.

import SwiftUI
import ScreenTimeNextCore

struct TimeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var minutes: Binding<Int> {
        Binding(get: { viewModel.draft.dailyBudgetSeconds / 60 },
                set: { viewModel.draft.dailyBudgetSeconds = $0 * 60 })
    }

    private var budgetMinutes: Int { viewModel.draft.dailyBudgetSeconds / 60 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.mint.opacity(0.30), Color(.systemGroupedBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            PlayfulBackground(tint: Theme.mint, intensity: 0.7)

            ScrollView {
                VStack(spacing: 24) {
                    MinuteDial.budget(minutes, color: Theme.mint)
                        .bounceIn()

                    VStack(spacing: 10) {
                        Label("Remind before the end", systemImage: "bell.badge.fill")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        WarningDials(minutes: $viewModel.draft.warningMinutes,
                                     budgetMinutes: budgetMinutes)
                    }
                    .bounceIn(delay: 0.1)
                }
                .padding(24)
                .readableWidth()
            }
            .safeAreaInset(edge: .bottom) {
                Button { viewModel.advance(to: .whatCounts) } label: { Text("Next") }
                    .buttonStyle(PillButtonStyle(color: Theme.mint))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .readableWidth()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { TimeStepView(viewModel: OnboardingViewModel(services: .mocks())) }
}
