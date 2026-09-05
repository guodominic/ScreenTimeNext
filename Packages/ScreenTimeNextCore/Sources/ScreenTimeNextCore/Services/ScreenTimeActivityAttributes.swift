//  ScreenTimeActivityAttributes.swift
//  ScreenTimeNextCore
//
//  D-014. The ActivityKit attributes shared by the app (which starts the activity) and the
//  widget extension (which renders it). Guarded so the package still builds for macOS tests.

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

public struct ScreenTimeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var startedAt: Date
        public var endsAt: Date
        public var chosenActivityRaw: String?
        public var stateName: String

        public init(startedAt: Date, endsAt: Date, chosenActivityRaw: String?, stateName: String) {
            self.startedAt = startedAt
            self.endsAt = endsAt
            self.chosenActivityRaw = chosenActivityRaw
            self.stateName = stateName
        }

        public var chosenActivity: TransitionActivity? {
            chosenActivityRaw.flatMap(TransitionActivity.init(rawValue:))
        }
    }

    public var childName: String

    public init(childName: String) {
        self.childName = childName
    }
}
#endif
