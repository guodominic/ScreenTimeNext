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

public enum NotificationKind: String, CaseIterable, Sendable {
    case warning10 = "screentimenext.warning10"
    case warning5  = "screentimenext.warning5"
    case warning1  = "screentimenext.warning1"
    case finished  = "screentimenext.finished"

    public var secondsBeforeEnd: Int {
        switch self {
        case .warning10: return WarningStateEngine.Threshold.warning10
        case .warning5:  return WarningStateEngine.Threshold.warning5
        case .warning1:  return WarningStateEngine.Threshold.warning1
        case .finished:  return 0
        }
    }
}

public enum NotificationPlan {

    /// Notifications for a window, honoring the parent's toggles (§6.6) and dropping anything
    /// already in the past. Copy per §6.11–§6.14, §7 — child-facing, no app names (§16).
    public static func make(for window: SessionWindow,
                            configuration: ScreenTimeConfiguration,
                            childName: String,
                            now: Date) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        for kind in NotificationKind.allCases {
            guard isEnabled(kind, configuration) else { continue }
            let fireDate = window.endsAt.addingTimeInterval(-TimeInterval(kind.secondsBeforeEnd))
            guard fireDate > now else { continue }
            let (title, body) = copy(for: kind, childName: childName, chosen: window.chosenActivity)
            result.append(PlannedNotification(identifier: kind.rawValue, fireDate: fireDate, title: title, body: body))
        }
        return result
    }

    static func isEnabled(_ kind: NotificationKind, _ config: ScreenTimeConfiguration) -> Bool {
        switch kind {
        case .warning10: return config.warning10Enabled
        case .warning5:  return config.warning5Enabled
        case .warning1:  return config.warning1Enabled
        case .finished:  return true
        }
    }

    static func copy(for kind: NotificationKind, childName: String, chosen: TransitionActivity?) -> (String, String) {
        switch kind {
        case .warning10:
            return ("10 minutes left 👋", "You're almost done, \(childName). What do you want to do next?")
        case .warning5:
            if let chosen {
                return ("5 minutes left", "Time to finish up. Next: \(chosen.displayName).")
            }
            return ("5 minutes left", "Time to finish up what you're doing.")
        case .warning1:
            return ("One more minute!", "Finish your game, \(childName).")
        case .finished:
            if let chosen {
                return ("Screen time is finished ❤️", "You chose \(chosen.displayName). \(chosen.invitation)")
            }
            return ("Screen time is finished ❤️", "Nice job, \(childName). Let's do something else now.")
        }
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
