//  SessionPresence.swift
//  ScreenTimeNextCore
//
//  D-014. A Live Activity keeps the countdown visible outside the app — Dynamic Island / status
//  area on iPhone, Lock Screen on iPad. This protocol is the framework-free seam: SessionController
//  drives it exactly like notifications; the app implements it on ActivityKit.

import Foundation

/// Everything the Live Activity needs. Pure data; the widget renders it.
public struct SessionPresenceState: Equatable, Sendable {
    public let childName: String
    public let startedAt: Date
    public let endsAt: Date
    public let chosenActivity: TransitionActivity?
    public let stateName: String     // ScreenTimeState.rawValue, so the widget can color itself

    public init(childName: String, startedAt: Date, endsAt: Date, chosenActivity: TransitionActivity?, stateName: String) {
        self.childName = childName
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.chosenActivity = chosenActivity
        self.stateName = stateName
    }
}

public protocol SessionPresenting: Sendable {
    /// Start or update the presence for the current window.
    func show(_ state: SessionPresenceState)
    /// End the presence (session finalized, day rolled over, parent ended it).
    func hide()
}

public final class MockSessionPresenter: SessionPresenting, @unchecked Sendable {
    private let lock = NSLock()
    private var _shown: [SessionPresenceState] = []
    private var _hideCount = 0
    public init() {}
    public func show(_ state: SessionPresenceState) { lock.withLock { _shown.append(state) } }
    public func hide() { lock.withLock { _hideCount += 1 } }
    public var shown: [SessionPresenceState] { lock.withLock { _shown } }
    public var hideCount: Int { lock.withLock { _hideCount } }
}
