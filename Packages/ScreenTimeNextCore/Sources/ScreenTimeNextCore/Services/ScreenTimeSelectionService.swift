//  ScreenTimeSelectionService.swift
//  ScreenTimeNext
//
//  PRD §6.4, §13 — protocol only. Real adapter: Task 005.
//  Framework-free: imports Foundation only. See docs/source-layout.md.

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

public extension SelectionSnapshot {

    /// The same opaque payload with new counts.
    ///
    /// Rule 1 / §13 — building a snapshot means touching `payload`, and `payload` is only allowed
    /// to be touched here and in the selection adapter (scripts/privacy-audit.sh enforces it). So
    /// callers that only know the COUNTS — the picker screen, for one — ask for a snapshot instead
    /// of assembling one, and never see the payload at all.
    func withSummary(_ summary: SelectionSummary) -> SelectionSnapshot {
        SelectionSnapshot(payload: payload, summary: summary)
    }

    /// A snapshot for Phase 0, where no real `FamilyActivitySelection` exists yet.
    ///
    /// The payload is a fixed marker, not an encoded selection: it exists so the record has the
    /// same shape it will have in Phase 1. Task 005 replaces this with the encoded selection and
    /// this factory goes away.
    static func phase0Placeholder(summary: SelectionSummary) -> SelectionSnapshot {
        SelectionSnapshot(payload: Data("phase0-selection".utf8), summary: summary)
    }
}

public enum ScreenTimeSelectionError: Error, Sendable {
    /// Persisted selection could not be decoded. PRD §6.4 — prompt the parent to reselect;
    /// never crash and never fall back to an invented identifier.
    case decodingFailed
    case notAuthorized
    /// Task 005 — the container could not be written to (App Group unreachable, disk full).
    /// Distinct from `decodingFailed`: the record is fine, we just could not keep it.
    case containerUnavailable
}

/// PRD §6.4, §13. Implemented for real in Task 005; mocked in Task 002.
public protocol ScreenTimeSelectionService: Sendable {
    func loadSelection() throws -> SelectionSnapshot?
    func save(_ selection: SelectionSnapshot) throws
    func clearSelection() throws
}
