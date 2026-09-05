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
                    Image(systemName: activity.symbolName)
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 120)
                        .background(Circle().fill(Theme.color(for: activity)))
                        .bounceIn(delay: 0.15)
                }
                .frame(height: 200)
                Text("You chose \(activity.displayName).")
                    .font(.title2)
                    .bounceIn(delay: 0.3)
                Text(activity.invitation)
                    .font(.system(.title, design: .rounded).bold())
                    .bounceIn(delay: 0.4)
            } else if budgetSpentEarlier {
                Image(systemName: "moon.stars.fill").font(.system(size: 64)).foregroundStyle(Theme.lavender)
                    .floating().bounceIn(delay: 0.1)
                Text("You've used today's screen time.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .bounceIn(delay: 0.2)
                Text("See you tomorrow, \(childName)!")
                    .font(.system(.title, design: .rounded).bold())
                    .bounceIn(delay: 0.3)
            } else {
                ZStack {
                    Sparkles()
                    Image(systemName: "hands.clap.fill").font(.system(size: 56)).foregroundStyle(.white)
                        .frame(width: 120, height: 120)
                        .background(Circle().fill(Theme.mint))
                        .bounceIn(delay: 0.15)
                }
                .frame(height: 200)
                Text("Nice job, \(childName).")
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

#Preview("Chose LEGO") {
    TimesUpView(childName: "Ivy", chosenActivity: .lego, budgetSpentEarlier: false)
}

#Preview("No choice") {
    TimesUpView(childName: "Ivy", chosenActivity: nil, budgetSpentEarlier: false)
}

#Preview("Budget spent earlier") {
    TimesUpView(childName: "Ivy", chosenActivity: nil, budgetSpentEarlier: true)
}
