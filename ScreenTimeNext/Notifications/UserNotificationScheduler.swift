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

    /// Show the banner even when ScreenTimeNext itself is in the foreground (the child may be on
    /// the timer screen at the 1-minute mark).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// The child tapped a warning: land on the timer, never on the parent dashboard.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        // Every ScreenTimeNext notification is about the session, so any tap goes to the timer —
        // never to the parent dashboard.
        let isOurs = NotificationIdentifier.all.contains(response.notification.request.identifier)
        guard isOurs else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .openChildTimer, object: nil)
        }
    }
}

extension Notification.Name {
    /// Posted when the app should present the child timer (notification tap, session running).
    static let openChildTimer = Notification.Name("screentimenext.openChildTimer")
}
