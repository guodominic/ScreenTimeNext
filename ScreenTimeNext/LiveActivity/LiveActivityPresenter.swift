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
            chosenActivityRaw: state.chosenActivity?.id,
            chosenActivityName: state.chosenActivity?.displayName,
            chosenActivitySymbol: state.chosenActivity?.symbolName,
            stateName: state.stateName
        )
        // ActivityKit asserts "Call must be made on main thread" — hop to the main actor.
        Task { @MainActor in
            // D-053 — `finish` ends the activity, and `end` is ONE-WAY: the card lingers in
            // `activities` for ten more minutes but no longer accepts updates. Updating it there
            // is a silent no-op, which is exactly what a parent saw when they added three minutes
            // to a finished session and the Dynamic Island went on saying nothing. So: only an
            // `.active` activity is updated; anything else is retired and replaced.
            let live = Activity<ScreenTimeActivityAttributes>.activities
            if let current = live.first(where: { $0.activityState == .active }) {
                await current.update(ActivityContent(state: content, staleDate: state.endsAt))
                return
            }
            for stale in live {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
            _ = try? Activity.request(
                attributes: ScreenTimeActivityAttributes(childName: state.childName),
                content: ActivityContent(state: content, staleDate: state.endsAt),
                pushType: nil
            )
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
            chosenActivityRaw: state.chosenActivity?.id,
            chosenActivityName: state.chosenActivity?.displayName,
            chosenActivitySymbol: state.chosenActivity?.symbolName,
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
