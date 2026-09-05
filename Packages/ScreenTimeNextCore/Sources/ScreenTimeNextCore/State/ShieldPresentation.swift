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
    /// The session just ended. The button sends the child to the Home Screen; it never lifts.
    case finished(activity: TransitionActivity?)
    /// A protected app opened later in the day with the budget already spent.
    case spentForToday
}

public struct ShieldPresentation: Hashable, Sendable {
    public let title: String
    public let subtitle: String
    /// SF Symbol name. The extension turns this into a UIImage; the preview into an Image.
    public let symbolName: String
    public let primaryButtonLabel: String
    /// True when pressing the primary button should lift ScreenTimeNext's own shield and let the
    /// child continue. False means the button only closes the app — never a bypass (§17).
    public let primaryButtonContinues: Bool
    /// Which activity's color to tint with, if any; nil means use the app's own accent.
    public let activity: TransitionActivity?

    public init(title: String, subtitle: String, symbolName: String,
                primaryButtonLabel: String, primaryButtonContinues: Bool,
                activity: TransitionActivity?) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.primaryButtonLabel = primaryButtonLabel
        self.primaryButtonContinues = primaryButtonContinues
        self.activity = activity
    }

    /// The one place shield copy is written. Child-facing: warm, concrete, names what comes next,
    /// never punitive, never technical (§7).
    public static func make(for moment: ShieldMoment, childName: String) -> ShieldPresentation {
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
                activity: activity
            )

        case let .finished(activity):
            if let activity {
                return ShieldPresentation(
                    title: "Screen time is finished ❤️",
                    subtitle: "You chose \(activity.displayName)\(addressed). \(activity.invitation)",
                    symbolName: activity.symbolName,
                    primaryButtonLabel: "Let's go!",
                    primaryButtonContinues: false,
                    activity: activity
                )
            }
            return ShieldPresentation(
                title: "Screen time is finished ❤️",
                subtitle: "Nice job\(addressed). Let's do something else now.",
                symbolName: "hands.clap.fill",
                primaryButtonLabel: "OK",
                primaryButtonContinues: false,
                activity: nil
            )

        case .spentForToday:
            return ShieldPresentation(
                title: "All done for today",
                subtitle: "You've used today's screen time. See you tomorrow\(addressed)!",
                symbolName: "moon.stars.fill",
                primaryButtonLabel: "OK",
                primaryButtonContinues: false,
                activity: nil
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
