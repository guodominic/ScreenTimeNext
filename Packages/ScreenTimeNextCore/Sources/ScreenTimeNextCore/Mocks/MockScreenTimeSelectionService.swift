//  MockScreenTimeSelectionService.swift
//  ScreenTimeNextCore
//
//  Task 002. In-memory stand-in for the real FamilyControls selection adapter (Task 005).

import Foundation

public final class MockScreenTimeSelectionService: ScreenTimeSelectionService, @unchecked Sendable {

    private let lock = NSLock()
    private var _snapshot: SelectionSnapshot?
    private var _failDecoding = false

    public init(initial: SelectionSnapshot? = nil) {
        _snapshot = initial
    }

    // MARK: ScreenTimeSelectionService

    public func loadSelection() throws -> SelectionSnapshot? {
        try lock.withLock {
            if _failDecoding { throw ScreenTimeSelectionError.decodingFailed }
            return _snapshot
        }
    }

    public func save(_ selection: SelectionSnapshot) throws {
        lock.withLock { _snapshot = selection }
    }

    public func clearSelection() throws {
        lock.withLock { _snapshot = nil }
    }

    // MARK: Test controls

    /// Simulate a persisted selection that no longer decodes (PRD §6.4 — prompt to reselect, never crash).
    public func setFailDecoding(_ fail: Bool) { lock.withLock { _failDecoding = fail } }

    /// A plausible non-empty selection for previews and onboarding walkthroughs.
    public static func sampleSnapshot(apps: Int = 3, categories: Int = 1, webDomains: Int = 0) -> SelectionSnapshot {
        SelectionSnapshot(
            payload: Data("mock-selection".utf8),
            summary: SelectionSummary(applicationCount: apps, categoryCount: categories, webDomainCount: webDomains)
        )
    }
}
