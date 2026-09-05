//  ReadyStepView.swift — PRD §6.8. The only step that persists anything.
import SwiftUI
import ScreenTimeNextCore

struct ReadyStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void
    @Environment(\.services) private var services
    @State private var finishing = false

    private var name: String { viewModel.draft.trimmedChildName }
    private var minutes: Int { viewModel.draft.dailyBudgetSeconds / 60 }

    var body: some View {
        OnboardingStepScaffold(
            title: "\(name) is all set",
            symbol: "party.popper.fill",
            color: Theme.mint,
            buttonTitle: finishing ? "Finishing…" : "Finish",
            buttonEnabled: !finishing,
            action: {
                guard viewModel.finish() else { return }
                finishing = true
                Task {
                    // Task 016: ask for notification permission here, in the parent flow, with the
                    // reason on screen. Denial is not an error — warnings still show in-app.
                    _ = await services.notifications.requestPermission()
                    onComplete()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Label("\(minutes) minutes of screen time each day", systemImage: "clock.fill").foregroundStyle(Theme.mint)
                Label(reminderSummary, systemImage: "bell.badge.fill").foregroundStyle(Theme.sun)
                Label("\(name) picks what to do next", systemImage: "star.fill").foregroundStyle(Theme.lavender)
                Label("Reminders arrive as notifications, so they reach \(name) in any app", systemImage: "app.badge.fill").foregroundStyle(Theme.sky)
                if let activities = nonEmptyActivities {
                    Text(activities)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                }
            }
            if let error = viewModel.commitError {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
        }
        .navigationBarBackButtonHidden(false)
    }

    private var reminderSummary: String {
        let mins = viewModel.draft.configuration.warningOffsetsSeconds.map { $0 / 60 }
        if mins.isEmpty { return "No reminders — just a finish notification" }
        return "Reminders at " + mins.map { "\($0) min" }.joined(separator: ", ") + " before the end"
    }

    private var nonEmptyActivities: String? {
        let names = viewModel.draft.configuration.selectedActivities.map(\.displayName)
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }
}
