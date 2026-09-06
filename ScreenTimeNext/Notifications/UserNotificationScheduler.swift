//  UserNotificationScheduler.swift
//  ScreenTimeNext
//
//  Task 016. The only file that talks to UserNotifications. Fire dates come straight from the
//  plan (absolute timestamps, Rule 4); identifiers are stable per kind so a reschedule replaces.
//  No app names or selection details ever appear in notification content (§16).

import Foundation
import UserNotifications
import ScreenTimeNextCore

/// `nonisolated`: the app target defaults to MainActor isolation, but this type must satisfy
/// the nonisolated `NotificationScheduling` requirements and be callable from SessionController.
nonisolated final class UserNotificationScheduler: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate, @unchecked Sendable {

    private let center = UNUserNotificationCenter.current()
    private let identifiers = NotificationIdentifier.all

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: NotificationScheduling

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    var isPermissionDenied: Bool {
        get async { await center.notificationSettings().authorizationStatus == .denied }
    }

    func replaceAll(with plan: [PlannedNotification]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            // Breaks through Focus and the scheduled summary once the Time Sensitive Notifications
            // capability is on the target (Phase 1). Without it iOS quietly treats this as `.active`.
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["route": "childTimer"]
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
        }
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: UNUserNotificationCenterDelegate
    //
    // BOTH of these are `@MainActor`, and that is load-bearing — it is not tidiness.
    //
    // The `async` form of these delegate methods is the Swift bridge over an ObjC method with a
    // completion handler, and UIKit runs that completion handler on WHATEVER thread the async
    // function finishes on. When it finishes off the main thread, UIKit's own follow-up work
    // (`-[UIApplication _updateSnapshotAndStateRestoration…]`) asserts and the app dies with
    // "Call must be made on main thread" — a crash the child sees, in their hand, from tapping a
    // reminder we sent them.
    //
    // `nonisolated` was the exact wrong answer here. It made the crash certain rather than likely:
    // a nonisolated async method always resumes off the main actor, so `await MainActor.run { … }`
    // as the last statement hops TO main, posts, and hops straight back OFF it before returning.
    // Marking the method `@MainActor` is what makes the completion handler run where UIKit requires
    // (Apple DTS, developer.apple.com/forums/thread/709563), and it removes the need for the inner
    // `MainActor.run` entirely.

    /// Show the banner even when ScreenTimeNext itself is in the foreground (the child may be on
    /// the timer screen at the 1-minute mark).
    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// The child tapped a warning: land on the timer, never on the parent dashboard.
    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // Every ScreenTimeNext notification is about the session, so any tap goes to the timer —
        // never to the parent dashboard.
        let isOurs = NotificationIdentifier.all.contains(response.notification.request.identifier)
        guard isOurs else { return }
        // Latch first: on a cold launch this callback runs before RootView is listening.
        TimerRoutingLatch.shared.request()
        // Already on the main actor (see the note above), so this is a plain call.
        NotificationCenter.default.post(name: .openChildTimer, object: nil)
    }
}

extension Notification.Name {
    /// Posted when the app should present the child timer (notification tap, session running).
    static let openChildTimer = Notification.Name("screentimenext.openChildTimer")

    /// D-019 — the parent saved Settings. Anything showing parent-owned values re-reads them.
    static let configurationDidChange = Notification.Name("screentimenext.configurationDidChange")
}

/// D-018 — tapping a reminder must land on the timer, including on a cold launch.
///
/// The broadcast alone is not enough: when the app is launched BY the tap, iOS delivers
/// `didReceive` while SwiftUI is still building the first view, so the notification is posted
/// before `RootView` is listening and nothing happens. This latch records the request instead, and
/// `RootView` drains it as soon as it has finished routing. Both paths stay — the broadcast handles
/// the warm case immediately, the latch catches the cold one.
nonisolated final class TimerRoutingLatch: @unchecked Sendable {
    static let shared = TimerRoutingLatch()

    private let lock = NSLock()
    private var requested = false

    func request() { lock.withLock { requested = true } }

    /// Reads and clears in one step, so a request is honoured exactly once.
    func consume() -> Bool {
        lock.withLock {
            defer { requested = false }
            return requested
        }
    }
}
