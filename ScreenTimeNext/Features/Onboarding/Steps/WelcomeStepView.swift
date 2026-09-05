//  WelcomeStepView.swift — PRD §6.1
import SwiftUI
import ScreenTimeNextCore

struct WelcomeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingStepScaffold(
            title: "Make screen time end peacefully.",
            symbol: "sun.max.fill",
            color: Theme.sky,
            mascot: .happy,
            buttonTitle: "Get Started",
            action: { viewModel.advance(to: .childProfile) }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("ScreenTimeNext helps your child move from screen time to what's next — with gentle warnings before time ends, and a next activity they get to choose.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    feature("bell.badge.fill", "Gentle warnings", Theme.sun)
                    feature("hand.thumbsup.fill", "They choose next", Theme.mint)
                    feature("heart.fill", "Calm endings", Theme.coral)
                }
            }
        }
    }

    private func feature(_ symbol: String, _ text: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color)
            Text(text).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(tint: color)
    }
}
