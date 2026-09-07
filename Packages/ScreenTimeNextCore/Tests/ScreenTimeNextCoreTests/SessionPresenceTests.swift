//  SessionPresenceTests.swift — D-014: the Live Activity seam follows the session.
import XCTest
@testable import ScreenTimeNextCore

final class SessionPresenceTests: XCTestCase {
    func testPresenceFollowsStartChooseExtendAndEnd() throws {
        let storage = InMemoryScreenTimeStorageService()
        try storage.save(ChildProfile(name: "Ivy"))
        let presence = MockSessionPresenter()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let controller = SessionController(storage: storage, presence: presence, now: { start })

        try controller.start()
        XCTAssertEqual(presence.shown.count, 1)
        XCTAssertEqual(presence.shown.last?.childName, "Ivy")
        XCTAssertEqual(presence.shown.last?.stateName, ScreenTimeState.active.rawValue)

        try controller.choose(.cleanUp)
        XCTAssertEqual(presence.shown.last?.chosenActivity, .cleanUp)

        try controller.extend(bySeconds: 600)
        // The default budget (D-034: 900s) plus the extension, read from the constant rather than
        // written out — this test is about the Live Activity following the session, not about
        // what the budget happens to be this month.
        XCTAssertEqual(presence.shown.last?.endsAt,
                       start.addingTimeInterval(Double(ScreenTimeConfiguration.defaultBudgetSeconds + 600)))

        try controller.endEarly()
        XCTAssertEqual(presence.hideCount, 1)
    }
}
