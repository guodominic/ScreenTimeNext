//  TimesUpView.swift
//  ScreenTimeNext
//
//  Task 015 — PRD §6.14, §6.15, §7. "Screen time is finished ❤️" plus the activity the child chose.
//  This is the product thesis in one screen (§2): the exit points TOWARD the activity, never back
//  to the shielded app. No dismiss, no controls, no "TIME'S UP!" framing.

import SwiftUI
import ScreenTimeNextCore

struct TimesUpView: View {
    let childName: String

    private var addressed: String { childName.isEmpty ? "" : ", \(childName)" }
    let chosenActivity: TransitionActivity?
    /// True when today's budget is already spent and there is no session to show (§6.10 idle-with-no-budget).
    let budgetSpentEarlier: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Screen time is finished ❤️")
                .font(.system(.largeTitle, design: .rounded).bold())
                .bounceIn()

            if let activity = chosenActivity {
                ZStack {
                    Sparkles(color: Theme.color(for: activity))
                    HStack(spacing: -14) {
                        Mascot(mood: .cheering, size: 118, tint: Theme.color(for: activity))
                        Image(systemName: activity.symbolName)
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .frame(width: 92, height: 92)
                            .background(Circle().fill(Theme.color(for: activity)))
                            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                            .offset(y: 14)
                    }
                    .bounceIn(delay: 0.15)
                }
                .frame(height: 200)
                Text("You chose \(activity.displayName)\(addressed).")
                    .font(.title2)
                    .bounceIn(delay: 0.3)
                Text(activity.invitation)
                    .font(.system(.title, design: .rounded).bold())
                    .bounceIn(delay: 0.4)
            } else if budgetSpentEarlier {
                ZStack(alignment: .topTrailing) {
                    Mascot(mood: .sleepy, size: 128, tint: Theme.lavender)
                    Image(systemName: "moon.stars.fill")
                        .font(.title2).foregroundStyle(Theme.sun)
                        .offset(x: 16, y: -6)
                }
                .bounceIn(delay: 0.1)
                Text("You've used today's screen time.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .bounceIn(delay: 0.2)
                Text(childName.isEmpty ? "See you tomorrow!" : "See you tomorrow, \(childName)!")
                    .font(.system(.title, design: .rounded).bold())
                    .bounceIn(delay: 0.3)
            } else {
                ZStack {
                    Sparkles()
                    Mascot(mood: .cheering, size: 128, tint: Theme.mint)
                        .bounceIn(delay: 0.15)
                }
                .frame(height: 200)
                Text(childName.isEmpty ? "Nice job!" : "Nice job, \(childName).")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .bounceIn(delay: 0.3)
                Text("Let's do something else now.")
                    .font(.system(.title, design: .rounded).bold())
                    .bounceIn(delay: 0.4)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Chose Outside") {
    TimesUpView(childName: "Ivy", chosenActivity: .outside, budgetSpentEarlier: false)
}

#Preview("No choice") {
    TimesUpView(childName: "Ivy", chosenActivity: nil, budgetSpentEarlier: false)
}

#Preview("Budget spent earlier") {
    TimesUpView(childName: "Ivy", chosenActivity: nil, budgetSpentEarlier: true)
}
