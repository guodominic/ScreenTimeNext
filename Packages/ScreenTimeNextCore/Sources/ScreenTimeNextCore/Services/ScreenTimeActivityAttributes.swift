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
        /// D-029 — the name and icon travel with the state.
        ///
        /// The widget runs in its own process and cannot read the parent's custom-activity list, so
        /// an id alone would render a family's "Piano" as nothing at all. Both are optional so a
        /// Live Activity started by an older build still decodes; those fall back to the built-ins.
        public var chosenActivityName: String?
        public var chosenActivitySymbol: String?
        public var stateName: String

        public init(startedAt: Date, endsAt: Date, chosenActivityRaw: String?,
                    chosenActivityName: String? = nil, chosenActivitySymbol: String? = nil,
                    stateName: String) {
            self.startedAt = startedAt
            self.endsAt = endsAt
            self.chosenActivityRaw = chosenActivityRaw
            self.chosenActivityName = chosenActivityName
            self.chosenActivitySymbol = chosenActivitySymbol
            self.stateName = stateName
        }

        public var chosenActivity: TransitionActivity? {
            guard let id = chosenActivityRaw else { return nil }
            if let name = chosenActivityName, let symbol = chosenActivitySymbol {
                return TransitionActivity(id: id, displayName: name,
                                          invitation: "Let's go!", symbolName: symbol,
                                          isCustom: TransitionActivity.builtIn(id: id) == nil)
            }
            return TransitionActivity.builtIn(id: id)
        }
    }

    public var childName: String

    public init(childName: String) {
        self.childName = childName
    }
}
#endif
