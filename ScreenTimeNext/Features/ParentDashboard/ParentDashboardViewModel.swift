//  ParentDashboardViewModel.swift
//  ScreenTimeNext
//
//  Task 014 — PRD §6.9. Everything the dashboard shows is re-read from storage on appear and on
//  foreground (PRD §14: the extension may have changed protection state while the app was closed).

import SwiftUI
import Observation
import ScreenTimeNextCore

@Observable
final class ParentDashboardViewModel {

    private(set) var profile: ChildProfile?
    private(set) var configuration: ScreenTimeConfiguration = .default
    private(set) var selectionSummary: SelectionSummary = .empty
    /// D-028 — kept whole, so the parent can open it and see what the counts stand for.
    private(set) var selection: SelectionSnapshot?
    private(set) var protectionState: ProtectionState = .unshielded
    private(set) var session: ChildSessionSnapshot = .idle
    private(set) var remainingTodaySeconds: Int = 0
    private(set) var notificationsDenied = false
    /// D-016 — the minutes shown on the idle hero; seeded from the saved budget so a repeat
    /// "fifteen minutes" is two taps from launch.
    var quickMinutes: Int = ScreenTimeConfiguration.defaultBudgetSeconds / 60
    /// D-057 — true once the parent has moved the dial themselves since it was last seeded.
    ///
    /// The dial has two sources and they disagree: the saved budget, and a one-off number a parent
    /// spun on the hero. This says which one is currently on screen, so a routine reload can leave
    /// their number alone while a deliberate Settings save overrides it.
    private var quickMinutesIsParentSet = false
    private(set) var authorization: ScreenTimeAuthorizationStatus = .notDetermined
    /// Task 004 — a request in flight, and whatever went wrong last time. Both are parent-facing.
    private(set) var isRequestingAuthorization = false
    private(set) var authorizationError: String?
    /// D-052 — the dashboard no longer SHOWS the monitor's check-ins; a parent should not have to
    /// read our diagnostics to trust the app. The journal is still written (it costs nothing and it
    /// is what settled two bugs this week), just not surfaced.
    /// D-053 — the slide's position: true when every restriction is off for today.
    private(set) var restrictionsAreCleared = false

    private let services: ServiceContainer
    private let controller: SessionController
    private var tickTask: Task<Void, Never>?

    init(services: ServiceContainer) {
        self.services = services
        controller = services.makeSessionController()
    }

    func appeared() {
        reload()
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshSession()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func disappeared() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Full re-read: appear, foreground, after Settings.
    func reload() {
        Task {
            notificationsDenied = await services.notifications.isPermissionDenied
            authorization = await services.authorization.status
        }
        let storage = services.storage
        profile = try? storage.loadChildProfile()
        configuration = (try? storage.loadConfiguration()) ?? .default
        selection = try? services.selection.loadSelection()
        selectionSummary = selection?.summary ?? .empty
        protectionState = (try? storage.loadProtectionState()) ?? .unshielded
        restrictionsAreCleared = ((try? storage.loadPickerPreferences()) ?? .default).restrictionsAreCleared()
        refreshSession()
        // D-057 — seeded AFTER the session is refreshed, and gated on the session actually
        // RUNNING. The old test was `session.window == nil`, read before the refresh — and a
        // finished window survives until the day rolls over (Task 017), so after the first session
        // of the day the dial silently stopped following the saved budget for good.
        if !sessionIsRunning && !quickMinutesIsParentSet {
            quickMinutes = configuration.dailyBudgetSeconds / 60
        }
    }

    /// D-057 — Settings wrote a new budget, so the hero's dial follows it.
    ///
    /// A parent who has just set fifteen minutes in Settings and comes back to a dial still saying
    /// thirty has been told two different things by the same app. An explicit save is the later and
    /// more deliberate statement, so it wins over a number spun on the hero earlier.
    func configurationChanged() {
        quickMinutesIsParentSet = false
        // D-019 / D-058 — a RUNNING session has to obey the new budget too, not just the next one.
        // The child's timer screen has always done this; the dashboard only reloaded, so a parent
        // who set three minutes mid-session went back to a card still counting down from thirty.
        // Same event, same answer, wherever you are standing.
        _ = try? controller.applyConfigurationChange()
        reload()
        // Re-derived windows move the end, so every wall-clock alarm moves with them (D-047).
        enforce()
    }

    private func refreshSession() {
        session = (try? controller.tick()) ?? .idle
        remainingTodaySeconds = (try? controller.remainingBudgetSeconds()) ?? 0
    }

    // MARK: Parent actions

    /// Task 004 / QA-02 — ask for Family Controls access. Every failure ends somewhere the parent
    /// can act: a message that names the fix, never a dead end.
    func requestAuthorization() {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        authorizationError = nil
        Task {
            defer { isRequestingAuthorization = false }
            do {
                authorization = try await services.authorization.requestAuthorization()
            } catch ScreenTimeAuthorizationError.denied {
                authorization = await services.authorization.status
                authorizationError = nil      // the row already explains a decline and offers Settings
            } catch ScreenTimeAuthorizationError.entitlementUnavailable {
                authorization = await services.authorization.status
                authorizationError = "Screen Time access isn't available in this build."
            } catch let ScreenTimeAuthorizationError.unknown(message) {
                authorization = await services.authorization.status
                authorizationError = message
            } catch {
                authorization = await services.authorization.status
                authorizationError = "Something went wrong. Please try again."
            }
        }
    }


    /// D-034 — one minute per press, like every other dial in the app.
    func adjustQuickMinutes(_ direction: Int) {
        let range = ScreenTimeConfiguration.budgetRangeSeconds
        let step = ScreenTimeConfiguration.budgetStepSeconds / 60
        quickMinutes = min(max(quickMinutes + direction * step, range.lowerBound / 60), range.upperBound / 60)
        quickMinutesIsParentSet = true
    }

    /// D-016 — set today's budget from the hero and open a session in one action.
    // MARK: D-060 — what a parent should be told BEFORE the timer starts

    /// D-061 — the copy and the cases live in `StartWarning.swift`, because onboarding needs the
    /// same warning and a second copy of these words would drift within a week.
    var startWarning: StartWarning? {
        if restrictionsAreCleared { return .restrictionsCleared }
        if selectionSummary.isEmpty { return .nothingCovered }
        return nil
    }

    /// Put the restrictions back, then start — the "yes, I forgot" path.
    func restoreRestrictionsAndStart() {
        setRestrictionsCleared(false)
        startSession()
    }

    func startSession() {
        // Only the budget changes here — everything else the parent has arranged (reminders,
        // activities, saved sets, typed websites) is carried across untouched (D-024/D-035).
        var config = configuration
        config.dailyBudgetSeconds = quickMinutes * 60
        try? services.storage.save(config)
        // The number is the saved budget again, so a later reload has nothing to override.
        quickMinutesIsParentSet = false
        _ = try? controller.start()
        // A new session means time again, so anything left shielded from the last one comes down.
        enforce()
        reload()
    }

    func endSession() {
        _ = try? controller.endEarly()
        // D-042 — ending a round is not ending the day. If budget remains this leaves the device
        // open, which is what "End" means; if the budget is gone it shields, same as any other way
        // of reaching zero. One rule, no special case.
        enforce()
        refreshSession()
    }

    /// D-052 — add or take back minutes. Adding counts from now when the session has already run
    /// out, which is the only way "+3" can mean three minutes to a child.
    func adjust(minutes: Int) {
        guard minutes != 0, (try? controller.adjust(bySeconds: minutes * 60)) != nil else { return }
        // The extension gave the budget back, so the shield comes down on the ordinary rule rather
        // than by being told to. `temporarilyExtended` is written after, because it is a note about
        // HOW the device came to be unshielded, not a second opinion about whether it is.
        enforce()
        try? services.storage.save(ProtectionState.temporarilyExtended)
        reload()
    }

    /// Task 012 — one rule, one place (`Enforcement`). Every parent action that can change how much
    /// time is left ends here.
    ///
    /// D-047 — and tells the coordinator, because the same actions move every wall-clock alarm:
    /// a session that now ends ten minutes later needs its reminders ten minutes later too.
    // MARK: D-052 / D-053 — the restriction slide

    /// Clear every restriction for the rest of today, or put them back exactly as they were.
    ///
    /// "Put them back" needs nothing stored: the restriction is the parent's CURRENT selection,
    /// which `Enforcement.reconcile` re-reads every time. So sliding back always restores the
    /// latest set, not a snapshot of whatever was in force when it was cleared — which is what a
    /// parent who edited their apps in between would expect.
    func setRestrictionsCleared(_ cleared: Bool) {
        guard var preferences = try? services.storage.loadPickerPreferences() else { return }
        preferences.restrictionsClearedOn = cleared ? Date() : nil
        try? services.storage.save(preferences)
        restrictionsAreCleared = cleared
        enforce()
    }

    private func enforce() {
        Enforcement.reconcile(storage: services.storage,
                              selection: services.selection,
                              shield: services.shield)
        NotificationCenter.default.post(name: .sessionDidChange, object: nil)
    }

    var canExtend: Bool { session.window != nil }

    // MARK: D-053 — what's next, SHOWN here and chosen in Settings

    /// What the child will actually be offered, in the order they will see it.
    ///
    /// D-053 — the dashboard shows this and no longer edits it. Ticking boxes is configuration a
    /// parent does once; putting it on the screen they open every evening made the dashboard read
    /// like a settings page, and put a tappable control next to the ring where a mis-tap costs
    /// something. Which activities are offered is back in Settings, beside the list they belong to.
    ///
    /// Empty picks mean "no preference", which offers everything (D-009) — so that is what is
    /// shown, rather than an empty row that looks like a mistake.
    var offeredActivities: [TransitionActivity] {
        let picked = configuration.selectedActivities
        guard picked.isEmpty else { return picked }
        return ((try? services.storage.loadPickerPreferences()) ?? .default).allActivities
    }

    /// D-057 — the dashboard shows THESE and nothing else.
    ///
    /// A system shield fits three (D-044) and takes them off the front of the list. Showing the
    /// whole list here and marking three of them was a list a parent had to read carefully to
    /// learn one fact. Three rows say the same thing by being the only three rows.
    var shieldActivities: [TransitionActivity] {
        Array(offeredActivities.prefix(ShieldMomentResolver.maxChooserOptions))
    }

    /// How many more are in the list but cannot fit on the shield.
    var activitiesBeyondTheShield: Int {
        max(0, offeredActivities.count - ShieldMomentResolver.maxChooserOptions)
    }

    /// True when the parent has picked none, so the list above is a default rather than a choice.
    var offersEverything: Bool { configuration.selectedActivities.isEmpty }

    /// D-044 — a system shield can show at most three. Which three is worth saying out loud,
    /// because reordering in Settings is the only way to change it.
    var shieldChoiceCount: Int { min(ShieldMomentResolver.maxChooserOptions, offeredActivities.count) }

    /// D-052 — only once the budget is gone. While a session runs nothing is shielded, so there is
    /// nothing for this to release.
    var canClearRestrictions: Bool { restrictionsAreCleared || remainingTodaySeconds == 0 }

    // MARK: Presentation helpers

    var sessionStatusText: String {
        switch session.state {
        case .idle:      return "Not started"
        case .active:    return "In progress"
        case .extended:  return "Extended"
        case .firstWarning, .secondWarning, .finalWarning:
            if let m = session.activeWarningMinutes { return "\(m)-minute reminder" }
            return "Reminder"
        case .finished:  return "Finished"
        }
    }

    /// Remaining ÷ budget for the hero ring (0…1). During a session, the live window counts.
    var remainingFraction: Double {
        let budget = max(1, configuration.dailyBudgetSeconds)
        let shown = session.window != nil ? session.remainingSeconds : remainingTodaySeconds
        return min(1, Double(shown) / Double(budget))
    }

    var sessionIsRunning: Bool { session.window != nil && session.state != .finished }

    var authorizationText: String {
        switch authorization {
        case .notDetermined: return "Not requested"
        case .approved:      return "Allowed"
        case .denied:        return "Declined"
        case .revoked:       return "Turned off in Settings"
        }
    }

    var protectionText: String {
        switch protectionState {
        case .unshielded:          return "Not shielded"
        case .shielded:            return "Shielded"
        case .temporarilyExtended: return "Extended by parent"
        }
    }
}
