//  WarningsStepView.swift — PRD §6.6 (10/5/1 all on by default; no custom intervals in V1)
import SwiftUI
import ScreenTimeNextCore

struct WarningsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var name: String { viewModel.draft.trimmedChildName }

    var body: some View {
        OnboardingStepScaffold(
            title: "Gentle warnings",
            subtitle: "\(name) will get a friendly heads-up before time ends.",
            buttonTitle: "Continue",
            action: { viewModel.advance(to: .whatsNext) }
        ) {
            VStack(spacing: 0) {
                Toggle("10 minutes left", isOn: $viewModel.draft.warning10Enabled)
                Divider()
                Toggle("5 minutes left", isOn: $viewModel.draft.warning5Enabled)
                Divider()
                Toggle("1 minute left", isOn: $viewModel.draft.warning1Enabled)
            }
            .padding(.vertical, 4)
        }
    }
}
