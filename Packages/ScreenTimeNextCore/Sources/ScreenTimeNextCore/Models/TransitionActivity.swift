//  TransitionActivity.swift
//  ScreenTimeNextCore
//
//  PRD §6.7, §12 — what the child chooses to do next.
//
//  D-029 — this was a fixed enum of eight. It is now a struct, because "what my child does after
//  screen time" is the one list in this app that belongs to the family, not to us. The eight ship
//  as built-ins; a parent can add their own, and those live on the device for good.
//
//  Framework-free: imports Foundation only. See docs/source-layout.md.

import Foundation

public struct TransitionActivity: Codable, Hashable, Identifiable, Sendable {

    /// Stable and never reused. Built-ins keep the raw values the old enum used, so every session,
    /// configuration and window written before D-029 still decodes.
    public let id: String
    /// Child-facing name. PRD §7 — warm and concrete.
    public let displayName: String
    /// Time's Up copy (§6.14): "You chose LEGO. Let's go build!" — the second sentence.
    public let invitation: String
    /// SF Symbol for the chooser tiles.
    public let symbolName: String
    /// True for anything a parent added themselves.
    public let isCustom: Bool

    public init(id: String, displayName: String, invitation: String, symbolName: String, isCustom: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.invitation = invitation
        self.symbolName = symbolName
        self.isCustom = isCustom
    }

    /// Identity is the id alone. Two records for the same activity are the same activity even if a
    /// parent has since renamed it — otherwise a rename would orphan the choice stored on a
    /// running session.
    public static func == (lhs: TransitionActivity, rhs: TransitionActivity) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: The built-in five (D-052, revised D-053)
    //
    // Was eight, chosen by us. These are the five Dominic's family actually uses, and the list is
    // now short enough that a parent can read it at a glance and long enough that the shield's
    // three-item menu (D-044) is a real choice rather than the whole list.
    //
    // The ids of the three that survived are UNCHANGED, so a session that stored "outside" still
    // resolves to Outside. A window that stored one of the removed ids ("lego") decodes through
    // the tolerant path in `init(from:)` as a readable placeholder rather than being lost — a
    // child's choice belongs to them even after we stop offering it.

    public static let familyTime = TransitionActivity(id: "familyTime", displayName: "Family Time",
                                                      invitation: "Let's find the family!",
                                                      symbolName: "figure.2.and.child.holdinghands")
    public static let outside = TransitionActivity(id: "outside", displayName: "Outside",
                                                   invitation: "Let's head outside!",
                                                   symbolName: "sun.max.fill")
    /// D-053 — replaced Sleep. "Free time" is the honest name for the commonest answer: not a
    /// scheduled thing, just anything that is not a screen. It also gives a child who does not
    /// want to commit to a specific plan something real to pick, which matters now that the last
    /// transition screen insists on an answer.
    public static let freeTime = TransitionActivity(id: "freeTime", displayName: "Free time",
                                                    invitation: "Go do whatever you like!",
                                                    symbolName: "sparkles")
    public static let cleanUp = TransitionActivity(id: "cleanUp", displayName: "Clean up",
                                                   invitation: "Let's tidy up!",
                                                   symbolName: "shippingbox.fill")
    public static let mealTime = TransitionActivity(id: "mealTime", displayName: "Meal time",
                                                    invitation: "Time to eat!",
                                                    symbolName: "fork.knife")

    /// The built-ins, in their canonical order. Deliberately still called `allCases`: it is what
    /// every caller means by it, and the built-in set is still a fixed list.
    ///
    /// The order is not cosmetic. A system shield can show at most THREE choices (D-044), and it
    /// takes them off the front of this list — so the first three here ARE what a child is offered
    /// on the transition screen until a parent reorders them.
    public static let allCases: [TransitionActivity] = [
        .familyTime, .outside, .freeTime, .cleanUp, .mealTime
    ]

    /// The built-in with this id, if any. Replaces the old `init(rawValue:)`; a custom activity
    /// cannot be resolved from an id alone, because only the parent's own record knows its name.
    public static func builtIn(id: String) -> TransitionActivity? {
        allCases.first { $0.id == id }
    }

    /// The symbols a parent may pick from when adding their own. Chosen to cover the things
    /// children actually do next, and to look right at tile size.
    public static let customSymbolChoices: [String] = [
        "star.fill", "soccerball", "bicycle", "music.note", "pawprint.fill", "leaf.fill",
        "gamecontroller.fill", "fork.knife", "bed.double.fill", "figure.run", "puzzlepiece.fill",
        "guitars.fill", "basketball.fill", "teddybear.fill", "scissors", "hammer.fill"
    ]

    /// A parent-created activity. The id is a UUID so two families' "Piano" never collide, and so a
    /// rename cannot break a session that already stored the choice.
    public static func custom(displayName: String, symbolName: String) -> TransitionActivity {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return TransitionActivity(id: "custom." + UUID().uuidString,
                                  displayName: name,
                                  // §7 keeps the child-facing line warm; a parent typing "Piano"
                                  // should not have to also write a cheerful sentence about it.
                                  invitation: "Time for \(name.lowercasedFirst)!",
                                  symbolName: symbolName,
                                  isCustom: true)
    }

    /// Rename or re-icon in place, keeping the id — see the note on `==`.
    public func renamed(to displayName: String, symbolName: String) -> TransitionActivity {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return TransitionActivity(id: id,
                                  displayName: name,
                                  invitation: isCustom ? "Time for \(name.lowercasedFirst)!" : invitation,
                                  symbolName: symbolName,
                                  isCustom: isCustom)
    }

    // MARK: Codable — tolerant of the pre-D-029 bare string

    private enum CodingKeys: String, CodingKey {
        case id, displayName, invitation, symbolName, isCustom
    }

    public init(from decoder: Decoder) throws {
        // Everything written while this was an enum encoded as its raw value, e.g. "lego".
        if let raw = try? decoder.singleValueContainer().decode(String.self) {
            if let known = Self.allCases.first(where: { $0.id == raw }) {
                self = known
            } else {
                // An id we no longer recognise. Keep it rather than dropping it: a child's choice
                // on a running session is theirs, and a readable placeholder beats losing it.
                self = TransitionActivity(id: raw,
                                          displayName: raw.capitalized,
                                          invitation: "Let's go!",
                                          symbolName: "star.fill",
                                          isCustom: true)
            }
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        // A built-in is re-resolved from its id rather than trusted from disk, so improving its
        // copy in a later version reaches families who already have it saved.
        if let known = Self.allCases.first(where: { $0.id == id }) {
            self = known
            return
        }
        self.init(id: id,
                  displayName: try c.decode(String.self, forKey: .displayName),
                  invitation: try c.decodeIfPresent(String.self, forKey: .invitation) ?? "Let's go!",
                  symbolName: try c.decodeIfPresent(String.self, forKey: .symbolName) ?? "star.fill",
                  isCustom: try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? true)
    }
}
