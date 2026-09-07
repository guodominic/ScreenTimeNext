//  FileStorageServiceTests.swift
//  ScreenTimeNextCoreTests
//
//  Task 006 — QA-05 (budget survives relaunch) and the corrupt-store contract.

import XCTest
@testable import ScreenTimeNextCore

final class FileStorageServiceTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenTimeNextTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func open() throws -> FileStorageService {
        try FileStorageService(directory: directory)
    }

    func testFreshStoreHasDefaultsAndManifest() throws {
        let store = try open()
        XCTAssertNil(try store.loadChildProfile())
        XCTAssertEqual(try store.loadConfiguration(), .default)
        XCTAssertNil(try store.loadSessionWindow())
        XCTAssertEqual(try store.loadProtectionState(), .unshielded)
        XCTAssertEqual(store.schemaVersion, AppGroup.currentSchemaVersion)
    }

    /// QA-05 — a second instance on the same directory is a "relaunch".
    func testEverythingSurvivesRelaunch() throws {
        let first = try open()
        try first.save(ChildProfile(name: "Ivy"))
        var config = ScreenTimeConfiguration.default
        config.dailyBudgetSeconds = 2700
        config.warningOffsetsSeconds = [600, 300]
        config.parentChosenActivity = .cleanUp
        try first.save(config)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        try first.save(SessionWindow(startedAt: start, budgetSeconds: 2700))
        try first.save(DailyUsage(date: start, budgetSeconds: 2700, usedSeconds: 900))
        try first.save(ProtectionState.temporarilyExtended)

        let relaunched = try open()
        XCTAssertEqual(try relaunched.loadChildProfile()?.name, "Ivy")
        XCTAssertEqual(try relaunched.loadConfiguration(), config)
        XCTAssertEqual(try relaunched.loadSessionWindow()?.startedAt, start)
        XCTAssertEqual(try relaunched.loadDailyUsage(for: start)?.usedSeconds, 900)
        XCTAssertEqual(try relaunched.loadProtectionState(), .temporarilyExtended)
    }

    func testCorruptFilesDegradeToDefaultsNotCrashes() throws {
        let store = try open()
        try store.save(ChildProfile(name: "Athan"))
        // Scribble over the files.
        for name in ["childProfile.json", "configuration.json", "protectionState.json", "dailyUsage.json"] {
            try Data("not json".utf8).write(to: directory.appendingPathComponent(name))
        }
        XCTAssertNil(try store.loadChildProfile())
        XCTAssertEqual(try store.loadConfiguration(), .default)
        XCTAssertEqual(try store.loadProtectionState(), .unshielded)
        XCTAssertNil(try store.loadDailyUsage(for: Date()))
        // And the store is still writable afterwards.
        try store.save(ChildProfile(name: "Athan"))
        XCTAssertEqual(try store.loadChildProfile()?.name, "Athan")
    }

    func testMissingManifestIsRestampedWithoutTouchingData() throws {
        let store = try open()
        try store.save(ChildProfile(name: "Ivy"))
        try FileManager.default.removeItem(at: directory.appendingPathComponent("manifest.json"))
        let reopened = try open()
        XCTAssertEqual(reopened.schemaVersion, AppGroup.currentSchemaVersion)
        XCTAssertEqual(try reopened.loadChildProfile()?.name, "Ivy")
    }

    func testUsageIsBucketedByLocalDayAndPruned() throws {
        let store = try open()
        let noon = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        try store.save(DailyUsage(date: noon, budgetSeconds: 3600, usedSeconds: 100))
        XCTAssertEqual(try store.loadDailyUsage(for: noon.addingTimeInterval(3 * 3600))?.usedSeconds, 100)

        let old = Calendar.current.date(byAdding: .day, value: -(FileStorageService.usageRetentionDays + 5), to: noon)!
        try store.save(DailyUsage(date: old, budgetSeconds: 3600, usedSeconds: 50))
        // Saving today again prunes the old day.
        try store.save(DailyUsage(date: noon, budgetSeconds: 3600, usedSeconds: 200))
        XCTAssertNil(try store.loadDailyUsage(for: old))
        XCTAssertEqual(try store.loadDailyUsage(for: noon)?.usedSeconds, 200)
    }

    func testClearAndErase() throws {
        let store = try open()
        try store.save(ChildProfile(name: "Ivy"))
        try store.save(SessionWindow(startedAt: Date(), budgetSeconds: 60))
        try store.clearSessionWindow()
        XCTAssertNil(try store.loadSessionWindow())
        XCTAssertNotNil(try store.loadChildProfile())
        try store.eraseAll()
        XCTAssertNil(try store.loadChildProfile())
        XCTAssertEqual(try store.loadConfiguration(), .default)
        XCTAssertEqual(store.schemaVersion, AppGroup.currentSchemaVersion, "erase keeps the manifest")
    }

    /// D-016 — "is the app set up" is a stored configuration, not a stored profile.
    func testHasStoredConfiguration() throws {
        let store = try open()
        XCTAssertFalse(try store.hasStoredConfiguration())
        try store.save(ScreenTimeConfiguration.default)
        XCTAssertTrue(try store.hasStoredConfiguration())
        try store.eraseAll()
        XCTAssertFalse(try store.hasStoredConfiguration())
    }

    func testDayKeyIsLexicallyChronological() {
        let a = FileStorageService.dayKey(Date(timeIntervalSince1970: 1_700_000_000))
        let b = FileStorageService.dayKey(Date(timeIntervalSince1970: 1_700_000_000 + 40 * 86_400))
        XCTAssertLessThan(a, b)
        XCTAssertEqual(a.count, 10)
    }

    func testUnwritableDirectoryThrowsContainerUnavailable() {
        let bad = URL(fileURLWithPath: "/dev/null/ScreenTimeNext-impossible")
        XCTAssertThrowsError(try FileStorageService(directory: bad)) { error in
            guard case ScreenTimeStorageError.containerUnavailable = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }
}
