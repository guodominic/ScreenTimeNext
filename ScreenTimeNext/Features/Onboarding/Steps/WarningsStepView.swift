//  WarningsStepView.swift — PRD §6.6, D-013: up to three reminders, 0–15 minutes before the end.
import SwiftUI
import ScreenTimeNextCore

struct WarningsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var name: String { viewModel.draft.trimmedChildName }

    var body: some View {
        OnboardingStepScaffold(
            title: "Gentle reminders",
            subtitle: "\(name) will get a friendly heads-up before time ends. Set up to three, minutes before the end. Turn a dial to Off to skip it.",
            symbol: "bell.badge.fill",
            color: Theme.sun,
            buttonTitle: "Continue",
            action: { viewModel.advance(to: .whatsNext) }
        ) {
            WarningDials(minutes: $viewModel.draft.warningMinutes)
        }
    }
}

/// Three small dials side by side. Shared with Settings.
struct WarningDials: View {
    @Binding var minutes: [Int]

    private let colors = [Theme.sun, Theme.peach, Theme.coral]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<ScreenTimeConfiguration.maxWarnings, id: \.self) { i in
                MinuteDial(minutes: slot(i),
                           range: 0...ScreenTimeConfiguration.warningOffsetRange.upperBound / 60,
                           step: 1,
                           title: "Reminder \(i + 1)",
                           color: colors[i],
                           size: 104,
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
