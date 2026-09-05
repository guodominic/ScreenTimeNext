//  WarningsStepView.swift — PRD §6.6, D-013: up to three reminders, 0–15 minutes before the end.
import SwiftUI
import ScreenTimeNextCore

struct WarningsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var name: String { viewModel.draft.trimmedChildName }

    var body: some View {
        OnboardingStepScaffold(
            title: "Gentle reminders",
            subtitle: "\(name) will get a friendly heads-up before time ends. We've suggested reminders for a \(viewModel.draft.dailyBudgetSeconds / 60)-minute budget — turn a dial to change it, or to Off to skip it.",
            symbol: "bell.badge.fill",
            color: Theme.sun,
            buttonTitle: "Continue",
            action: { viewModel.advance(to: .whatsNext) }
        ) {
            WarningDials(minutes: $viewModel.draft.warningMinutes,
                         budgetMinutes: viewModel.draft.dailyBudgetSeconds / 60)
            Text("Reminders must be shorter than the \(viewModel.draft.dailyBudgetSeconds / 60)-minute budget, so the dials stop at \(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: viewModel.draft.dailyBudgetSeconds) / 60).")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// Three small dials side by side. Shared with Settings.
struct WarningDials: View {
    @Binding var minutes: [Int]
    /// Daily budget in minutes: a reminder must be strictly shorter than the budget (budget 8 → up to 7).
    let budgetMinutes: Int

    private let colors = [Theme.sun, Theme.peach, Theme.coral]

    private var upperBound: Int {
        ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: budgetMinutes * 60) / 60
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<ScreenTimeConfiguration.maxWarnings, id: \.self) { i in
                MinuteDial(minutes: slot(i),
                           range: 0...upperBound,
                           step: 1,
                           title: "Reminder \(i + 1)",
                           color: colors[i],
                           baseSize: 104,
                           zeroMeansOff: true)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func slot(_ i: Int) -> Binding<Int> {
        Binding(
            get: { i < minutes.count ? minutes[i] : 0 },
            set: { newValue in
                var m = minutes
                while m.count < ScreenTimeConfiguration.maxWarnings { m.append(0) }
                m[i] = newValue
                minutes = m
            }
        )
    }
}
