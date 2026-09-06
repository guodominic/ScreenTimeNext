//  ParentPickerPreferences.swift
//  ScreenTimeNextCore
//
//  D-024 / D-029 — the things the PARENT made: the row order they dragged, the "my usual" set they
//  saved, the selections they named, and the activities they invented. Deliberately NOT part of
//  `ScreenTimeConfiguration`.
//
//  The configuration is the child's setup — budget, reminders, what is covered — and "Start over"
//  is supposed to erase exactly that. These two are neither: they are the parent's own working
//  arrangement, and losing them on every reset means re-dragging thirteen rows and re-saving a
//  usual set that has not changed. So they live in their own record, which `eraseAll` leaves
//  alone, and which is therefore also what makes a reset feel like a reset rather than a
//  punishment.
//
//  §16: these are our own catalogue rows, never Apple's opaque selection tokens.

import Foundation

public struct ParentPickerPreferences: Codable, Equatable, Sendable {

    /// The row order as the parent arranged it. Always completed against the catalogue on read,
    /// so a category added in a later version can never be stranded off the bottom of a saved list.
    public var categoryOrder: [ContentCategory]

    /// The set applied by "My usual".
    public var favourites: [ContentCategory]

    /// False while `favourites` is still the value WE chose. It gates pre-ticking: offering the
    /// parent their own saved set on a fresh picker is helpful, silently ticking three categories
    /// they never chose is presumptuous.
    public var favouritesAreCustom: Bool

    /// D-029 — activities the parent invented. Kept here rather than in the configuration for the
    /// same reason as everything else in this record: a reset should take the child's setup, not
    /// the things the parent made.
    public var customActivities: [TransitionActivity]

    /// D-030 — whole selections the parent saved and named, so a set of apps, categories and
    /// WEBSITES can be re-applied with one tap instead of retyped. A website can only be created
    /// inside Apple's picker (no public API turns a string into a `WebDomainToken`), so
    /// remembering the selection that contains it is the only way to stop a parent typing it again.
    public var savedSelections: [SavedSelection]

    public init(categoryOrder: [ContentCategory] = ContentCategory.defaultOrder,
                favourites: [ContentCategory] = ContentCategory.defaultFavourites,
                favouritesAreCustom: Bool = false,
                customActivities: [TransitionActivity] = [],
                savedSelections: [SavedSelection] = []) {
        self.categoryOrder = ContentCategory.completeOrder(categoryOrder)
        self.favourites = favourites
        self.favouritesAreCustom = favouritesAreCustom
        self.customActivities = customActivities
        self.savedSelections = savedSelections
    }

    /// The built-in eight plus whatever the parent added, in a stable order.
    public var allActivities: [TransitionActivity] {
        TransitionActivity.allCases + customActivities
    }

    public static let `default` = ParentPickerPreferences()

    /// What a fresh picker should open with ticked: the parent's own usual set, or nothing.
    public var initialSelection: Set<ContentCategory> {
        favouritesAreCustom ? Set(favourites) : []
    }

    private enum CodingKeys: String, CodingKey {
        case categoryOrder, favourites, favouritesAreCustom, customActivities, savedSelections
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            categoryOrder: try c.decodeIfPresent([ContentCategory].self, forKey: .categoryOrder) ?? ContentCategory.defaultOrder,
            favourites: try c.decodeIfPresent([ContentCategory].self, forKey: .favourites) ?? ContentCategory.defaultFavourites,
            favouritesAreCustom: try c.decodeIfPresent(Bool.self, forKey: .favouritesAreCustom) ?? false,
            customActivities: try c.decodeIfPresent([TransitionActivity].self, forKey: .customActivities) ?? [],
            savedSelections: try c.decodeIfPresent([SavedSelection].self, forKey: .savedSelections) ?? []
        )
    }
}

/// D-030 — a named selection the parent can re-apply.
///
/// The snapshot is opaque here exactly as everywhere else: this record carries it, never reads it.
public struct SavedSelection: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var snapshot: SelectionSnapshot

    public init(id: UUID = UUID(), name: String, snapshot: SelectionSnapshot) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.snapshot = snapshot
    }

    /// "3 categories · 1 website" — enough for the parent to tell two presets apart without
    /// opening either (§16: counts only).
    public var subtitle: String {
        let s = snapshot.summary
        var parts: [String] = []
        if s.categoryCount > 0 { parts.append(count(s.categoryCount, "category", "categories")) }
        if s.applicationCount > 0 { parts.append(count(s.applicationCount, "app", "apps")) }
        if s.webDomainCount > 0 { parts.append(count(s.webDomainCount, "website", "websites")) }
        return parts.isEmpty ? "Nothing selected" : parts.joined(separator: " · ")
    }

    private func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }
}
