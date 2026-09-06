//  ContentCategoryTests.swift
//  ScreenTimeNextCoreTests
//
//  D-018 — the catalogue behind "Pick apps and categories".

import XCTest
@testable import ScreenTimeNextCore

final class ContentCategoryTests: XCTestCase {

    func testEveryRowHasCopyAndASymbol() {
        for category in ContentCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "\(category) has no name")
            XCTAssertFalse(category.hint.isEmpty, "\(category) has no hint")
            XCTAssertFalse(category.symbolName.isEmpty, "\(category) has no symbol")
        }
    }

    /// Browsers stand for web domains, so they must not inflate the categories count.
    func testBrowsersCountAsWebsitesNotCategories() {
        let summary = ContentCategory.summary(categories: [.games, .social, .browsers])
        XCTAssertEqual(summary.categoryCount, 2)
        XCTAssertEqual(summary.webDomainCount, 1)
        XCTAssertEqual(summary.applicationCount, 0)
    }

    func testAppCountIsPassedThrough() {
        let summary = ContentCategory.summary(categories: [.games], apps: 3)
        XCTAssertEqual(summary.applicationCount, 3)
        XCTAssertEqual(summary.categoryCount, 1)
    }

    func testNothingPickedIsAnEmptySummary() {
        XCTAssertTrue(ContentCategory.summary(categories: []).isEmpty)
        XCTAssertFalse(ContentCategory.summary(categories: [.browsers]).isEmpty)
    }

    func testBrowsersIsTheOnlyWebRowAndIsNotInTheCategoryList() {
        XCTAssertEqual(ContentCategory.allCases.filter(\.isWeb), [.browsers])
        XCTAssertFalse(ContentCategory.appCategories.contains(.browsers))
        XCTAssertEqual(ContentCategory.appCategories.count, ContentCategory.allCases.count - 1)
    }

    func testTheDefaultUsualSetAreRealRows() {
        for category in ContentCategory.defaultFavourites {
            XCTAssertTrue(ContentCategory.appCategories.contains(category))
        }
    }

    // MARK: Order (D-019)

    func testBrowsersComeFirstByDefault() {
        XCTAssertEqual(ContentCategory.defaultOrder.first, .browsers)
        XCTAssertEqual(Set(ContentCategory.defaultOrder), Set(ContentCategory.allCases))
        XCTAssertEqual(ContentCategory.defaultOrder.count, ContentCategory.allCases.count)
    }

    /// A saved order must never be able to hide a row — that is how a parent loses a category
    /// after an update that adds one.
    func testASavedOrderIsCompletedNotTrusted() {
        let partial: [ContentCategory] = [.games, .social]
        let completed = ContentCategory.completeOrder(partial)
        XCTAssertEqual(completed.prefix(2).map { $0 }, partial, "what the parent arranged stays put")
        XCTAssertEqual(Set(completed), Set(ContentCategory.allCases), "nothing goes missing")
        XCTAssertEqual(completed.count, ContentCategory.allCases.count, "and nothing is duplicated")
    }

    func testDuplicatesInASavedOrderAreDropped() {
        let completed = ContentCategory.completeOrder([.games, .games, .social, .games])
        XCTAssertEqual(completed.filter { $0 == .games }.count, 1)
        XCTAssertEqual(completed.count, ContentCategory.allCases.count)
    }

    func testAnEmptySavedOrderFallsBackToTheDefault() {
        XCTAssertEqual(ContentCategory.completeOrder([]), ContentCategory.defaultOrder)
    }

    func testOrderAndFavouritesSurviveAPreferencesRoundTrip() throws {
        let prefs = ParentPickerPreferences(categoryOrder: [.education, .games, .browsers],
                                            favourites: [.education],
                                            favouritesAreCustom: true)
        let decoded = try JSONDecoder().decode(ParentPickerPreferences.self,
                                               from: try JSONEncoder().encode(prefs))
        XCTAssertEqual(decoded.categoryOrder.prefix(3).map { $0 }, [.education, .games, .browsers])
        XCTAssertEqual(decoded.favourites, [.education])
        XCTAssertTrue(decoded.favouritesAreCustom)
    }

    /// A preferences record written before a field existed must decode to the defaults rather than
    /// to an empty list, which would render no rows at all.
    func testPreferencesWithoutFieldsGetTheDefaults() throws {
        let decoded = try JSONDecoder().decode(ParentPickerPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded.categoryOrder, ContentCategory.defaultOrder)
        XCTAssertEqual(decoded.favourites, ContentCategory.defaultFavourites)
        XCTAssertFalse(decoded.favouritesAreCustom)
    }

    /// D-024 — a fresh picker offers the parent's OWN saved set, and never a set we invented.
    func testAFreshPickerPreTicksOnlyACustomUsualSet() {
        XCTAssertEqual(ParentPickerPreferences.default.initialSelection, [],
                       "our starting three are a suggestion, not a decision")
        let mine = ParentPickerPreferences(favourites: [.games, .browsers], favouritesAreCustom: true)
        XCTAssertEqual(mine.initialSelection, [.games, .browsers])
    }

    /// §16 — a row must never name a real app or brand.
    func testNoRowNamesAnApp() {
        let banned = ["youtube", "tiktok", "roblox", "minecraft", "instagram", "snapchat", "netflix", "safari", "chrome"]
        for category in ContentCategory.allCases {
            let text = (category.displayName + " " + category.hint).lowercased()
            for word in banned {
                XCTAssertFalse(text.contains(word), "\(category) mentions \(word)")
            }
        }
    }

    func testRoundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(ContentCategory.allCases)
        XCTAssertEqual(try JSONDecoder().decode([ContentCategory].self, from: data), ContentCategory.allCases)
    }
}
