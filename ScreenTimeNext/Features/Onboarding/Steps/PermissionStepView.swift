//  PermissionStepView.swift — PRD §6.3
//  Explains WHY before triggering anything; the system prompt never appears on screen entry.
import SwiftUI
import ScreenTimeNextCore

struct PermissionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var name: String { viewModel.draft.trimmedChildName }

    var body: some View {
        OnboardingStepScaffold(
            title: "Screen Time access",
            subtitle: "ScreenTimeNext needs Screen Time access to:",
            buttonTitle: "Continue",
            buttonEnabled: viewModel.canContinuePastPermission,
            action: { viewModel.advance(to: .appSelection) }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                reason("1", "Monitor the apps you choose")
                reason("2", "Warn \(name) before time ends")
                reason("3", "End screen time when the budget is used up")
            }
            .padding(.vertical, 8)

            statusView
        }
        .task { await viewModel.loadAuthorizationStatus() }
    }

    private func reason(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.authorization {
        case .approved:
            Label("Access granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .notDetermined, .denied, .revoked:
            VStack(alignment: .leading, spacing: 12) {
                if let message = viewModel.authorizationMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await viewModel.requestAuthorization() }
                } label: {
                    if viewModel.isRequestingAuthorization {
                        ProgressView()
                    } else {
                        Text(viewModel.authorization == .notDetermined ? "Allow Screen Time Access" : "Try Again")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRequestingAuthorization)
            }
        }
    }
}
