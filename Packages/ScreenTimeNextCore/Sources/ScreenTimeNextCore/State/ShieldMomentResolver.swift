//  ShieldMomentResolver.swift
//  ScreenTimeNextCore
//
//  D-044 — which of the three shields a child is looking at, decided in ONE place.
//
//  Two separate extension processes need this answer and must never disagree: the configuration
//  extension draws the screen, and the action extension decides what its buttons do. If they
//  computed "which moment is this" independently, a child could be shown a chooser whose menu the
//  other process resolves against a different list — and pick "LEGO" and get "Bath".
//
//  Framework-free on purpose (Foundation only), so it can live in the package both extensions
//  already link rather than in the app target neither of them is.
//
//  The sequence, from the child's side:
//    1. first reminder   — "5 minutes left", OK, carry on
//    2. last reminder    — "1 minute left", pick what's next, carry on
//    3. the end          — time's up, and the button only closes
//
//  §16: nothing here sees an app, a token, or a selection. It reads a clock and a list the parent
//  wrote themselves.

import Foundation

public enum ShieldMomentResolver {

    /// `ShieldConfiguration` offers a secondary button with a submenu of at most THREE items — the
    /// only list a system shield can show. So the child is offered the first three the PARENT
    /// arranged, which is what the drag-to-reorder in Settings is for (D-039): the order they chose
    /// decides what their child sees here.
    public static let maxChooserOptions = 3

    public static func chooserOptions(_ activities: [TransitionActivity]) -> [TransitionActivity] {
        Array(activities.prefix(maxChooserOptions))
    }

    /// Whether this device can show the chooser at all.
    ///
    /// `ShieldConfiguration`'s submenu — and the `ShieldAction` cases that report which item was
    /// tapped — are **iOS 26.4+**. The app itself supports iOS 18, so on anything older there is
    /// simply no way for a system shield to offer a list, and pretending otherwise would give a
    /// child a button that does nothing.
    ///
    /// Where the menu is unavailable the second reminder becomes an ordinary heads-up and the
    /// child picks what's next inside ScreenTimeNext, the way they did before D-044. Less good,
    /// still whole.
    public static var supportsChooserMenu: Bool {
        if #available(iOS 26.4, *) { return true }
        return false
    }

    /// What to show right now.
    ///
    /// `availableActivities` is what the child may choose from — the parent's picks, in the
    /// parent's order. Pass the same list to both extensions.
    public static func moment(window: SessionWindow?,
                              configuration: ScreenTimeConfiguration,
                              availableActivities: [TransitionActivity],
                              now: Date = Date()) -> ShieldMoment {
        guard let window else {
            // The shield is up with no session behind it: the budget went earlier today.
            return .spentForToday
        }

        let remaining = window.remainingSeconds(at: now)
        guard remaining > 0 else { return .finished(activity: window.chosenActivity) }

        // Round UP: with 61 seconds left a child should be told "2 minutes", not "1" — the number
        // has to still be true a moment after they read it.
        let minutesLeft = max(1, Int((Double(remaining) / 60).rounded(.up)))

        let offsets = configuration.effectiveWarningOffsets(forWindowSeconds: window.totalSeconds)
        guard let index = WarningStateEngine.reachedWarningIndex(remainingSeconds: remaining,
                                                                 warningOffsets: offsets) else {
            // Shielded between reminders — the parent raised it, or a reminder shield was never
            // dismissed. Treat it as a plain heads-up rather than inventing a fourth kind.
            return .reminder(minutesLeft: minutesLeft, activity: window.chosenActivity)
        }

        // Ask only once. A child who has already chosen gets the plain reminder: re-asking would
        // read as "that wasn't good enough", and it costs them a tap for nothing.
        if WarningStateEngine.isChooser(warningAt: index, count: offsets.count),
           window.chosenActivity == nil,
           supportsChooserMenu,
           !chooserOptions(availableActivities).isEmpty {
            return .chooseNext(minutesLeft: minutesLeft, options: chooserOptions(availableActivities))
        }
        return .reminder(minutesLeft: minutesLeft, activity: window.chosenActivity)
    }

    /// The activity a submenu index maps to, or nil when the index is out of range — which can
    /// happen if the parent edits their list while a shield is on screen. Nil means "do nothing"
    /// rather than "pick something", because guessing on a child's behalf is worse than a no-op.
    public static func activity(forSubmenuIndex index: Int,
                                availableActivities: [TransitionActivity]) -> TransitionActivity? {
        let options = chooserOptions(availableActivities)
        guard options.indices.contains(index) else { return nil }
        return options[index]
    }
}
