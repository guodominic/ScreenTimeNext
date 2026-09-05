//  OnboardingDraft.swift
//  ScreenTimeNextCore
//
//  Task 003. Everything the parent enters during onboarding, held as a value until the final
//  step commits it (PRD §6.1–§6.8). Pure and testable; the SwiftUI view model just wraps it.

import Foundation

public enum OnboardingError: Error, Equatable, Sendable {
    case missingChildName
}

public struct OnboardingDraft: Equatable, Sendable {

    /// §6.2 — first name only, stays on device.
    public var childName: String = ""

    /// §6.4 — set by the (mocked, then real) picker. Optional: a parent may skip in onboarding.
    public var selection: SelectionSnapshot? = nil

    /// §6.5 — default 60 minutes.
    public var dailyBudgetSeconds: Int = ScreenTimeConfiguration.defaultBudgetSeconds

    /// §6.6 / D-013 — up to three reminders, minutes before the end; 0 = off. Default 10 / 5 / 1.
    public var warningMinutes: [Int] = [10, 5, 1]

    /// §6.7 — activities the child may choose from.
    public var selectedActivities: Set<TransitionActivity> = []

    public init() {}

    // MARK: Validation

    public var trimmedChildName: String {
        childName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isChildNameValid: Bool { !trimmedChildName.isEmpty }

    public var hasSelection: Bool { !(selection?.summary.isEmpty ?? true) }

    // MARK: Derived records

    public var childProfile: ChildProfile { ChildProfile(name: trimmedChildName) }

    /// Activities are stored in the canonical `TransitionActivity.allCases` order, not set order.
    public var configuration: ScreenTimeConfiguration {
        // A reminder can never be as long as the budget (D-013): clamp, so going back to lower
        // the budget after setting reminders cannot leave an impossible combination behind.
        let cap = ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: dailyBudgetSeconds)
        return ScreenTimeConfiguration(
            dailyBudgetSeconds: dailyBudgetSeconds,
            warningOffsetsSeconds: warningMinutes.map { min($0 * 60, cap) },
            selectedActivities: TransitionActivity.allCases.filter { selectedActivities.contains($0) }
        )
    }

    // MARK: Commit

    /// Persist the draft through the service protocols. Nothing is written before this call.
    public func commit(using services: ServiceContainer) throws {
        guard isChildNameValid else { throw OnboardingError.missingChildName }
        try services.storage.save(childProfile)
        try services.storage.save(configuration)
        if let selection {
            try services.selection.save(selection)
        }
    }
}
