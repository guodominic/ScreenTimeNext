//  ShieldPresentation.swift
//  ScreenTimeNextCore
//
//  D-012. Everything that appears on the full-screen interstitial the child sees inside the app
//  they are using. Pure data, framework-free, so:
//    · the in-app preview (Phase 0) renders it today, and it can be shown to real children;
//    · the ShieldConfiguration extension (Phase 1) builds a `ShieldConfiguration` from the very
//      same values — the design settled here transfers unchanged;
//    · the copy is unit-testable against the §7 rules.
//
//  PRD §6.15, §7. Nothing here names an app or leaks a selection token (§16).

import Foundation

/// What the child is being shown, and what the button does.
public enum ShieldMoment: Hashable, Sendable {
    /// A reminder mid-session. The button lifts our shield so the remaining minutes continue.
    case reminder(minutesLeft: Int, activity: TransitionActivity?)
    /// D-044 / D-050 — the reminder that asks. Same shield, plus a menu of what to do after;
    /// picking one IS the "OK", and it lifts the shield for the minutes that remain.
    ///
    /// D-065 — there was a `mustChoose` flag here, for the last ask that refused to let a child
    /// past without deciding. It is gone: enforcing it meant a shield with no primary button, and
    /// that shield was rejected by iOS in favour of its own grey screen. What a child sees is now
    /// decided by one thing — have they chosen? Not chosen: the minutes AND the list. Chosen: the
    /// minutes. A rule with one input cannot produce a screen nobody predicted.
    case chooseNext(minutesLeft: Int, options: [TransitionActivity])
    /// D-072 — the parent decided, so this is a reminder that TELLS rather than asks. No menu, no
    /// list, nothing to pick: the screen states what is happening after and lets the child carry
    /// on with the minutes they have left.
    ///
    /// It is a separate case rather than a flag on `.reminder` because it is a different screen
    /// with different words. `.reminder` says "you picked Outside"; this one cannot, because they
    /// did not, and reusing the case would have meant one of the two moments lying.
    case parentChoseNext(minutesLeft: Int, activity: TransitionActivity)
    /// The session just ended. The button sends the child to the Home Screen; it never lifts.
    case finished(activity: TransitionActivity?)
    /// D-072 — the end, when the parent chose. Same button, honest copy.
    case finishedParentChose(activity: TransitionActivity)
    /// A protected app opened later in the day with the budget already spent.
    case spentForToday
}

/// How close the child is to the end — the ONE thing that drives the interstitial's colour and
/// Pip's expression (D-018).
///
/// Before D-018 the card was tinted by the activity the child had chosen, so every reminder came
/// up a different, arbitrary colour and the screen said nothing about time. Now the ramp is the
/// message: green while there is room, orange when it is time to wrap up, red on the last stretch,
/// and only the finish is celebratory.
public enum ShieldUrgency: String, Hashable, Sendable, CaseIterable {
    /// First reminder — plenty of runway. Green.
    case calm
    /// Middle reminder — start finishing up. Orange.
    case soon
    /// Last reminder before the end. Red.
    case last
    /// The session just ended. Celebratory, and the only moment that is multi-coloured.
    case finished
    /// A protected app opened later with the budget already gone. Quiet, not alarming.
    case spent

    /// The ramp for reminder `index` of `count`. A lone reminder is the last one, not the first —
    /// `WarningStateEngine.role(ofWarningAt:count:)` calls index 0 `.firstWarning` for its own
    /// state-machine reasons, which is not the colour we want when there is only one.
    public static func forWarning(index: Int, count: Int) -> ShieldUrgency {
        guard count > 1 else { return .last }
        if index == 0 { return .calm }
        if index >= count - 1 { return .last }
        return .soon
    }

    /// The ramp implied by the session state, for callers that hold a snapshot rather than an index.
    public static func from(state: ScreenTimeState) -> ShieldUrgency {
        switch state {
        case .idle, .active, .extended: return .calm
        case .firstWarning:  return .calm
        case .secondWarning: return .soon
        case .finalWarning:  return .last
        case .finished:      return .finished
        }
    }

    /// Fallback when only the clock is known: the last minute is red, single digits are orange.
    public static func fromMinutesLeft(_ minutes: Int) -> ShieldUrgency {
        if minutes <= 1 { return .last }
        if minutes <= 5 { return .soon }
        return .calm
    }
}

public struct ShieldPresentation: Hashable, Sendable {
    public let title: String
    public let subtitle: String
    /// SF Symbol name. The extension turns this into a UIImage; the preview into an Image.
    public let symbolName: String
    /// D-065 — always present again.
    ///
    /// D-056 made this optional so the insisting ask could have NO primary button. That produced a
    /// `ShieldConfiguration` with a primary button COLOUR and no primary button, and the screen a
    /// child got was Apple's own grey "Restricted" — iOS appears to reject the configuration and
    /// fall back, silently, exactly on the moment that matters most.
    ///
    /// The lesson is narrower than "don't remove buttons": a shield is a set of values handed to a
    /// process we cannot see, and a combination we have not seen work is a combination we do not
    /// know works. Every field is filled or the whole screen is forfeit.
    public let primaryButtonLabel: String
    /// True when pressing the primary button should lift ScreenTimeNext's own shield and let the
    /// child continue. False means the button only closes the app — never a bypass (§17).
    public let primaryButtonContinues: Bool
    /// D-044 — the secondary button, when there is one. `ShieldConfiguration` gives it an optional
    /// submenu of at most THREE items, which is the only list a system shield can show.
    public let secondaryButtonLabel: String?
    /// What the submenu offers, in order. Empty when there is no submenu. Capped at three by
    /// `ShieldMomentResolver.chooserOptions` — the platform's limit, not ours.
    public let submenuItems: [String]
    /// Which activity was chosen for after, if any. Used for the copy and the small badge — NOT
    /// for the card's colour any more (D-018); `urgency` owns colour.
    public let activity: TransitionActivity?
    /// How close the end is. Drives the tint and Pip's expression, and nothing else.
    public let urgency: ShieldUrgency

    public init(title: String, subtitle: String, symbolName: String,
                primaryButtonLabel: String, primaryButtonContinues: Bool,
                activity: TransitionActivity?,
                urgency: ShieldUrgency,
                secondaryButtonLabel: String? = nil,
                submenuItems: [String] = []) {
        self.secondaryButtonLabel = secondaryButtonLabel
        self.submenuItems = submenuItems
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.primaryButtonLabel = primaryButtonLabel
        self.primaryButtonContinues = primaryButtonContinues
        self.activity = activity
        self.urgency = urgency
    }

    /// "LEGO, Outside or Snack" — the child's own options, in the parent's order.
    static func list(_ options: [TransitionActivity]) -> String {
        let names = options.map(\.displayName)
        switch names.count {
        case 0:  return ""
        case 1:  return names[0]
        case 2:  return "\(names[0]) or \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " or " + (names.last ?? "")
        }
    }

    /// The one place shield copy is written. Child-facing: warm, concrete, names what comes next,
    /// never punitive, never technical (§7).
    ///
    /// `urgency` is the colour ramp. Pass it when the caller knows which reminder this is (the
    /// session controller and the preview both do); leave it nil and it is inferred from the clock.
    public static func make(for moment: ShieldMoment,
                            childName: String,
                            urgency: ShieldUrgency? = nil) -> ShieldPresentation {
        let name = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        let addressed = name.isEmpty ? "" : ", \(name)"

        switch moment {
        case let .reminder(minutes, activity):
            let left = minutes == 1 ? "1 minute left" : "\(minutes) minutes left"
            let subtitle: String
            if let activity {
                subtitle = "You picked \(activity.displayName) for after. Finish up, then \(activity.invitation.lowercasedFirst)"
            } else {
                subtitle = "Time to start finishing up what you're doing."
            }
            return ShieldPresentation(
                title: "\(left)\(addressed)",
                subtitle: subtitle,
                symbolName: activity?.symbolName ?? "hourglass",
                primaryButtonLabel: minutes == 1 ? "OK, one more minute" : "OK, \(minutes) more minutes",
                primaryButtonContinues: true,
                activity: activity,
                urgency: urgency ?? .fromMinutesLeft(minutes)
            )

        case let .chooseNext(minutes, options):
            let left = minutes == 1 ? "1 minute left" : "\(minutes) minutes left"
            return ShieldPresentation(
                title: "\(left)\(addressed)",
                // D-049 — the options are NAMED here, because the system hides them behind the
                // secondary button until it is tapped: `secondaryButtonSubmenuItems` is a menu, not
                // a list on the screen. A child saw a time and two buttons and no sign there was
                // anything to choose, which is the same as there being nothing.
                subtitle: options.isEmpty
                    ? "Time to start finishing up what you're doing."
                    : "\(Self.list(options)) — pick one and keep playing.",
                symbolName: "hand.tap.fill",
                // §17 — the primary button never buys more time. Choosing is the way onward, which
                // is the point: the child decides what comes next while the screen time is still
                // theirs, not once it has already been taken away.
                //
                // D-050 — on the LAST ask there is no "not yet": the button says what to do and
                // does nothing else, so the menu is the only way back into the app. The child can
                // always leave for the Home Screen, which is a real choice and not our business to
                // prevent — what we refuse is a way to carry on WITHOUT deciding.
                // D-067 — the ask insists, from the very first one, and it does so WITHOUT
                // removing a button (D-065: a shield with a button colour and no button is a
                // shield iOS replaces with its own grey screen).
                //
                // So the primary button stays and says exactly what it does: it closes the app.
                // That is a real choice and an honest one — the child can always leave, and
                // leaving is not something we get to prevent. What we refuse is a way to carry on
                // INSIDE the app without deciding. The way back in is the list.
                primaryButtonLabel: "Close the app",
                primaryButtonContinues: false,
                activity: nil,
                urgency: urgency ?? .fromMinutesLeft(minutes),
                secondaryButtonLabel: options.isEmpty ? nil : "What's next?",
                submenuItems: options.map(\.displayName)
            )

        case let .parentChoseNext(minutes, activity):
            let left = minutes == 1 ? "1 minute left" : "\(minutes) minutes left"
            return ShieldPresentation(
                title: "\(left)\(addressed)",
                // Stated, not sold. A child who is told what happens next can get ready for it;
                // a child who is asked a question whose answer is already fixed learns that the
                // asking is theatre.
                subtitle: "Next is \(activity.displayName). Finish up, then \(activity.invitation.lowercasedFirst)",
                symbolName: activity.symbolName,
                primaryButtonLabel: minutes == 1 ? "OK, one more minute" : "OK, \(minutes) more minutes",
                primaryButtonContinues: true,
                activity: activity,
                urgency: urgency ?? .fromMinutesLeft(minutes)
            )

        case let .finishedParentChose(activity):
            return ShieldPresentation(
                title: "Screen time is finished ❤️",
                subtitle: "Next is \(activity.displayName)\(addressed). \(activity.invitation)",
                symbolName: activity.symbolName,
                primaryButtonLabel: "Let's go!",
                primaryButtonContinues: false,
                activity: activity,
                urgency: .finished
            )

        case let .finished(activity):
            if let activity {
                return ShieldPresentation(
                    title: "Screen time is finished ❤️",
                    subtitle: "You chose \(activity.displayName)\(addressed). \(activity.invitation)",
                    symbolName: activity.symbolName,
                    primaryButtonLabel: "Let's go!",
                    primaryButtonContinues: false,
                    activity: activity,
                    urgency: .finished
                )
            }
            return ShieldPresentation(
                title: "Screen time is finished ❤️",
                subtitle: "Nice job\(addressed). Let's do something else now.",
                symbolName: "hands.clap.fill",
                primaryButtonLabel: "OK",
                primaryButtonContinues: false,
                activity: nil,
                urgency: .finished
            )

        case .spentForToday:
            return ShieldPresentation(
                title: "All done for today",
                subtitle: "You've used today's screen time. See you tomorrow\(addressed)!",
                symbolName: "moon.stars.fill",
                primaryButtonLabel: "OK",
                primaryButtonContinues: false,
                activity: nil,
                urgency: .spent
            )
        }
    }
}

extension String {
    /// "Let's go build!" → "let's go build!" for use mid-sentence.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
