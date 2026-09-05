//  WelcomeStepView.swift — PRD §6.1, D-016
//
//  A greeting, not a manual. One promise, one button. Everything else the parent needs to know,
//  they will learn by using it thirty seconds from now.

import SwiftUI
import ScreenTimeNextCore

struct WelcomeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.sky.opacity(0.38), Color(.systemGroupedBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            PlayfulBackground(tint: Theme.sky, intensity: 1.0)

            VStack(spacing: 22) {
                Spacer()
                Mascot(mood: .happy, size: 230, tint: Theme.sky)
                    .bounceIn()
                Text("Hi, I'm Pip!")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .bounceIn(delay: 0.1)
                Text("Let's make screen time end peacefully.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .bounceIn(delay: 0.16)
                Spacer()
                Button { viewModel.advance(to: .time) } label: { Text("Let's go") }
                    .buttonStyle(PillButtonStyle(color: Theme.mint))
                    .bounceIn(delay: 0.24)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .readableWidth(520)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { WelcomeStepView(viewModel: OnboardingViewModel(services: .mocks())) }
}
