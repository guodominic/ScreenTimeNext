//  StartWarning.swift
//  ScreenTimeNext
//
//  D-061 — the two ways a timer can look like it works and do nothing, in ONE place.
//
//  Both end the same way: the minutes run out and the device carries on exactly as before. The
//  parent finds out fifteen minutes later, and has no way to tell which of the two it was.
//
//  D-060 put this check on the dashboard's Start button and stopped there. That missed the case
//  that actually matters most — a parent who has just pressed "Start over" is sent to ONBOARDING,
//  whose own start button had no check at all, and a fresh setup is precisely when nothing has
//  been picked yet. The check now lives here so every door into a session asks the same question
//  and offers the same words.
//
//  §7 — a warning says what is true and offers the fix as the first thing to tap. It never scolds.

import Foundation

enum StartWarning: Identifiable, Equatable {
    /// The slide is green — every restriction is off until midnight.
    case restrictionsCleared
    /// No app, category or website has ever been picked.
    case nothingCovered

    var id: Int {
        switch self {
        case .restrictionsCleared: return 0
        case .nothingCovered:      return 1
        }
    }

    var title: String {
        switch self {
        case .restrictionsCleared: return "Restrictions are off today"
        case .nothingCovered:      return "Nothing is covered yet"
        }
    }

    var message: String {
        switch self {
        case .restrictionsCleared:
            return "You slid every restriction off for the rest of today, so a timer started now will not block anything, send reminders, or show a transition screen. It will just count."
        case .nothingCovered:
            return "No apps, categories or websites have been picked, so there is nothing for the timer to cover. It will count down, and nothing will happen when it ends."
        }
    }

    /// The first button: the thing that makes the warning go away for real.
    var fixLabel: String {
        switch self {
        case .restrictionsCleared: return "Put restrictions back"
        case .nothingCovered:      return "Pick apps now"
        }
    }

    /// The second button. Deliberately not "Cancel": a parent who means it should not have to
    /// argue with the app, and §17 says we inform rather than obstruct.
    var proceedLabel: String { "Start anyway" }
}
