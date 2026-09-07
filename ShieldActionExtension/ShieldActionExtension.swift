//  ShieldActionExtension.swift
//  ShieldActionExtension
//
//  Task 011 / D-012 — what the button on the shield does.
//
//  Two answers, and the difference between them is the whole design:
//    · MID-SESSION (a reminder): the button lifts ScreenTimeNext's own shield and the child carries
//      on with the minutes they still have. The shield was a heads-up, not the end.
//    · AT THE END: the button closes the app. It does NOT lift anything. §17 — a child can never
//      grant themselves more time; more time comes from a parent, on the parent's device.
//
//  Which of the two it is comes from `ShieldPresentation.primaryButtonContinues`, the same value
//  the in-app preview reads, so the button a parent demonstrated to their child behaves the way
//  they demonstrated (D-012).
//
//  Rule 3 — a moment, in its own process, app not running. Rule 6 — we lift OUR named store's four
//  keys and nothing else; `clearAllSettings()` appears nowhere in this codebase.
//
//  API verified against Apple's documentation (2026-09-06), per Rule 8:
//      ShieldActionDelegate — handle(action:for:completionHandler:) for
//          ApplicationToken · WebDomainToken · ActivityCategoryToken
//      ShieldAction: .primaryButtonPressed · .secondaryButtonPressed ·
//        .firstSecondarySubmenuItemPressed · .secondSecondarySubmenuItemPressed ·
//        .thirdSecondarySubmenuItemPressed        (this is why the switch needed five cases, and
//        it is also the whole reason the "pick what's next" shield is possible at all — three
//        submenu slots are the only list a system shield can offer)
//      ShieldActionResponse: .close · .defer · .none

import Foundation
import ManagedSettings
import ScreenTimeNextCore

class ShieldActionExtension: ShieldActionDelegate {

    // §16 — the token identifies which app the child tapped. It is never read, never stored, and
    // never needed: what happens next depends on the clock, not on which game it was.
    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    // MARK: The decision

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        // D-044 — the submenu cases are iOS 26.4+, so they cannot appear in the switch below
        // without dragging an availability annotation across the whole method.
        if #available(iOS 26.4, *), let index = Self.submenuIndex(of: action) {
            return choose(index: index)
        }

        switch action {
        case .primaryButtonPressed:
            // Mid-session: acknowledge and continue. Ended: close, and the shield stays up, so the
            // next tap on the same app shows the same screen rather than letting them back in.
            //
            // D-067 — and on the ask, the primary CLOSES, however many minutes are left. The
            // screen says "Close the app" and this is what makes that true.
            //
            // This is the one place the shield's words and its behaviour could drift apart: the
            // configuration extension draws the buttons and this one decides what they do, in two
            // processes that never meet. They agree because they ask the same resolver the same
            // question — not because two people remembered to change two files.
            guard !isAsking() else { return .close }
            guard shouldContinue() else { return .close }
            resumeClock()          // D-050 — pay back the time the shield was up, first
            liftShield()
            return .defer          // dismiss the shield and return the child to what they were doing

        default:
            // Every other button — including any this SDK has that we have not heard of — closes.
            // A control we do not recognise must never become a way through, and the template's
            // `fatalError()` here would have crashed in a child's face.
            return .close
        }
    }

    /// D-044 — which submenu item the child tapped, or nil for any other action. The cases are
    /// iOS 26.4+, which is why this is separate and annotated rather than inline.
    @available(iOS 26.4, *)
    private static func submenuIndex(of action: ShieldAction) -> Int? {
        switch action {
        case .firstSecondarySubmenuItemPressed:  return 0
        case .secondSecondarySubmenuItemPressed: return 1
        case .thirdSecondarySubmenuItemPressed:  return 2
        default: return nil
        }
    }

    /// Record the child's choice and let them carry on.
    ///
    /// The same list, built the same way, as the configuration extension used to draw the menu
    /// (`ShieldMomentResolver.chooserOptions`) — otherwise a child could tap "LEGO" and get "Bath".
    private func choose(index: Int) -> ShieldActionResponse {
        guard let storage = try? FileStorageService.shared() else { return .close }
        // D-072 — the parent's list, in the parent's order, exactly as the configuration extension
        // built it when it drew this menu.
        let available = ((try? storage.loadPickerPreferences()) ?? .default).allActivities

        if let activity = ShieldMomentResolver.activity(forSubmenuIndex: index,
                                                        availableActivities: available) {
            // No presence or notifications here: this process has neither, and the choice is
            // written to the window, which is what the app and the Live Activity read from.
            _ = try? SessionController(storage: storage).choose(activity)
        }
        resumeClock()              // D-050 — deciding took time; it was not their screen time
        guard shouldContinue() else { return .close }
        liftShield()
        return .defer
    }

    /// D-067 — is this the screen that asks? Same resolver, same inputs as the one that drew it.
    private func isAsking() -> Bool {
        guard let storage = try? FileStorageService.shared() else { return false }
        let moment = ShieldMomentResolver.moment(
            window: (try? storage.loadSessionWindow()) ?? nil,
            configuration: (try? storage.loadConfiguration()) ?? .default,
            availableActivities: ((try? storage.loadPickerPreferences()) ?? .default).allActivities)
        if case .chooseNext = moment { return true }
        return false
    }

    /// True only while there is time left on the stored window. Read from absolute timestamps, so
    /// a device that slept, changed timezone, or sat unopened for an hour gets the right answer.
    private func shouldContinue() -> Bool {
        guard let storage = try? FileStorageService.shared(),
              let window = try? storage.loadSessionWindow() else { return false }
        return window.remainingSeconds(at: Date()) > 0
    }

    /// Rule 6 — OUR four keys in OUR named store. Never `clearAllSettings()`, which would also
    /// erase whatever Apple's Screen Time and any other parental-control app wrote to this device.
    ///
    /// The typed-website filter (D-033) is deliberately NOT lifted: those are sites a parent blocked
    /// outright, not part of the budget, and a reminder is not permission to visit them.
    /// D-050 — hand back the seconds the shield was up before letting the child carry on.
    ///
    /// This process has no `DeviceActivity`, so it moves the window and leaves the alarms where
    /// they are. The end alarm then fires early, finds time left, and re-arms itself from the new
    /// end. An early alarm is self-correcting; a missing one would end the session in silence.
    private func resumeClock() {
        guard let storage = try? FileStorageService.shared() else { return }
        MonitorJournal()?.creditPause(to: storage)
    }

    private func liftShield() {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("screentimenext"))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        if let storage = try? FileStorageService.shared() {
            try? storage.save(ProtectionState.unshielded)
        }
    }
}
