//  NotificationPlanTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 016 — fire dates from absolute timestamps; toggles honored; stale ones dropped;
//  rescheduled on start/choose/settings; cancelled on end and rollover.

import XCTest
@testable import ScreenTimeNextCore

final class NotificationPlanTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testFullPlanForFreshWindow() {
        let window = SessionWindow(startedAt: start, budgetSeconds: 1200)
        let plan = NotificationPlan.make(for: window, configuration: .default, childName: "Ivy", now: start)
        XCTAssertEqual(plan.map(\.identifier), [NotificationIdentifier.warning(0), NotificationIdentifier.warning(1), NotificationIdentifier.warning(2), NotificationIdentifier.finished])
        XCTAssertEqual(plan.map { Int($0.fireDate.timeIntervalSince(start)) }, [600, 900, 1140, 1200])
        XCTAssertTrue(plan[0].body.contains("Ivy"))
        XCTAssertFalse(plan.contains { $0.title.uppercased().contains("TIME'S UP") })
    }

    func testDisabledWarningsAreOmittedButExpiryStays() {
        var config = ScreenTimeConfiguration.default
        config.warningOffsetsSeconds = [300]
        let window = SessionWindow(startedAt: start, budgetSeconds: 1200)
        let plan = NotificationPlan.make(for: window, configuration: config, childName: "Ivy", now: start)
        XCTAssertEqual(plan.map(\.identifier), [NotificationIdentifier.warning(0), NotificationIdentifier.finished])
        XCTAssertTrue(plan[0].title.contains("5 minutes left"), "a single warning is the first warning and says its minutes")
    }

    func testPastNotificationsAreDropped() {
        let window = SessionWindow(startedAt: start, budgetSeconds: 1200)
        let later = start.addingTimeInterval(950)   // past the 10- and 5-minute marks
        let plan = NotificationPlan.make(for: window, configuration: .default, childName: "Ivy", now: later)
        XCTAssertEqual(plan.map(\.identifier), [NotificationIdentifier.warning(2), NotificationIdentifier.finished])
    }

    func testChosenActivityAppearsInLaterCopy() {
        let window = SessionWindow(startedAt: start, budgetSeconds: 1200, chosenActivity: .lego)
        let plan = NotificationPlan.make(for: window, configuration: .default, childName: "Ivy", now: start)
        XCTAssertTrue(plan[1].body.contains("LEGO"))
        XCTAssertTrue(plan[3].body.contains("Let's go build!"))
    }

    func testShortBudgetOnlyGetsWhatFits() {
        let window = SessionWindow(startedAt: start, budgetSeconds: 300)   // 5 minutes total
        let plan = NotificationPlan.make(for: window, configuration: .default, childName: "Ivy", now: start)
        // 10-minute mark is before start → dropped; 5-minute mark == now → not strictly future → dropped.
        XCTAssertEqual(plan.map(\.identifier), [NotificationIdentifier.warning(2), NotificationIdentifier.finished])
    }

    // MARK: Controller integration

    private func makeController(_ scheduler: MockNotificationScheduler, now: @escaping @Sendable () -> Date) throws -> (SessionController, InMemoryScreenTimeStorageService) {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(ChildProfile(name: "Ivy"))
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 1200
        try storage.save(config)
        return (SessionController(storage: storage, notifications: scheduler, now: now), storage)
    }

    func testStartSchedulesAndEndEarlyCancels() throws {
        let scheduler = MockNotificationScheduler()
        let clock = start
        let (controller, _) = try makeController(scheduler) { clock }
        try controller.start()
        XCTAssertEqual(scheduler.latestPlan?.count, 4)
        try controller.endEarly()
        XCTAssertEqual(scheduler.cancelCount, 1)
    }

    func testChoosingReschedulesWithActivityCopy() throws {
        let scheduler = MockNotificationScheduler()
        let clock = start
        let (controller, _) = try makeController(scheduler) { clock }
        try controller.start()
        try controller.choose(.reading)
        XCTAssertEqual(scheduler.plans.count, 2)
        XCTAssertTrue(scheduler.latestPlan?.last?.body.contains("Reading") ?? false)
    }

    func testSettingsChangeReschedulesAndRolloverCancels() throws {
        let scheduler = MockNotificationScheduler()
        final class Clock: @unchecked Sendable { var now: Date; init(_ d: Date) { now = d } }
        let clock = Clock(start)
        let (controller, storage) = try makeController(scheduler) { clock.now }
        try controller.start()
        var config = try storage.loadConfiguration()
        config.warningOffsetsSeconds = [300, 60]
        try storage.save(config)
        try controller.rescheduleNotifications()
        XCTAssertEqual(scheduler.latestPlan?.count, 3)
        clock.now = start.addingTimeInterval(24 * 3600)
        _ = try controller.tick()   // rollover finalizes → cancel
        XCTAssertEqual(scheduler.cancelCount, 1)
    }
}
