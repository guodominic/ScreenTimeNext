//  OnboardingDraftTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 003 — QA-01 support: the data half of onboarding.

import XCTest
@testable import ScreenTimeNextCore

final class OnboardingDraftTests: XCTestCase {

    /// PRD §6.6 defaults, and the one place the app deliberately departs from §6.5: D-034 made
    /// the starting budget 15 minutes rather than 60. The PRD's 60 was a number a parent had to
    /// dial DOWN from every single time, and "fifteen minutes, then dinner" is the sentence this
    /// app exists to answer.
    func testDefaultsMatchThePRDExceptTheBudget() {
        let draft = OnboardingDraft()
        XCTAssertEqual(draft.dailyBudgetSeconds, 900)
        XCTAssertEqual(draft.warningMinutes, [5, 1], "D-044 — two reminders")
        XCTAssertNil(draft.selection)
        XCTAssertFalse(draft.hasChildName)
        XCTAssertFalse(draft.hasSelection)
    }

    func testChildNameIsTrimmedAndOptional() {
        var draft = OnboardingDraft()
        draft.childName = "   "
        XCTAssertFalse(draft.hasChildName)
        XCTAssertNil(draft.childProfile, "D-016: no name means no profile, not an error")
        draft.childName = "  Ivy \n"
        XCTAssertTrue(draft.hasChildName)
        XCTAssertEqual(draft.childProfile?.name, "Ivy")
    }

    /// Defaults follow the budget until the parent touches the dials.
    func testReminderDefaultsFollowTheBudget() {
        // D-044 — two dials, so every expected list here is two long.
        var draft = OnboardingDraft()
        XCTAssertEqual(draft.warningMinutes, [5, 1])
        draft.dailyBudgetSeconds = 4 * 60
        XCTAssertEqual(draft.warningMinutes, [2, 1])
        draft.dailyBudgetSeconds = 8 * 60
        XCTAssertEqual(draft.warningMinutes, [4, 1])
        draft.dailyBudgetSeconds = 3 * 60
        XCTAssertEqual(draft.warningMinutes, [1, 0])
        draft.dailyBudgetSeconds = 12 * 60
        XCTAssertEqual(draft.warningMinutes, [5, 1])
        XCTAssertFalse(draft.hasCustomizedWarnings)
        // Once customized, they stick.
        draft.warningMinutes = [6, 0]
        draft.dailyBudgetSeconds = 60 * 60
        XCTAssertEqual(draft.warningMinutes, [6, 0])
        XCTAssertTrue(draft.hasCustomizedWarnings)
    }

    /// Budget lowered after reminders were set: reminders are clamped to budget − 1 minute.
    func testRemindersAreClampedToTheBudget() {
        var draft = OnboardingDraft()
        draft.warningMinutes = [10, 5]
        draft.dailyBudgetSeconds = 8 * 60
        XCTAssertEqual(draft.configuration.warningOffsetsSeconds, [420, 300], "10 → 7")
    }

    func testCommitWritesProfileConfigurationAndSelection() throws {
        let storage = InMemoryScreenTimeStorageService()
        let selection = MockScreenTimeSelectionService()
        let services = ServiceContainer.mocks(selection: selection, storage: storage)

        var draft = OnboardingDraft()
        draft.childName = "Athan"
        draft.dailyBudgetSeconds = 1800
        draft.warningMinutes = [10, 0, 1]   // middle reminder off
        draft.selection = MockScreenTimeSelectionService.sampleSnapshot()

        try draft.commit(using: services)

        XCTAssertEqual(try storage.loadChildProfile()?.name, "Athan")
        let config = try storage.loadConfiguration()
        XCTAssertEqual(config.dailyBudgetSeconds, 1800)
        XCTAssertEqual(config.warningOffsetsSeconds, [600, 60])
        // D-072 — onboarding never asked for an activity list and no longer carries one.
        XCTAssertNil(config.parentChosenActivity)
        XCTAssertEqual(try selection.loadSelection(), draft.selection)
    }

    /// D-016 — setup with no name at all still produces a usable configuration.
    func testCommitWithoutNameSavesConfigurationAndNoProfile() throws {
        let storage = InMemoryScreenTimeStorageService()
        let services = ServiceContainer.mocks(storage: storage)
        var draft = OnboardingDraft()
        draft.dailyBudgetSeconds = 15 * 60
        try draft.commit(using: services)
        XCTAssertNil(try storage.loadChildProfile())
        XCTAssertEqual(try storage.loadConfiguration().dailyBudgetSeconds, 900)
        XCTAssertTrue(try storage.hasStoredConfiguration(), "the app now counts as set up")
    }

    func testCommitWithoutSelectionSkipsSelectionSave() throws {
        let selection = MockScreenTimeSelectionService()
        let services = ServiceContainer.mocks(selection: selection)
        var draft = OnboardingDraft()
        draft.childName = "Ivy"
        try draft.commit(using: services)
        XCTAssertNil(try selection.loadSelection())
    }
}
