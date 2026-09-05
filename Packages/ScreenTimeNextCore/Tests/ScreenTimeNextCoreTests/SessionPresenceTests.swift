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

        try controller.choose(.lego)
        XCTAssertEqual(presence.shown.last?.chosenActivity, .lego)

        try controller.extend(bySeconds: 600)
        XCTAssertEqual(presence.shown.last?.endsAt, start.addingTimeInterval(3600 + 600))

        try controller.endEarly()
        XCTAssertEqual(presence.hideCount, 1)
    }
}
