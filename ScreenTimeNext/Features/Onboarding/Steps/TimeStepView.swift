//  TimeStepView.swift — D-016 / D-017 / D-034
//
//  The decision made in the moment: how long, and when to give a heads-up. No headline — the dial
//  says what it is. Every dial moves one minute at a time (D-034).
//
//  D-038 briefly added a "what's covered" row here so the picker was reachable before the timer
//  was settled. It came straight back out: the very next screen IS the picker, so the row was a
//  second door onto the room you were already walking into — two entries to the same place read as
//  two different places. Reverted, deliberately, and recorded rather than quietly undone.

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
