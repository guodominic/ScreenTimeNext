//  ContentCategory.swift
//  ScreenTimeNextCore
//
//  D-018 — the catalogue behind the "Pick apps & categories" screen.
//
//  WHY THIS LIST EXISTS, AND WHAT IT IS NOT
//  iOS will not let an app enumerate what is installed, and an `ActivityCategoryToken` cannot be
//  built from a name — Apple's `FamilyActivityPicker` is the only thing that produces real tokens
//  (Apple Frameworks Engineer, developer.apple.com/forums/thread/726298: "There is no way to
//  extract application tokens from a category token."). So this list does not shield anything and
//  it can never report how many installed apps a category holds.
//
//  It is the Phase 0 stand-in that lets the screen, the counts and the flow be designed and tested
//  before the entitlement exists. In Phase 1 the very same screen hosts `FamilyActivityPicker`
//  inline — it is a SwiftUI view, not only a sheet — and these rows are replaced by its own
//  Categories / Apps / Websites sections. Everything around the picker (title, running counts,
//  Start button) survives that swap unchanged.
//
//  §16: no row names a real app or brand. The hints describe a kind of activity, nothing more.

import Foundation

public enum ContentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case games
    case entertainment
    case social
    case creativity
    case education
    case reading
    case productivity
    case health
    case shopping
    case travel
    case utilities
    case browsers
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .games:         return "Games"
        case .entertainment: return "Entertainment"
        case .social:        return "Social"
        case .creativity:    return "Creativity"
        case .education:     return "Education"
        case .reading:       return "Reading & Reference"
        case .productivity:  return "Productivity"
        case .health:        return "Health & Fitness"
        case .shopping:      return "Shopping & Food"
        case .travel:        return "Travel"
        case .utilities:     return "Utilities"
        case .browsers:      return "Web browsers"
        case .other:         return "Everything else"
        }
    }

    /// One short line under the name. Describes a kind of activity — never an app or a brand.
    public var hint: String {
        switch self {
        case .games:         return "Playing and competing"
        case .entertainment: return "Video, music and streaming"
        case .social:        return "Chatting and sharing"
        case .creativity:    return "Drawing, building, making"
        case .education:     return "Learning and homework"
        case .reading:       return "Books, news, reference"
        case .productivity:  return "Notes, mail, calendars"
        case .health:        return "Movement and wellbeing"
        case .shopping:      return "Buying and ordering"
        case .travel:        return "Maps and getting around"
        case .utilities:     return "Tools and settings"
        case .browsers:      return "Websites in any browser"
        case .other:         return "Anything not listed above"
        }
    }

    public var symbolName: String {
        switch self {
        case .games:         return "gamecontroller.fill"
        case .entertainment: return "play.tv.fill"
        case .social:        return "bubble.left.and.bubble.right.fill"
        case .creativity:    return "paintbrush.pointed.fill"
        case .education:     return "graduationcap.fill"
        case .reading:       return "book.fill"
        case .productivity:  return "checklist"
        case .health:        return "heart.fill"
        case .shopping:      return "cart.fill"
        case .travel:        return "map.fill"
        case .utilities:     return "wrench.and.screwdriver.fill"
        case .browsers:      return "globe"
        case .other:         return "square.grid.2x2.fill"
        }
    }

    /// `browsers` stands for web domains rather than installed apps, so it counts on the websites
    /// line of the summary instead of the categories line.
    public var isWeb: Bool { self == .browsers }

    /// The rows shown under "Categories". `browsers` gets its own section.
    public static var appCategories: [ContentCategory] {
        allCases.filter { !$0.isWeb }
    }

    /// D-019 — the order rows appear in before the parent drags anything. Browsers first: it is
    /// the one row that covers something no app category does, and it is the easiest to overlook.
    public static var defaultOrder: [ContentCategory] {
        [.browsers] + allCases.filter { !$0.isWeb }
    }

    /// The starting "my usual" set. The parent can overwrite it with whatever they actually use.
    public static var defaultFavourites: [ContentCategory] {
        [.games, .entertainment, .social]
    }

    /// A saved order, made whole: known rows keep the parent's arrangement, anything they have
    /// never seen (a category added in a later version) is appended in catalogue order, and
    /// duplicates are dropped. A saved order can therefore never hide a row.
    public static func completeOrder(_ saved: [ContentCategory]) -> [ContentCategory] {
        var seen = Set<ContentCategory>()
        var ordered = saved.filter { seen.insert($0).inserted }
        ordered.append(contentsOf: defaultOrder.filter { !seen.contains($0) })
        return ordered
    }

    /// Counts a set the way the summary reports it: web rows on the websites line, the rest on
    /// the categories line. `apps` comes from the picker and is passed through untouched.
    public static func summary(categories: Set<ContentCategory>, apps: Int = 0) -> SelectionSummary {
        SelectionSummary(
            applicationCount: apps,
            categoryCount: categories.filter { !$0.isWeb }.count,
            webDomainCount: categories.filter(\.isWeb).count
        )
    }
}
