//  LiveActivityPresenter.swift
//  ScreenTimeNext
//
//  D-014. Starts/updates/ends the ScreenTimeNext Live Activity. The countdown itself is rendered
//  by the widget with `Text(timerInterval:)`, so it keeps ticking with no process running (Rule 4).
//  Requires NSSupportsLiveActivities in the app's Info.plist and the ScreenTimeNextWidgets target.

import Foundation
import ScreenTimeNextCore

#if canImport(ActivityKit)
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
        Task {
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

    func hide() {
        Task {
            for activity in Activity<ScreenTimeActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#else
nonisolated final class LiveActivityPresenter: SessionPresenting, @unchecked Sendable {
    func show(_ state: SessionPresenceState) {}
    func hide() {}
}
#endif
