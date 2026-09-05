//  NotificationScheduling.swift
//  ScreenTimeNextCore
//
//  Task 016. Local notifications carry the 10/5/1 warnings and the expiry to the child while
//  they are in another app (which, during screen time, is always). Rule 4 — every fire date is
//  derived from the SessionWindow's absolute timestamps, never from a relative offset.
//  The plan is pure; the app target implements the scheduler on UserNotifications.

import Foundation

public struct PlannedNotification: Equatable, Sendable {
    /// Stable per kind, so rescheduling replaces rather than duplicates.
    public let identifier: String
    public let fireDate: Date
    public let title: String
    public let body: String

    public init(identifier: String, fireDate: Date, title: String, body: String) {
        self.identifier = identifier
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}

/// Stable identifiers: three warning slots (earliest-first) plus the expiry.
public enum NotificationIdentifier {
    public static func warning(_ index: Int) -> String { "screentimenext.warning.\(index)" }
    public static let finished = "screentimenext.finished"
    /// Everything ScreenTimeNext might have scheduled — used to cancel/replace.
    public static let all: [String] = (0..<ScreenTimeConfiguration.maxWarnings).map(warning) + [finished]
}

public enum NotificationPlan {

    /// Notifications for a window, honoring the parent's warning offsets (D-013) and dropping
    /// anything already in the past. Copy per §6.11–§6.14, §7 — child-facing, no app names (§16).
    public static func make(for window: SessionWindow,
                            configuration: ScreenTimeConfiguration,
                            childName: String,
                            now: Date) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        let offsets = configuration.effectiveWarningOffsets(forWindowSeconds: window.totalSeconds)
        for (index, offset) in offsets.enumerated() {
            let fireDate = window.endsAt.addingTimeInterval(-TimeInterval(offset))
            guard fireDate > now else { continue }
            let role = WarningStateEngine.role(ofWarningAt: index, count: offsets.count)
            let (title, body) = warningCopy(role: role, minutes: max(1, offset / 60), childName: childName, chosen: window.chosenActivity)
            result.append(PlannedNotification(identifier: NotificationIdentifier.warning(index), fireDate: fireDate, title: title, body: body))
        }
        if window.endsAt > now {
            let (title, body) = finishedCopy(childName: childName, chosen: window.chosenActivity)
            result.append(PlannedNotification(identifier: NotificationIdentifier.finished, fireDate: window.endsAt, title: title, body: body))
        }
        return result
    }

    public static func warningCopy(role: ScreenTimeState, minutes: Int, childName: String, chosen: TransitionActivity?) -> (String, String) {
        let left = minutes == 1 ? "1 minute left" : "\(minutes) minutes left"
        switch role {
        case .firstWarning:
            return ("\(left) 👋", "You're almost done, \(childName). What do you want to do next?")
        case .secondWarning:
            if let chosen { return (left, "Time to finish up. Next: \(chosen.displayName).") }
            return (left, "Time to finish up what you're doing.")
        default:
            let title = minutes == 1 ? "One more minute!" : "\(left)!"
            if let chosen { return (title, "Finish your game, \(childName). Then: \(chosen.displayName)!") }
            return (title, "Finish your game, \(childName).")
        }
    }

    public static func finishedCopy(childName: String, chosen: TransitionActivity?) -> (String, String) {
        if let chosen {
            return ("Screen time is finished ❤️", "You chose \(chosen.displayName). \(chosen.invitation)")
        }
        return ("Screen time is finished ❤️", "Nice job, \(childName). Let's do something else now.")
    }
}

/// Implemented by the app on UserNotifications; mocked in tests. Kept framework-free here.
public protocol NotificationScheduling: Sendable {
    /// Ask the system for permission (parent flow only). True when granted.
    func requestPermission() async -> Bool
    /// True when the parent has explicitly declined — the dashboard offers a way to Settings.
    var isPermissionDenied: Bool { get async }
    /// Replace every ScreenTimeNext notification with this plan.
    func replaceAll(with plan: [PlannedNotification])
    /// Remove every ScreenTimeNext notification (session ended, day rolled over).
    func cancelAll()
}

/// Records calls. Phase 0 tests and previews.
public final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var _plans: [[PlannedNotification]] = []
    private var _cancelCount = 0
    public var grants = true
    public init() {}
    public func requestPermission() async -> Bool { grants }
    public var isPermissionDenied: Bool { get async { !grants } }
    public func replaceAll(with plan: [PlannedNotification]) { lock.withLock { _plans.append(plan) } }
    public func cancelAll() { lock.withLock { _cancelCount += 1 } }
    public var plans: [[PlannedNotification]] { lock.withLock { _plans } }
    public var latestPlan: [PlannedNotification]? { lock.withLock { _plans.last } }
    public var cancelCount: Int { lock.withLock { _cancelCount } }
}
