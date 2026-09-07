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

        // D-072 — the parent's own answer, which outranks the child's wherever both exist.
        let parentChoice = configuration.parentChosenActivity

        let remaining = window.remainingSeconds(at: now)
        guard remaining > 0 else {
            if let parentChoice { return .finishedParentChose(activity: parentChoice) }
            return .finished(activity: window.chosenActivity)
        }

        // Round UP: with 61 seconds left a child should be told "2 minutes", not "1" — the number
        // has to still be true a moment after they read it.
        let minutesLeft = max(1, Int((Double(remaining) / 60).rounded(.up)))

        // D-065 — WHICH reminder this is no longer changes the screen, only whether one is due.
        let offsets = configuration.effectiveWarningOffsets(forWindowSeconds: window.totalSeconds)
        guard WarningStateEngine.reachedWarningIndex(remainingSeconds: remaining,
                                                     warningOffsets: offsets) != nil else {
            // Shielded between reminders — the parent raised it, or a reminder shield was never
            // dismissed. Treat it as a plain heads-up rather than inventing a fourth kind.
            if let parentChoice { return .parentChoseNext(minutesLeft: minutesLeft, activity: parentChoice) }
            return .reminder(minutesLeft: minutesLeft, activity: window.chosenActivity)
        }

        // D-072 — the parent decided, so there is nothing to ask and nothing to offer. This is
        // checked BEFORE the chooser on purpose: a menu whose result would be discarded is worse
        // than no menu, because the child spends a decision on it.
        if let parentChoice {
            return .parentChoseNext(minutesLeft: minutesLeft, activity: parentChoice)
        }

        // D-050 — ask from the FIRST reminder, and keep asking until they answer.
        //
        // D-044 asked only on the last one, so a child who wanted to decide early could not, and a
        // child who missed that single screen was never asked at all. Asking early is also the
        // gentler version: the choice arrives while there is still time to enjoy making it.
        //
        // A child who has already chosen gets the plain reminder — re-asking reads as "that wasn't
        // good enough" and costs a tap for nothing.
        if window.chosenActivity == nil,
           supportsChooserMenu,
           !chooserOptions(availableActivities).isEmpty {
            // D-065 — every ask looks the same, and asks again until they answer. Insisting cost
            // more than it bought: see `ShieldMoment.chooseNext`.
            return .chooseNext(minutesLeft: minutesLeft,
                               options: chooserOptions(availableActivities))
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
