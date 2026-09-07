//  WhatsNextTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 009 — QA-08: the child can select a next activity, and it survives to Time's Up.

import XCTest
@testable import ScreenTimeNextCore

final class WhatsNextTests: XCTestCase {

    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private var storage: InMemoryScreenTimeStorageService!
    private var clock: Clock!
    private var controller: SessionController!

    override func setUpWithError() throws {
        storage = InMemoryScreenTimeStorageService()
        clock = Clock(Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600))
        let c = clock!
        controller = SessionController(storage: storage, now: { c.now })
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 900
        try storage.save(config)
    }

    /// D-072 — the offered list is the parent's ORDER, and nothing filters it any more.
    func testAvailableActivitiesAreTheParentsListInTheParentsOrder() throws {
        var preferences = ParentPickerPreferences.default
        preferences.activityOrder = [TransitionActivity.mealTime.id, TransitionActivity.cleanUp.id]
        try storage.save(preferences)

        let available = try controller.availableActivities()
        XCTAssertEqual(Array(available.prefix(2)), [.mealTime, .cleanUp],
                       "the arrangement decides, and its first three are what a shield can show")
        XCTAssertEqual(Set(available), Set(TransitionActivity.allCases),
                       "arranging is not filtering — no row falls off the list")
    }

    func testTheWholeListIsOfferedWhenTheParentHasArrangedNothing() throws {
        XCTAssertEqual(try controller.availableActivities(), TransitionActivity.allCases)
    }

    // MARK: D-072 — the parent's override

    /// The whole point of it: the child's answer is still on the window, and every screen shows
    /// the parent's instead.
    func testTheParentsChoiceOutranksTheChilds() throws {
        try controller.start()
        try controller.choose(.freeTime)

        var config = try storage.loadConfiguration()
        config.parentChosenActivity = .mealTime
        try storage.save(config)

        let snapshot = try controller.tick()
        XCTAssertEqual(snapshot.chosenActivity, .mealTime)
        XCTAssertTrue(snapshot.chosenByParent)
        XCTAssertEqual(try storage.loadSessionWindow()?.chosenActivity, .freeTime,
                       "the child's own answer is kept — it is theirs, it is just not what happens")
    }

    /// A decision ends the question, so nothing is asked and no menu is drawn.
    func testAParentsChoiceStopsTheChildBeingAsked() throws {
        try controller.start()
        clock.advance(850)   // 50 left — the reminder that asks (WarningStateEngine.chooserIndex)
        XCTAssertTrue(try controller.tick().isChoosingMoment, "nobody has decided yet")

        var config = try storage.loadConfiguration()
        config.parentChosenActivity = .cleanUp
        try storage.save(config)
        XCTAssertFalse(try controller.tick().isChoosingMoment,
                       "asking for an answer we intend to ignore is worse than not asking")

        let moment = ShieldMomentResolver.moment(window: try storage.loadSessionWindow(),
                                                 configuration: try storage.loadConfiguration(),
                                                 availableActivities: TransitionActivity.allCases,
                                                 now: clock.now)
        guard case let .parentChoseNext(_, activity) = moment else {
            return XCTFail("the transition screen should tell, not ask: got \(moment)")
        }
        XCTAssertEqual(activity, .cleanUp)
    }

    /// It lasts one session. A parent who meant "tonight, we're eating" is not still saying it on
    /// Thursday.
    func testTheParentsChoiceIsClearedByTheNextStart() throws {
        var config = try storage.loadConfiguration()
        config.parentChosenActivity = .mealTime
        try storage.save(config)
        try controller.start()

        XCTAssertNil(try storage.loadConfiguration().parentChosenActivity)
        XCTAssertNil(try controller.tick().chosenActivity)
    }

    /// The end of a session it governed still names it — the child is standing there reading it.
    func testTheParentsChoiceNamesTheFinish() throws {
        try controller.start()
        var config = try storage.loadConfiguration()
        config.parentChosenActivity = .outside
        try storage.save(config)
        clock.advance(900)

        let done = try controller.tick()
        XCTAssertEqual(done.state, .finished)
        XCTAssertEqual(done.chosenActivity, .outside)

        let moment = ShieldMomentResolver.moment(window: try storage.loadSessionWindow(),
                                                 configuration: try storage.loadConfiguration(),
                                                 availableActivities: TransitionActivity.allCases,
                                                 now: clock.now)
        guard case let .finishedParentChose(activity) = moment else {
            return XCTFail("expected the told-not-asked finish, got \(moment)")
        }
        XCTAssertEqual(activity, .outside)
    }

    /// §7 — the copy has to be honest about who decided. "You picked Outside" to a child who
    /// picked nothing is a small lie, and small lies are what a child stops believing.
    func testTheToldScreenNeverClaimsTheChildPicked() {
        let told = ShieldPresentation.make(for: .parentChoseNext(minutesLeft: 5, activity: .mealTime),
                                           childName: "Ivy")
        XCTAssertFalse(told.subtitle.lowercased().contains("you picked"))
        XCTAssertTrue(told.subtitle.contains("Meal time"))
        XCTAssertNil(told.secondaryButtonLabel, "nothing to choose means no menu")
        XCTAssertTrue(told.submenuItems.isEmpty)
        XCTAssertTrue(told.primaryButtonContinues, "the minutes they have left are still theirs")

        let end = ShieldPresentation.make(for: .finishedParentChose(activity: .mealTime), childName: "Ivy")
        XCTAssertFalse(end.subtitle.lowercased().contains("you chose"))
        XCTAssertTrue(end.subtitle.contains("Meal time"))
    }

    func testChoiceIsPersistedOnTheWindowAndSurvivesRelaunch() throws {
        try controller.start()
        clock.advance(400)   // 500 left → warning10
        let snap = try controller.choose(.cleanUp)
        XCTAssertEqual(snap.chosenActivity, .cleanUp)
        XCTAssertEqual(try storage.loadSessionWindow()?.chosenActivity, .cleanUp)

        let c = clock!
        let relaunched = SessionController(storage: storage, now: { c.now })
        XCTAssertEqual(try relaunched.restore().chosenActivity, .cleanUp)
    }

    func testChoiceCarriesThroughToFinishedAndClearsOnNextStart() throws {
        try controller.start()
        try controller.choose(.mealTime)
        clock.advance(900)
        let done = try controller.tick()
        XCTAssertEqual(done.state, .finished)
        XCTAssertEqual(done.chosenActivity, .mealTime, "Time's Up can name it")
        // Next day, next session: no leftover choice.
        clock.advance(24 * 3600)
        let next = try controller.start()
        XCTAssertNil(next.chosenActivity)
    }

    func testChoosingWithoutASessionIsANoOp() throws {
        let snap = try controller.choose(.familyTime)
        XCTAssertEqual(snap.state, .idle)
        XCTAssertNil(snap.chosenActivity)
        XCTAssertNil(try storage.loadSessionWindow())
    }

    func testChoiceCanBeChanged() throws {
        try controller.start()
        try controller.choose(.cleanUp)
        XCTAssertEqual(try controller.choose(.mealTime).chosenActivity, .mealTime)
    }

    func testExtensionKeepsTheChoice() {
        let w = SessionWindow(startedAt: Date(), budgetSeconds: 60, chosenActivity: .freeTime)
        XCTAssertEqual(w.extended(bySeconds: 600).chosenActivity, .freeTime)
    }

    func testEveryActivityHasChildFacingCopy() {
        for a in TransitionActivity.allCases {
            XCTAssertFalse(a.invitation.isEmpty)
            XCTAssertFalse(a.symbolName.isEmpty)
            XCTAssertFalse(a.displayName.isEmpty)
        }
    }
}
