//  ParentPickerPreferences.swift
//  ScreenTimeNextCore
//
//  D-024 — how the PARENT likes the picker: the row order they dragged, and the "my usual" set
//  they saved. Deliberately NOT part of `ScreenTimeConfiguration`.
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

    public init(categoryOrder: [ContentCategory] = ContentCategory.defaultOrder,
                favourites: [ContentCategory] = ContentCategory.defaultFavourites,
                favouritesAreCustom: Bool = false) {
        self.categoryOrder = ContentCategory.completeOrder(categoryOrder)
        self.favourites = favourites
        self.favouritesAreCustom = favouritesAreCustom
    }

    public static let `default` = ParentPickerPreferences()

    /// What a fresh picker should open with ticked: the parent's own usual set, or nothing.
    public var initialSelection: Set<ContentCategory> {
        favouritesAreCustom ? Set(favourites) : []
    }

    private enum CodingKeys: String, CodingKey {
        case categoryOrder, favourites, favouritesAreCustom
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            categoryOrder: try c.decodeIfPresent([ContentCategory].self, forKey: .categoryOrder) ?? ContentCategory.defaultOrder,
            favourites: try c.decodeIfPresent([ContentCategory].self, forKey: .favourites) ?? ContentCategory.defaultFavourites,
            favouritesAreCustom: try c.decodeIfPresent(Bool.self, forKey: .favouritesAreCustom) ?? false
        )
    }
}
