//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//
//  Task 011 / D-012 — what the child actually sees when a covered app is opened.
//
//  This is the product. Everything else in the app is scaffolding around this one screen: the
//  moment a child taps a game and gets, instead, a warm sentence naming the thing they chose to do
//  next. §6.15 — a transition, not a punishment.
//
//  The copy is NOT written here. `ShieldPresentation.make(for:childName:)` in the core package is
//  the single place shield wording lives, so the in-app preview a parent can show their child and
//  the real shield can never drift apart (D-012). This file's whole job is to work out WHICH moment
//  applies and turn the result into UIKit values.
//
//  Rule 3 — the system gives this extension a moment to answer, in its own process, with the app
//  not running. So: no async, no network, no waiting. Read the App Group, compute from absolute
//  timestamps (Rule 4), return.
//
//  §16 — `application` and `webDomain` arrive as opaque tokens and are never read, logged, or
//  written anywhere. We do not need to know which app it is to say the right thing.
//
//  API verified against Apple's documentation (2026-09-06), per Rule 8:
//      ShieldConfigurationDataSource — configuration(shielding:) x4
//      ShieldConfiguration(backgroundBlurStyle:backgroundColor:icon:title:subtitle:
//                          primaryButtonLabel:primaryButtonBackgroundColor:secondaryButtonLabel:)
//      ShieldConfiguration.Label(text:color:)

import ManagedSettings
import ManagedSettingsUI
import ScreenTimeNextCore
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // Every entry point shows the same thing. A child who opens a covered game and a child who
    // opens a covered website are in the same moment, and giving them different screens would be
    // an implementation detail leaking into a six-year-old's evening.
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        current()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        current()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        current()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        current()
    }

    // MARK: What moment is this?

    private func current() -> ShieldConfiguration {
        guard let storage = try? FileStorageService.shared() else {
            // No shared container: we cannot know anything about the session, and a shield that
            // invents a number is worse than one that says the plain true thing.
            return render(ShieldPresentation.make(for: .spentForToday, childName: ""))
        }
        let childName = (try? storage.loadChildProfile())?.name ?? ""
        // D-044 — the decision itself lives in the package, shared with the action extension, so
        // the screen the child sees and the buttons that act on it can never disagree.
        let moment = ShieldMomentResolver.moment(window: (try? storage.loadSessionWindow()) ?? nil,
                                                 configuration: (try? storage.loadConfiguration()) ?? .default,
                                                 availableActivities: Self.activities(storage: storage))
        // D-049 — leave a note saying which of the three the child got. This process is invisible
        // from everywhere else, so without it "the reminder fired" and "the child saw the chooser"
        // are two claims and only the first can be checked.
        MonitorJournal()?.record(Self.journalEvent(for: moment), activity: MonitoringName.sessionEnd)
        return render(ShieldPresentation.make(for: moment, childName: childName))
    }

    private static func journalEvent(for moment: ShieldMoment) -> MonitorReport.Event {
        switch moment {
        case .reminder:      return .shieldShownReminder
        case .chooseNext:    return .shieldShownChooser
        case .finished:      return .shieldShownFinished
        case .spentForToday: return .shieldShownSpent
        }
    }

    /// What the child may choose from: the parent's picks, in the parent's order (D-039). Both
    /// extensions build this the same way — the action extension's copy is the same three lines,
    /// against the same records.
    static func activities(storage: any ScreenTimeStorageService) -> [TransitionActivity] {
        let all = ((try? storage.loadPickerPreferences()) ?? .default).allActivities
        let picked = ((try? storage.loadConfiguration()) ?? .default).selectedActivities
        // D-009 — picking none means "no preference", which is everything, not nothing.
        return picked.isEmpty ? all : all.filter { picked.contains($0) }
    }

    // MARK: Presentation → UIKit

    private func render(_ p: ShieldPresentation) -> ShieldConfiguration {
        let tint = Self.color(for: p.urgency)
        let secondary = p.secondaryButtonLabel.map {
            ShieldConfiguration.Label(text: $0, color: .label)
        }

        // D-044 — the second button exists for exactly one thing: choosing what comes next. §17
        // still holds; it never buys more time. The submenu is iOS 26.4+, and
        // `ShieldMomentResolver.supportsChooserMenu` means a `.chooseNext` moment cannot even be
        // produced on anything older — so this branch and that guard agree by construction.
        if #available(iOS 26.4, *), !p.submenuItems.isEmpty {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterial,
                backgroundColor: nil,
                icon: UIImage(systemName: p.symbolName),
                title: ShieldConfiguration.Label(text: p.title, color: .label),
                subtitle: ShieldConfiguration.Label(text: p.subtitle, color: .secondaryLabel),
                primaryButtonLabel: ShieldConfiguration.Label(text: p.primaryButtonLabel, color: .white),
                primaryButtonBackgroundColor: tint,
                secondaryButtonLabel: secondary,
                secondaryButtonSubmenuItems: p.submenuItems
            )
        }

        return ShieldConfiguration(
            // Blurred rather than opaque: the child can still see they are in their own app, which
            // is what makes this read as a pause rather than as the device breaking.
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: nil,
            icon: UIImage(systemName: p.symbolName),
            title: ShieldConfiguration.Label(text: p.title, color: .label),
            subtitle: ShieldConfiguration.Label(text: p.subtitle, color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: p.primaryButtonLabel, color: .white),
            primaryButtonBackgroundColor: tint,
            secondaryButtonLabel: secondary
        )
    }

    /// The same ramp as the in-app preview (D-018): green while there is room, orange to wrap up,
    /// red on the last stretch, and only the finish is celebratory. Written out here because
    /// `Theme` lives in the app target and this is a different process.
    private static func color(for urgency: ShieldUrgency) -> UIColor {
        switch urgency {
        case .calm:     return UIColor(red: 0.30, green: 0.72, blue: 0.47, alpha: 1)   // grass
        case .soon:     return UIColor(red: 0.96, green: 0.62, blue: 0.24, alpha: 1)   // tangerine
        case .last:     return UIColor(red: 0.91, green: 0.35, blue: 0.35, alpha: 1)   // ruby
        case .finished: return UIColor(red: 0.55, green: 0.47, blue: 0.91, alpha: 1)   // lavender
        case .spent:    return UIColor(red: 0.44, green: 0.53, blue: 0.86, alpha: 1)   // sky
        }
    }
}
