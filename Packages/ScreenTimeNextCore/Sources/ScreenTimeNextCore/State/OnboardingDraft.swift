//  OnboardingDraft.swift
//  ScreenTimeNextCore
//
//  Task 003. Everything the parent enters during onboarding, held as a value until the final
//  step commits it (PRD §6.1–§6.8). Pure and testable; the SwiftUI view model just wraps it.

import Foundation

public enum OnboardingError: Error, Equatable, Sendable {
    /// Kept for source compatibility; setup no longer requires a name (D-016).
    case missingChildName
}

public struct OnboardingDraft: Equatable, Sendable {

    /// §6.2 — first name only, stays on device.
    public var childName: String = ""

    /// §6.4 — set by the (mocked, then real) picker. Optional: a parent may skip in onboarding.
    public var selection: SelectionSnapshot? = nil

    /// §6.5 / D-034 — default 15 minutes: the length of the request a parent is usually
    /// answering when they open this app.
    public var dailyBudgetSeconds: Int = ScreenTimeConfiguration.defaultBudgetSeconds

    /// §6.6 / D-013 — up to three reminders, minutes before the end; 0 = off.
    /// Until the parent touches the dials, the defaults follow the budget (4-minute budget → 2 / 1),
    /// so going back to change the budget re-derives them; once customized they are kept (and
    /// clamped to the budget at commit).
    public var customWarningMinutes: [Int]? = nil

    public var warningMinutes: [Int] {
        get {
            customWarningMinutes ?? Self.defaultWarningMinutes(forBudgetSeconds: dailyBudgetSeconds)
        }
        set { customWarningMinutes = newValue }
    }

    public var hasCustomizedWarnings: Bool { customWarningMinutes != nil }

    /// Three slots (0 = off) from the configuration-level defaults.
    public static func defaultWarningMinutes(forBudgetSeconds budget: Int) -> [Int] {
        var mins = ScreenTimeConfiguration.defaultWarningOffsets(forBudgetSeconds: budget).map { $0 / 60 }
        while mins.count < ScreenTimeConfiguration.maxWarnings { mins.append(0) }
        return mins
    }

    public init() {}

    // MARK: Validation

    public var trimmedChildName: String {
        childName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// D-016 — the name is optional. The app is used in the moment ("you get 15 minutes"), not
    /// configured as a profile; copy degrades to a warm, name-less form when it is empty.
    public var hasChildName: Bool { !trimmedChildName.isEmpty }

    public var hasSelection: Bool { !(selection?.summary.isEmpty ?? true) }

    // MARK: Derived records

    public var childProfile: ChildProfile? {
        hasChildName ? ChildProfile(name: trimmedChildName) : nil
    }

    /// D-072 — onboarding no longer carries an activity list. It never asked for one (no
    /// onboarding screen ever set it), and the list it would have written is the parent's order in
    /// `ParentPickerPreferences`, which onboarding does not touch either.
    public var configuration: ScreenTimeConfiguration {
        // A reminder can never be as long as the budget (D-013): clamp, so going back to lower
        // the budget after setting reminders cannot leave an impossible combination behind.
        let cap = ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: dailyBudgetSeconds)
        return ScreenTimeConfiguration(
            dailyBudgetSeconds: dailyBudgetSeconds,
            warningOffsetsSeconds: warningMinutes.map { min($0 * 60, cap) }
        )
    }

    // MARK: Commit

    /// Persist the draft through the service protocols. Nothing is written before this call.
    public func commit(using services: ServiceContainer) throws {
        if let childProfile {
            try services.storage.save(childProfile)
        }
        try services.storage.save(configuration)
        if let selection {
            try services.selection.save(selection)
        }
    }
}
