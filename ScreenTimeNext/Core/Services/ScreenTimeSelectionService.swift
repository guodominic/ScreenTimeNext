//  ScreenTimeSelectionService.swift
//  ScreenTimeNext
//
//  PRD §6.4, §13 — protocol only. Real adapter: Task 005.
//  Framework-free: imports Foundation only. See ScreenTimeNext/README.md.

import Foundation

/// Display-safe summary of the parent's selection.
///
/// PRD §16 — never surface or log the underlying privacy-preserving tokens. Counts only.
public struct SelectionSummary: Codable, Equatable, Sendable {
    public let applicationCount: Int
    public let categoryCount: Int
    public let webDomainCount: Int

    public init(applicationCount: Int, categoryCount: Int, webDomainCount: Int) {
        self.applicationCount = applicationCount
        self.categoryCount = categoryCount
        self.webDomainCount = webDomainCount
    }

    public var isEmpty: Bool {
        applicationCount == 0 && categoryCount == 0 && webDomainCount == 0
    }

    public static let empty = SelectionSummary(applicationCount: 0, categoryCount: 0, webDomainCount: 0)
}

/// An opaque, serializable handle to a `FamilyActivitySelection`.
///
/// Rule 7 — the Apple selection remains the source of truth; this wraps it, never replaces it.
/// Rule 1 — `payload` stays opaque outside `ScreenTimeNext/ScreenTime/Selection/`, which is the only
/// place that knows how to encode and decode it. Never build an app-name-to-bundle-ID map (PRD §13).
public struct SelectionSnapshot: Codable, Equatable, Sendable {
    public let payload: Data
    public let summary: SelectionSummary

    public init(payload: Data, summary: SelectionSummary) {
        self.payload = payload
        self.summary = summary
    }
}

public enum ScreenTimeSelectionError: Error, Sendable {
    /// Persisted selection could not be decoded. PRD §6.4 — prompt the parent to reselect;
    /// never crash and never fall back to an invented identifier.
    case decodingFailed
    case notAuthorized
}

/// PRD §6.4, §13. Implemented for real in Task 005; mocked in Task 002.
public protocol ScreenTimeSelectionService: Sendable {
    func loadSelection() throws -> SelectionSnapshot?
    func save(_ selection: SelectionSnapshot) throws
    func clearSelection() throws
}
