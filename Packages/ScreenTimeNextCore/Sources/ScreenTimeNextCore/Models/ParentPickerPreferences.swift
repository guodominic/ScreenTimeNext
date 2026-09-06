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
//  D-035 removed `categoryOrder` / `favourites` / `favouritesAreCustom`. They arranged and saved
//  category TILES, and the tiles are gone: only a token from Apple's picker can shield anything, so
//  a saved set of our own category names promised something it could never deliver. Records written
//  by an older build still decode — the keys are simply ignored (`decodeIfPresent` never saw them
//  as required), which is the whole reason this record has a hand-written decoder.
//
//  §16: nothing here is one of Apple's opaque selection tokens.

import Foundation

public struct ParentPickerPreferences: Codable, Equatable, Sendable {

    /// D-029 — activities the parent invented. Kept here rather than in the configuration for the
    /// same reason as everything else in this record: a reset should take the child's setup, not
    /// the things the parent made.
    public var customActivities: [TransitionActivity]

    /// D-033 — websites the parent typed, blocked by name rather than by token.
    ///
    /// This is a SECOND, unrelated mechanism to the selection: `ManagedSettings` can block a domain
    /// from a plain string (`WebDomain(domain:)` + `blockedByFilter = .specific(...)`), with no
    /// token and no picker involved. It lives here rather than in the configuration because a
    /// family's list of blocked sites is theirs and should outlive a reset (D-024).
    public var blockedWebsites: [String]

    /// D-033 — the order the parent dragged their "what's next" activities into, by id. Ids that
    /// no longer exist are ignored, and anything missing is appended, so the list can never lose a
    /// row.
    public var activityOrder: [String]

    /// D-039 — built-ins the parent removed, by id.
    ///
    /// Hidden rather than deleted, for two reasons. A built-in is a `static let` in code, so there
    /// is nothing to delete; and a family that removes "Bath" and later wants it back should get it
    /// back, not have to retype it. `restoreBuiltIns()` is one tap away in Settings.
    public var hiddenActivityIDs: [String]

    /// D-030 — whole selections the parent saved and named, so a set of apps, categories and
    /// WEBSITES can be re-applied with one tap instead of retyped. A website can only be created
    /// inside Apple's picker (no public API turns a string into a `WebDomainToken`), so
    /// remembering the selection that contains it is the only way to stop a parent typing it again.
    public var savedSelections: [SavedSelection]

    public init(customActivities: [TransitionActivity] = [],
                savedSelections: [SavedSelection] = [],
                blockedWebsites: [String] = [],
                activityOrder: [String] = [],
                hiddenActivityIDs: [String] = []) {
        self.customActivities = customActivities
        self.savedSelections = savedSelections
        self.blockedWebsites = Self.tidied(blockedWebsites)
        self.activityOrder = activityOrder
        self.hiddenActivityIDs = hiddenActivityIDs
    }

    /// What the child is actually offered: the built-ins the parent kept, plus whatever they
    /// added, in the order they arranged.
    public var allActivities: [TransitionActivity] {
        let hidden = Set(hiddenActivityIDs)
        let everything = (TransitionActivity.allCases + customActivities).filter { !hidden.contains($0.id) }
        guard !activityOrder.isEmpty else { return everything }
        var byID = Dictionary(uniqueKeysWithValues: everything.map { ($0.id, $0) })
        var ordered: [TransitionActivity] = []
        for id in activityOrder {
            if let activity = byID.removeValue(forKey: id) { ordered.append(activity) }
        }
        // Anything the saved order never heard of goes on the end, in catalogue order. A stale
        // order can therefore never hide an activity — the same rule as `completeOrder`.
        ordered.append(contentsOf: everything.filter { byID[$0.id] != nil })
        return ordered
    }

    /// Normalises a typed domain: trims, lowercases, drops a scheme and any path. `youtube.com`,
    /// `https://YouTube.com/feed` and ` youtube.com ` are the same site, and a parent who typed the
    /// long one should not end up with a second entry that blocks nothing extra.
    public static func normalizedDomain(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasPrefix("www.") { text.removeFirst(4) }
        if let slash = text.firstIndex(of: "/") { text = String(text[text.startIndex..<slash]) }
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.contains(" ") else { return nil }

        // A sanity check, not validation. iOS decides what it can actually match, and rejecting
        // something it would have accepted is worse than letting an odd one through — so the only
        // things refused are shapes that cannot be a domain at all: fewer than two labels, an empty
        // label ("..", "a..b"), or a single-character last label. No real top-level domain is one
        // character, so "a.b" is a typo, and a typo in this list is an entry that silently blocks
        // nothing while the parent believes it does.
        let labels = text.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({ !$0.isEmpty }),
              (labels.last?.count ?? 0) >= 2 else { return nil }
        return text
    }

    private static func tidied(_ domains: [String]) -> [String] {
        var seen = Set<String>()
        return domains.compactMap(normalizedDomain).filter { seen.insert($0).inserted }
    }

    /// Adds a typed domain. Returns false when it is not usable or is already there.
    @discardableResult
    public mutating func addWebsite(_ raw: String) -> Bool {
        guard let domain = Self.normalizedDomain(raw), !blockedWebsites.contains(domain) else { return false }
        blockedWebsites.append(domain)
        return true
    }

    /// D-039 — true when the parent has removed at least one built-in, which is the only reason
    /// to offer them a way back.
    public var hasHiddenBuiltIns: Bool {
        let builtInIDs = Set(TransitionActivity.allCases.map(\.id))
        return hiddenActivityIDs.contains { builtInIDs.contains($0) }
    }

    /// D-039 — the child must always have something to choose. A parent who removes the last row
    /// has not configured anything, they have broken §6.11, so removal stops one short.
    public func canRemoveActivity(_ id: String) -> Bool {
        allActivities.contains { $0.id != id }
    }

    public static let `default` = ParentPickerPreferences()

    private enum CodingKeys: String, CodingKey {
        case customActivities, savedSelections
        case blockedWebsites, activityOrder, hiddenActivityIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            customActivities: try c.decodeIfPresent([TransitionActivity].self, forKey: .customActivities) ?? [],
            savedSelections: try c.decodeIfPresent([SavedSelection].self, forKey: .savedSelections) ?? [],
            blockedWebsites: try c.decodeIfPresent([String].self, forKey: .blockedWebsites) ?? [],
            activityOrder: try c.decodeIfPresent([String].self, forKey: .activityOrder) ?? [],
            hiddenActivityIDs: try c.decodeIfPresent([String].self, forKey: .hiddenActivityIDs) ?? []
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
