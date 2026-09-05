//  WelcomeStepView.swift — PRD §6.1
import SwiftUI
import ScreenTimeNextCore

struct WelcomeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepScaffold(
            title: "Make screen time end peacefully.",
            buttonTitle: "Get Started",
            action: { viewModel.advance(to: .childProfile) }
        ) {
            Text("ScreenTimeNext helps your child move from screen time to what's next — with gentle warnings before time ends, and a next activity they get to choose.")
                .foregroundStyle(.secondary)
        }
    }
}
