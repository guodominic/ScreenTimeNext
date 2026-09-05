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
                .font(.largeTitle.bold())

            if let activity = chosenActivity {
                Image(systemName: activity.symbolName)
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 8)
                Text("You chose \(activity.displayName).")
                    .font(.title2)
                Text(activity.invitation)
                    .font(.title.bold())
            } else if budgetSpentEarlier {
                Text("You've used today's screen time.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("See you tomorrow, \(childName)!")
                    .font(.title.bold())
            } else {
                Text("Nice job, \(childName).")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Let's do something else now.")
                    .font(.title.bold())
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
