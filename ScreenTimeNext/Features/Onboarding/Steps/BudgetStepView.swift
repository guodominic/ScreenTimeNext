//  BudgetStepView.swift — PRD §6.5 (default 60; presets 15/30/45/60/90/120)
import SwiftUI
import ScreenTimeNextCore

struct BudgetStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        OnboardingStepScaffold(
            title: "How much screen time each day?",
            subtitle: "You can change this any time.",
            buttonTitle: "Continue",
            action: { viewModel.advance(to: .warnings) }
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ScreenTimeConfiguration.budgetPresetsSeconds, id: \.self) { seconds in
                    let selected = viewModel.draft.dailyBudgetSeconds == seconds
                    Button {
                        viewModel.draft.dailyBudgetSeconds = seconds
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(seconds / 60)").font(.title2.bold())
                            Text("min").font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? Color.accentColor : Color.secondary)
                }
            }
        }
    }
}
