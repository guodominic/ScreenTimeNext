//  FamilyActivitySelectionCoding.swift
//  ScreenTimeNext
//
//  Task 005 — the boundary between Apple's `FamilyActivitySelection` and the app's opaque
//  `SelectionSnapshot`. Rule 1 / D-001: this folder is the ONE place that may hold both types at
//  once. Everything above it sees counts and an opaque payload, never a token.
//
//  API verified against Apple's documentation (2026-09-06), per Rule 8:
//      FamilyActivitySelection conforms to Encodable, Decodable and Equatable (NOT Hashable)
//      applicationTokens / categoryTokens / webDomainTokens are Sets of opaque tokens
//      includeEntireCategory says whether a picked category covers the apps inside it

import Foundation
import FamilyControls
import ScreenTimeNextCore

enum FamilyActivitySelectionCoding {

    /// Encode a live selection into the record the rest of the app passes around.
    ///
    /// The payload is Apple's own encoding of the selection, kept opaque on purpose: §13 says the
    /// selection stays the source of truth and is never re-expressed as app names or bundle IDs.
    /// Only the three counts cross the boundary (§16).
    static func snapshot(from selection: FamilyActivitySelection) throws -> SelectionSnapshot {
        let payload: Data
        do {
            payload = try JSONEncoder().encode(selection)
        } catch {
            throw ScreenTimeSelectionError.decodingFailed
        }
        return SelectionSnapshot(payload: payload, summary: summary(of: selection))
    }

    /// Restore a live selection from a stored record.
    ///
    /// Throws `decodingFailed` rather than returning an empty selection, because those two mean
    /// very different things to a parent: "nothing is protected because you picked nothing" and
    /// "nothing is protected because we lost your choice" need different screens (§6.4).
    static func selection(from snapshot: SelectionSnapshot) throws -> FamilyActivitySelection {
        do {
            return try JSONDecoder().decode(FamilyActivitySelection.self, from: snapshot.payload)
        } catch {
            throw ScreenTimeSelectionError.decodingFailed
        }
    }

    /// Counts only — never names, never tokens.
    static func summary(of selection: FamilyActivitySelection) -> SelectionSummary {
        SelectionSummary(applicationCount: selection.applicationTokens.count,
                         categoryCount: selection.categoryTokens.count,
                         webDomainCount: selection.webDomainTokens.count)
    }

    /// True when the parent picked nothing at all. A selection with `includeEntireCategory` set but
    /// no tokens still protects nothing, so this is the honest test for "is anything covered".
    static func isEmpty(_ selection: FamilyActivitySelection) -> Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }
}
