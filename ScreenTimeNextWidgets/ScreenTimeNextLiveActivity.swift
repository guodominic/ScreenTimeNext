//  ScreenTimeNextLiveActivity.swift
//  ScreenTimeNextWidgets
//
//  D-014. The countdown lives in the Dynamic Island / status area (iPhone) and on the Lock Screen
//  (iPhone + iPad). `Text(timerInterval:)` ticks on its own — no process needed (Rule 4).
//  The state line updates when the app updates the activity (start / choose / extend / warnings
//  while the app is open); the timer is always live.

import ActivityKit
import WidgetKit
import SwiftUI
import ScreenTimeNextCore

struct ScreenTimeNextLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenTimeActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(color(for: context.state.stateName).opacity(0.25))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: symbol(for: context.state))
                        .font(.title2)
                        .foregroundStyle(color(for: context.state.stateName))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                        .font(.system(.title2, design: .rounded).bold())
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.attributes.childName)'s screen time").font(.headline)
                        Text(line(for: context.state)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: symbol(for: context.state))
                    .foregroundStyle(color(for: context.state.stateName))
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .frame(width: 46)
            } minimal: {
                ProgressView(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(color(for: context.state.stateName))
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<ScreenTimeActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol(for: context.state))
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(color(for: context.state.stateName)))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(context.attributes.childName)'s screen time").font(.headline)
                Text(line(for: context.state)).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(width: 96)
        }
        .padding(16)
    }
}

// MARK: - Copy & colors (mirrors the app's Theme without depending on the app target)

private func line(for state: ScreenTimeActivityAttributes.ContentState) -> String {
    switch state.stateName {
    case "firstWarning":  return "Almost done — pick what's next"
    case "secondWarning": return state.chosenActivity.map { "Time to finish up · Next: \($0.displayName)" } ?? "Time to finish up"
    case "finalWarning":  return "One more minute!"
    case "finished":      return "Screen time is finished ❤️"
    case "extended":      return "Extra time from a parent"
    default:              return state.chosenActivity.map { "Next: \($0.displayName)" } ?? "Enjoy!"
    }
}

private func symbol(for state: ScreenTimeActivityAttributes.ContentState) -> String {
    state.chosenActivity?.symbolName ?? "hourglass"
}

private func color(for stateName: String) -> Color {
    switch stateName {
    case "firstWarning":  return Color(red: 1.00, green: 0.78, blue: 0.24)
    case "secondWarning": return Color(red: 1.00, green: 0.67, blue: 0.45)
    case "finalWarning":  return Color(red: 1.00, green: 0.49, blue: 0.43)
    case "finished", "extended": return Color(red: 0.62, green: 0.54, blue: 0.96)
    default:              return Color(red: 0.31, green: 0.80, blue: 0.62)
    }
}
