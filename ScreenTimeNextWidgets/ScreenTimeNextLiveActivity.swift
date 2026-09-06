//  ScreenTimeNextLiveActivity.swift
//  ScreenTimeNextWidgets
//
//  D-014. The countdown lives in the Dynamic Island / status area (iPhone) and on the Lock Screen
//  (iPhone + iPad). `Text(timerInterval:)` ticks on its own — no process needed (Rule 4).
//  The state line updates when the app updates the activity (start / choose / extend / warnings
//  while the app is open); the timer is always live.
//
//  D-019 — the mark is Pip, not an SF Symbol: this is the one place the app appears while the
//  child is in someone else's app, so it should look like ScreenTimeNext. See PipMark.swift for
//  why the mascot is drawn a second time here rather than shared with the app target.

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
                    PipMark(mood: isFinished(context) ? .cheering : PipMarkMood(stateName: context.state.stateName),
                            size: 30,
                            tint: color(for: context.state.stateName))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if isFinished(context) {
                            Text("Done").font(.system(.title3, design: .rounded).bold())
                        } else {
                            Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                                .font(.system(.title2, design: .rounded).bold())
                                .monospacedDigit()
                        }
                    }
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: context.attributes.childName)).font(.headline)
                        Label {
                            Text(isFinished(context) ? "Screen time is finished ❤️" : line(for: context.state))
                        } icon: {
                            Image(systemName: symbol(for: context.state))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                PipMark(mood: isFinished(context) ? .cheering : PipMarkMood(stateName: context.state.stateName),
                        size: 20,
                        tint: color(for: context.state.stateName))
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .frame(width: 46)
            } minimal: {
                // The ring still carries the countdown; Pip sits inside it so the mark is the app's.
                ZStack {
                    ProgressView(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.circular)
                    .tint(color(for: context.state.stateName))
                    PipMark(mood: PipMarkMood(stateName: context.state.stateName),
                            size: 13,
                            tint: color(for: context.state.stateName))
                }
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<ScreenTimeActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color(for: context.state.stateName))
                PipMark(mood: isFinished(context) ? .cheering : PipMarkMood(stateName: context.state.stateName),
                        size: 34, tint: .white)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: context.attributes.childName)).font(.headline)
                Text(isFinished(context) ? "Screen time is finished ❤️" : line(for: context.state))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Group {
                if isFinished(context) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(color(for: context.state.stateName))
                } else {
                    Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .multilineTextAlignment(.trailing)
            .frame(width: 96)
        }
        .padding(16)
    }
}

// MARK: - Copy & colors (mirrors the app's Theme without depending on the app target)

/// D-021 — `isStale` means "the app has not been able to update this". The commonest cause is a
/// force-quit partway through a session: the countdown keeps ticking on its own (it is drawn from
/// absolute dates, Rule 4) but by the end nothing is left to retire the card. Rendering the stale
/// state as finished is what stops a dead card claiming a session is still running.
private func isFinished(_ context: ActivityViewContext<ScreenTimeActivityAttributes>) -> Bool {
    context.state.stateName == "finished" || context.isStale
}

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

/// D-016 — the name is optional, so there is a name-less form of every line.
private func title(for childName: String) -> String {
    childName.isEmpty ? "Screen time" : "\(childName)'s screen time"
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
