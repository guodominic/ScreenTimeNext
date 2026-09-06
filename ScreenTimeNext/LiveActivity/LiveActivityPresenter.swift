//  LiveActivityPresenter.swift
//  ScreenTimeNext
//
//  D-014. Starts/updates/ends the ScreenTimeNext Live Activity. The countdown itself is rendered
//  by the widget with `Text(timerInterval:)`, so it keeps ticking with no process running (Rule 4).
//  Requires NSSupportsLiveActivities in the app's Info.plist and the ScreenTimeNextWidgets target.

import Foundation
import ScreenTimeNextCore

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

nonisolated final class LiveActivityPresenter: SessionPresenting, @unchecked Sendable {

    func show(_ state: SessionPresenceState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ScreenTimeActivityAttributes.ContentState(
            startedAt: state.startedAt,
            endsAt: state.endsAt,
            chosenActivityRaw: state.chosenActivity?.rawValue,
            stateName: state.stateName
        )
        // ActivityKit asserts "Call must be made on main thread" — hop to the main actor.
        Task { @MainActor in
            if let current = Activity<ScreenTimeActivityAttributes>.activities.first {
                await current.update(ActivityContent(state: content, staleDate: state.endsAt))
            } else {
                _ = try? Activity.request(
                    attributes: ScreenTimeActivityAttributes(childName: state.childName),
                    content: ActivityContent(state: content, staleDate: state.endsAt),
                    pushType: nil
                )
            }
        }
    }

    /// D-021 — the window ran out. Show "finished" and let iOS retire the card on its own a few
    /// minutes later, rather than yanking it away the instant the timer hits zero.
    ///
    /// `end(_:dismissalPolicy:)` is the only way to schedule a dismissal, and it is one-way: the
    /// activity stops being updatable. That is fine here — the session is over.
    func finish(_ state: SessionPresenceState) {
        let content = ScreenTimeActivityAttributes.ContentState(
            startedAt: state.startedAt,
            endsAt: state.endsAt,
            chosenActivityRaw: state.chosenActivity?.rawValue,
            stateName: state.stateName
        )
        let dismissAt = Date().addingTimeInterval(Self.finishedLingerSeconds)
        Task { @MainActor in
            for activity in Activity<ScreenTimeActivityAttributes>.activities {
                await activity.end(ActivityContent(state: content, staleDate: nil),
                                   dismissalPolicy: .after(dismissAt))
            }
        }
    }

    func hide() {
        Task { @MainActor in
            for activity in Activity<ScreenTimeActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Long enough for a parent to notice on the Lock Screen, short enough not to become clutter.
    private static let finishedLingerSeconds: TimeInterval = 10 * 60
}
#else
nonisolated final class LiveActivityPresenter: SessionPresenting, @unchecked Sendable {
    func show(_ state: SessionPresenceState) {}
    func finish(_ state: SessionPresenceState) {}
    func hide() {}
}
#endif
