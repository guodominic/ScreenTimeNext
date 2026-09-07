//  ShieldIconStore.swift
//  ScreenTimeNextCore
//
//  D-051 — where Pip's face lives so a shield can draw it.
//
//  `ShieldConfiguration.icon` is a `UIImage`, which is the one opening the system leaves us: the
//  layout, typography and buttons are Apple's, but the picture is ours. The catch is that the
//  shield is drawn in an extension that has no SwiftUI views of ours and must answer in a moment.
//
//  So the APP renders Pip — once per urgency, in that moment's colour — into the App Group, and the
//  extension just loads a file. Nothing is rendered in the extension, nothing is drawn twice, and
//  the mascot the parent sees in the preview is byte-for-byte the one their child meets.
//
//  Framework-free: paths and bytes only. The rendering lives in the app, the loading in the shield.

import Foundation

public enum ShieldIconStore {

    /// One image per moment, because the colour and the expression ARE the message (D-018).
    public static func fileName(for urgency: ShieldUrgency) -> String {
        "pip-\(urgency.rawValue).png"
    }

    /// The shared folder. `nil` only when the App Group cannot be opened, which means the shield
    /// could not have read anything anyway.
    public static func directory(fileManager: FileManager = .default) -> URL? {
        guard let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            return nil
        }
        let directory = group.appendingPathComponent("ShieldIcons", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func url(for urgency: ShieldUrgency, fileManager: FileManager = .default) -> URL? {
        directory(fileManager: fileManager)?.appendingPathComponent(fileName(for: urgency))
    }

    /// Bytes for the shield to turn into a `UIImage`, or nil to fall back to an SF Symbol.
    public static func imageData(for urgency: ShieldUrgency, fileManager: FileManager = .default) -> Data? {
        guard let url = url(for: urgency, fileManager: fileManager) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Written by the app. Atomic, because the shield may be reading this exact file at the moment
    /// a session starts.
    @discardableResult
    public static func write(_ data: Data, for urgency: ShieldUrgency, fileManager: FileManager = .default) -> Bool {
        guard let url = url(for: urgency, fileManager: fileManager) else { return false }
        return (try? data.write(to: url, options: [.atomic])) != nil
    }

    /// True when every moment has a face waiting for it. The app re-renders when this is false —
    /// on a first run, and after an update that changed how Pip looks.
    public static func isComplete(fileManager: FileManager = .default) -> Bool {
        ShieldUrgency.allCases.allSatisfy { urgency in
            guard let url = url(for: urgency, fileManager: fileManager) else { return false }
            return fileManager.fileExists(atPath: url.path)
        }
    }
}
