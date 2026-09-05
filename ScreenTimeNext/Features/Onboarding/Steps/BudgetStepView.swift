//  BudgetStepView.swift — PRD §6.5, D-013: dial from 2 to 120 minutes in 2-minute steps.
import SwiftUI
import ScreenTimeNextCore

struct BudgetStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var minutes: Binding<Int> {
        Binding(get: { viewModel.draft.dailyBudgetSeconds / 60 },
                set: { viewModel.draft.dailyBudgetSeconds = $0 * 60 })
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "How much screen time each day?",
            subtitle: "Turn the dial. You can change this any time.",
            symbol: "clock.fill",
            color: Theme.mint,
            buttonTitle: "Continue",
            action: { viewModel.advance(to: .warnings) }
        ) {
            HStack {
                Spacer()
                MinuteDial(minutes: minutes,
                           range: ScreenTimeConfiguration.budgetRangeSeconds.lowerBound / 60...ScreenTimeConfiguration.budgetRangeSeconds.upperBound / 60,
                           step: ScreenTimeConfiguration.budgetStepSeconds / 60,
                           color: Theme.mint)
                Spacer()
            }
        }
    }
}
