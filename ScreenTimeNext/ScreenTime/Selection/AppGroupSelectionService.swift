//  AppGroupSelectionService.swift
//  ScreenTimeNext
//
//  Task 005 — the real `ScreenTimeSelectionService`. One JSON file in the App Group container,
//  because the DeviceActivityMonitor and Shield extensions have to read the same selection while
//  the app is not running (Rule 5, PRD §13/§14).
//
//  It stores an opaque `SelectionSnapshot` and never looks inside the payload — decoding it back
//  into a `FamilyActivitySelection` is `FamilyActivitySelectionCoding`'s job, in this same folder.

import Foundation
import ScreenTimeNextCore

final class AppGroupSelectionService: ScreenTimeSelectionService, @unchecked Sendable {

    private let fileURL: URL
    private let lock = NSLock()

    /// Prefers the App Group; falls back to the app's own container so a signing problem degrades
    /// to "the extensions can't see the selection" instead of a crash on launch — the same bargain
    /// `FileStorageService.shared()` makes (D-023).
    init?(fileManager: FileManager = .default) {
        let base: URL
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            base = group
        } else if let local = try? fileManager.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: true) {
            base = local
        } else {
            return nil
        }
        let directory = base.appendingPathComponent("ScreenTimeNext", isDirectory: true)
        guard (try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            return nil
        }
        fileURL = directory.appendingPathComponent("selection.json")
    }

    /// True when the selection lives where the extensions can read it. False means enforcement
    /// cannot work however healthy the app looks.
    var isShared: Bool {
        fileURL.path.contains("Shared/AppGroup")
    }

    // MARK: ScreenTimeSelectionService

    func loadSelection() throws -> SelectionSnapshot? {
        try lock.withLock {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            do {
                return try JSONDecoder().decode(SelectionSnapshot.self, from: data)
            } catch {
                // §6.4 — a record we cannot read is reported, not silently treated as "nothing
                // picked". The parent needs to know their choice was lost, not think they never
                // made one.
                throw ScreenTimeSelectionError.decodingFailed
            }
        }
    }

    func save(_ selection: SelectionSnapshot) throws {
        try lock.withLock {
            let data: Data
            do {
                data = try JSONEncoder().encode(selection)
            } catch {
                throw ScreenTimeSelectionError.decodingFailed
            }
            // Atomic: an extension may be reading this file at the same moment.
            do {
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                throw ScreenTimeSelectionError.containerUnavailable
            }
        }
    }

    func clearSelection() throws {
        lock.withLock {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
