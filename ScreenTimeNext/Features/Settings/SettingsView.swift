//  SettingsView.swift
//  ScreenTimeNext
//
//  Task 014 / D-013 — parent settings after onboarding: name, budget dial, reminder dials,
//  activities, protected content (mocked in Phase 0). "Start over" lives on the dashboard.

import SwiftUI
import ScreenTimeNextCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let services: ServiceContainer
    let onSaved: () -> Void

    @State private var childName = ""
    /// D-072 — the parent's own answer to "what's next", or nil while the child still decides.
    /// One, not a set: see the note on `ScreenTimeConfiguration.parentChosenActivity`.
    @State private var parentChoice: TransitionActivity?
    @State private var selection: SelectionSnapshot?
    @State private var picker = ContentPickerModel()
    @State private var pickerLoaded = false
    @State private var screenTimeApproved = false
    @State private var isRequestingAccess = false
    @State private var screenTimeDenied = false
    /// D-068 — chosen now, honoured when the translation lands.
    @State private var languageCode = ParentPickerPreferences.defaultLanguageCode
    @State private var customActivities: [TransitionActivity] = []
    /// D-039 — built-ins the parent removed. Hidden, not deleted: they are `static let`s in code,
    /// and a family that drops "Bath" and wants it back should not have to retype it.
    @State private var hiddenActivityIDs: [String] = []
    /// D-045 — the Face ID shortcut, and what this device can actually offer.
    @State private var usesBiometrics = false
    @State private var biometricKind: BiometricKind = .none
    @State private var showActivityEditor = false
    @State private var editingActivity: TransitionActivity?
    @State private var parentPIN: ParentPIN?
    @State private var showPINEditor = false
    @State private var activityOrder: [String] = []
    @State private var isReorderingActivities = false
    /// D-054 — the enforcement log, read on appear and on demand.
    @State private var journal: [MonitorReport] = []
    @State private var showJournal = false

    /// D-033 — the parent's own order, built by the same rule as the category list: their
    /// arrangement first, anything it has never heard of appended, so a stale order cannot hide a
    /// row.
    private var activityPreferences: ParentPickerPreferences {
        ParentPickerPreferences(customActivities: customActivities,
                                activityOrder: activityOrder,
                                hiddenActivityIDs: hiddenActivityIDs)
    }

    private var orderedActivities: [TransitionActivity] { activityPreferences.allActivities }
    private var allActivities: [TransitionActivity] { orderedActivities }
    @State private var existingProfileID: UUID?
    @State private var errorText: String?

    var body: some View {
        Form {
            Section {
                TextField("First name (optional)", text: $childName)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
            } header: {
                Text("Child")
            } footer: {
                Text("Only used to greet them. Optional.")
            }

            Section {
                // D-031 — first in Settings, because a parent who never sets one has no gate at
                // all, and the thing behind the gate hands out more screen time.
                Button { showPINEditor = true } label: {
                    HStack(spacing: 12) {
                        IconChip(symbol: parentPIN == nil ? "lock.open.fill" : "lock.fill",
                                 color: parentPIN == nil ? .orange : Theme.grass)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parentPIN == nil ? "Set a parent PIN" : "Change parent PIN")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.primary)
                            Text(parentPIN == nil
                                 ? "Without one, holding “Parents” is all it takes to leave the timer."
                                 : "Needed to leave the timer and open settings.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                // D-045 — offered only once a PIN exists, because this is a shortcut PAST the
                // PIN, not an alternative to it.
                if parentPIN != nil, biometricKind != .none {
                    Toggle(isOn: $usesBiometrics) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use \(biometricKind.displayName) instead of typing")
                                .fontWeight(.semibold)
                            // The whole decision, in the place where it is made. A parent who
                            // reads this and turns it on anyway has made an informed choice; one
                            // who is told nothing has had it made for them.
                            Text("Only if this device recognises YOUR face — not your child's. Your PIN always works.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: usesBiometrics) { _, _ in persistGatePreference() }
                }
                if parentPIN != nil {
                    Button("Turn the PIN off", role: .destructive) { setPIN(nil) }
                }
            } header: {
                Text("Parent gate")
            }

            // D-053 — choosing WHICH activities are offered lives here again. D-052 moved the
            // ticks to the dashboard on the theory that it was a weekly decision; it is not, and a
            // tappable list beside the ring turned the evening screen into a settings page. The
            // dashboard shows the answer; this is where it is decided, beside the same rows a
            // parent renames and reorders.
            Section {
                ForEach(orderedActivities) { activity in
                    activityRow(activity)
                }
                .onMove(perform: moveActivities)
                Button { editingActivity = nil; showActivityEditor = true } label: {
                    Label("Add your own", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.mint)
                }
                .moveDisabled(true)
                if activityPreferences.hasHiddenBuiltIns {
                    Button { restoreBuiltIns() } label: {
                        Label("Bring back the ones I removed", systemImage: "arrow.uturn.backward")
                            .foregroundStyle(Theme.sky)
                    }
                    .moveDisabled(true)
                }
            } header: {
                HStack {
                    Text("What's next")
                    Spacer()
                    Button(isReorderingActivities ? "Done" : "Reorder") { isReorderingActivities.toggle() }
                        .font(.caption.weight(.bold))
                        .textCase(nil)
                }
            } footer: {
                // D-072 — two rules, and the footer says whichever one is currently in force.
                // The ORDER is load-bearing: a system shield shows three (D-044) and takes them
                // off the front of this list. The TICK overrides the whole question.
                Text(parentChoice.map { "\($0.displayName) — your child won't be asked. Cleared when you start a new session." }
                     ?? "The first three reach the transition screen. Tick one to decide for them.")
            }

            Section {
                if let summary = (picker.realSelection ?? selection)?.summary, !summary.isEmpty {
                    SelectionSummaryView(summary: summary)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                NavigationLink {
                    ContentPickerScreen(model: picker,
                                        screenTimeAccessAvailable: screenTimeApproved,
                                        // D-058 — same fix as onboarding: a screen that names a
                                        // prerequisite has to offer the way to meet it.
                                        onRequestAccess: { requestScreenTimeAccess() },
                                        isRequestingAccess: isRequestingAccess,
                                        accessDenied: screenTimeDenied) { selection = $0 }
                } label: {
                    Label(selection == nil ? "Pick apps and categories" : "Change what's covered",
                          systemImage: "square.grid.2x2.fill")
                        .fontWeight(.semibold)
                }
                if selection != nil {
                    Button("Clear selection", role: .destructive) {
                        selection = nil
                        picker.clearAll()                   // D-027 — clears the stored one too
                    }
                }
            } header: {
                Text("Protected content")
            }

            Section {
                Picker("Language", selection: $languageCode) {
                    ForEach(ParentPickerPreferences.supportedLanguages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .onChange(of: languageCode) { _, _ in persistLanguage() }
            } footer: {
                // D-068 — says what is true. A setting that quietly does nothing teaches a parent
                // that settings in this app are decorative, which is a hard thing to un-teach.
                Text("Your choice is saved. The app is still English everywhere — translation is coming.")
            }

            enforcementLogSection

            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .environment(\.editMode, .constant(isReorderingActivities ? .active : .inactive))
        .sheet(isPresented: $showPINEditor) {
            // No biometrics here on purpose: proving who you are to CHANGE the PIN is the one
            // moment the keypad has to be the answer (D-045).
            ParentPINView(mode: parentPIN.map { ParentPINView.Mode.change(existing: $0) } ?? .create) { pin in
                setPIN(pin)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showActivityEditor) {
            ActivityEditorSheet(existing: editingActivity) { saved in
                if let original = editingActivity, !original.isCustom {
                    replaceBuiltIn(original, with: saved)    // D-039 — see the note on that method
                } else if let index = customActivities.firstIndex(of: saved) {
                    customActivities[index] = saved          // same id — a rename, not a new one
                } else {
                    // D-072 — added, not decided. Adding an activity puts it on the list; it does
                    // not announce that tonight is that activity.
                    customActivities.append(saved)
                }
                persistCustomActivities()
            }
        }
        .onAppear(perform: load)
        .task {
            let status = await services.authorization.status
            screenTimeApproved = status == .approved
            screenTimeDenied = status == .denied
        }
        .task { biometricKind = await services.unlock.available }
    }

    /// D-054 — what the invisible processes actually did, in order.
    ///
    /// D-052 deleted this from the dashboard, and that was right — a parent has no use for it. But
    /// deleting it outright was wrong: the monitor, the shield's configuration and the shield's
    /// action all run in their own processes with no console, no breakpoint and no way to ask them
    /// anything afterwards. `MonitorJournal` is the only evidence that exists about them, and the
    /// first time a shield misbehaved after the panel was gone the answer was unreachable.
    ///
    /// So it lives here instead: collapsed by default, out of a parent's way, one tap from mine.
    /// The three `shieldShown…` lines are the ones that matter — they say which of the three
    /// screens the child was actually given, which is otherwise a claim rather than a fact. A line
    /// missing entirely means iOS never asked us and drew its own "Restricted" screen.
    private var enforcementLogSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showJournal) {
                if journal.isEmpty {
                    Text("Nothing recorded yet.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    // Newest first: the question is always "what just happened?".
                    ForEach(Array(journal.reversed().enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(Self.describe(entry.event))
                                    .font(.caption.weight(.semibold))
                                Text(Self.shortName(entry.activity))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(entry.at, format: .dateTime.hour().minute().second())
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    Button("Clear the log", role: .destructive) {
                        MonitorJournal()?.clear()
                        journal = []
                    }
                    .font(.caption)
                }
            } label: {
                Label("Enforcement log", systemImage: "stethoscope")
                    .font(.subheadline.weight(.semibold))
            }
            .onChange(of: showJournal) { _, open in if open { journal = MonitorJournal()?.entries() ?? [] } }
        } footer: {
            Text("What the background processes did. Nothing here leaves the device.")
        }
    }

    private static func describe(_ event: MonitorReport.Event) -> String {
        switch event {
        case .intervalDidStart:         return "A new day's window opened"
        case .intervalDidEnd:           return "Alarm interval ended"
        case .thresholdReached:         return "Budget spent / time's up"
        case .warningBeforeIntervalEnds: return "System warning before an interval ended"
        case .warningBeforeThreshold:   return "Reminder alarm — shield raised"
        case .shieldShownReminder:      return "Child saw: minutes left"
        case .shieldShownChooser:       return "Child saw: pick what's next"
        case .shieldShownFinished:      return "Child saw: screen time finished"
        case .shieldShownSpent:         return "Child saw: today's time is gone"
        case .shieldExtensionEntered:   return "iOS asked us for a shield screen"
        case .staleAlarmIgnored:        return "Stale alarm ignored — clock had moved"
        case .shieldNotRaisedNothingCovered:
            return "NO SHIELD — nothing is covered"
        }
    }

    /// The activity names are ours and long; the tail is the part that identifies the moment.
    private static func shortName(_ activity: String) -> String {
        activity.replacingOccurrences(of: "screentimenext.", with: "")
    }

    @ViewBuilder
    /// D-072 — the tick is a DECISION now, not a permission.
    ///
    /// It used to mean "this one is offered", which is what the order already means. It now means
    /// "this is what's happening after screen time", one activity at most, and a parent who sets
    /// it has taken the question away from their child deliberately. Tapping the ticked row again
    /// gives it back — without that there is no way to undo a decision, and a parent should never
    /// have to reinstall an app to change their mind.
    ///
    /// Swiping still renames or removes. Two verbs on one row is fine: the gestures differ.
    private func activityRow(_ activity: TransitionActivity) -> some View {
        let isChosen = parentChoice == activity
        HStack {
            Label(activity.displayName, systemImage: activity.symbolName)
                .foregroundStyle(Theme.color(for: activity))
                .fontWeight(.medium)
            Spacer()
            Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isChosen ? Theme.color(for: activity) : Color.secondary.opacity(0.4))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.18)) {
                parentChoice = isChosen ? nil : activity
            }
        }
        // D-039 — every row, ours included. "What my child does after screen time" is the one
        // list in this app that belongs to the family; a built-in called "Bath" is a suggestion,
        // not a fact about their evening. Removal stops one short of empty: a chooser with nothing
        // in it is not a configuration, it is a broken §6.11.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if activityPreferences.canRemoveActivity(activity.id) {
                Button(role: .destructive) { remove(activity) } label: { Label("Remove", systemImage: "trash") }
            }
            Button { editingActivity = activity; showActivityEditor = true } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(Theme.sky)
        }
    }

    /// D-022 — written the moment it is tapped, like every other preference on this screen.
    private func persistLanguage() {
        guard var preferences = try? services.storage.loadPickerPreferences() else { return }
        preferences.languageCode = languageCode
        try? services.storage.save(preferences)
    }

    /// D-058 — ask iOS for Screen Time access from here, so a parent who reaches the picker
    /// through Settings is not stuck the same way onboarding left them.
    private func requestScreenTimeAccess() {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        Task {
            defer { isRequestingAccess = false }
            _ = try? await services.authorization.requestAuthorization()
            let status = await services.authorization.status
            screenTimeApproved = status == .approved
            screenTimeDenied = status == .denied
        }
    }

    /// D-031 / D-022 — written immediately. A PIN that only takes effect after pressing Save is a
    /// gate a parent thinks they set and did not.
    private func setPIN(_ pin: ParentPIN?) {
        parentPIN = pin
        try? services.storage.save(pin)
    }

    private func moveActivities(from source: IndexSet, to destination: Int) {
        var ids = orderedActivities.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        activityOrder = ids
        persistCustomActivities()
    }

    /// D-039 — a custom activity is deleted; a built-in is hidden, so "Bring back the ones I
    /// removed" can undo it.
    private func remove(_ activity: TransitionActivity) {
        guard activityPreferences.canRemoveActivity(activity.id) else { return }
        if activity.isCustom {
            customActivities.removeAll { $0 == activity }
        } else {
            hiddenActivityIDs.append(activity.id)
        }
        if parentChoice == activity { parentChoice = nil }
        activityOrder.removeAll { $0 == activity.id }
        persistCustomActivities()
    }

    private func restoreBuiltIns() {
        let builtInIDs = Set(TransitionActivity.allCases.map(\.id))
        hiddenActivityIDs.removeAll { builtInIDs.contains($0) }
        persistCustomActivities()
    }

    /// D-039 — renaming a BUILT-IN makes a new activity of the family's own and hides ours, rather
    /// than editing ours in place. A built-in is re-resolved from its id on every decode (so that
    /// improving its wording reaches families who already have it), which would quietly undo the
    /// rename on the next launch. A real custom activity has an id nothing else owns, so the new
    /// name is the family's for good — and it lands where the old row was, not at the bottom.
    private func replaceBuiltIn(_ builtIn: TransitionActivity, with renamed: TransitionActivity) {
        let replacement = TransitionActivity.custom(displayName: renamed.displayName,
                                                    symbolName: renamed.symbolName)
        customActivities.append(replacement)
        if let slot = orderedActivities.firstIndex(of: builtIn) {
            var ids = orderedActivities.map(\.id)
            ids[slot] = replacement.id
            activityOrder = ids
        }
        if parentChoice == builtIn { parentChoice = replacement }
        hiddenActivityIDs.append(builtIn.id)
        persistCustomActivities()
    }

    /// D-029 — written straight away, the D-022 rule: a parent who adds an activity and leaves
    /// should not lose it because they did not also press Save.
    /// D-045 / D-022 — written the moment the switch moves. A gate setting that waits for a Save
    /// button is a gate a parent thinks they changed and did not.
    private func persistGatePreference() {
        guard var preferences = try? services.storage.loadPickerPreferences() else { return }
        preferences.gate = ParentGatePreference(usesBiometrics: usesBiometrics)
        try? services.storage.save(preferences)
    }

    private func persistCustomActivities() {
        guard var preferences = try? services.storage.loadPickerPreferences() else { return }
        preferences.customActivities = customActivities
        preferences.activityOrder = activityOrder
        preferences.hiddenActivityIDs = hiddenActivityIDs
        try? services.storage.save(preferences)
    }

    // MARK: Load / save

    private func load() {
        let storage = services.storage
        if let profile = try? storage.loadChildProfile() {
            childName = profile.name
            existingProfileID = profile.id
        }
        let config = (try? storage.loadConfiguration()) ?? .default
        parentChoice = config.parentChosenActivity
        let preferences = (try? services.storage.loadPickerPreferences()) ?? .default
        customActivities = preferences.customActivities
        hiddenActivityIDs = preferences.hiddenActivityIDs
        usesBiometrics = preferences.gate.usesBiometrics
        languageCode = preferences.languageCode
        activityOrder = preferences.activityOrder
        parentPIN = try? services.storage.loadParentPIN()
        selection = try? services.selection.loadSelection()
        // Only on first appear: coming back from the picker must not undo what was just arranged.
        if !pickerLoaded {
            // D-022 — autosaving: a typed website and a saved set write themselves immediately here,
            // rather than waiting for this screen's own Save button.
            picker = ContentPickerModel.loaded(from: services.storage,
                                               selection: services.selection,
                                               autosaving: true)
            pickerLoaded = true
        }
    }

    private func save() {
        let name = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = ChildProfile(id: existingProfileID ?? UUID(), name: name)   // empty name is fine (D-016)
        // D-066 — Settings no longer sets the time.
        //
        // The budget is dialled on the dashboard, where a parent is already standing when they
        // decide how long; a second dial two screens away could only disagree with the first, and
        // for a while it did (D-057). The reminders follow from the budget — a heads-up and the one
        // that asks — so they are derived rather than dialled, and the screen that had two dials
        // for numbers most parents never touched now has none.
        //
        // Load-and-amend, not construct: whatever the clock is doing right now must survive
        // pressing Save on a screen that has nothing to say about it.
        var config = (try? services.storage.loadConfiguration()) ?? .default
        config.parentChosenActivity = parentChoice
        do {
            try services.storage.save(profile)
            try services.storage.save(config)
            // D-024/D-029 — merged, so saving this screen cannot delete the custom activities or
            // saved selections the picker screen owns.
            try services.storage.save(picker.preferences(mergedInto: try? services.storage.loadPickerPreferences()))
            // D-027 — a real selection has already been written by the picker itself. Re-saving
            // this screen's older copy of it would undo the parent's most recent choice, so the
            // real one wins and only a Phase 0 placeholder is written from here.
            if picker.realSelection == nil {
                if let selection {
                    try services.selection.save(selection)
                } else {
                    try services.selection.clearSelection()
                }
            }
            // D-019 — a running session must obey the new settings, not just the next one.
            // This re-derives the window's end from the new daily budget and reschedules
            // everything from it; `rescheduleNotifications` alone could not move the end.
            _ = try? services.makeSessionController().applyConfigurationChange()
            NotificationCenter.default.post(name: .configurationDidChange, object: nil)
            errorText = nil
            onSaved()
            dismiss()
        } catch {
            errorText = "Couldn't save. Please try again."
        }
    }
}

/// Three small dials: reminders, in minutes before the end. 0 = off.
///
/// D-019 — reminder 1 fires before reminder 2 fires before reminder 3, so their minutes must
/// strictly DESCEND (10 / 5 / 1). Two things enforce that, and between them an illegal state is
/// unreachable rather than quietly corrected afterwards:
///   · each dial's range stops one minute short of the dial before it, so it physically cannot be
///     dragged past its neighbour;
///   · moving a dial pushes the ones after it down (`clampedDescendingMinutes`), so lowering
///     reminder 1 to 4 drags 5 and 2 along instead of leaving 4 / 5 / 2 on screen.
/// A dial set to 0 (off) turns off every later one — "reminder 3" with no reminder 2 is a lie.
struct WarningDials: View {
    @Binding var minutes: [Int]
    let budgetMinutes: Int

    private let colors = [Theme.sun, Theme.peach, Theme.coral]

    private var capMinutes: Int {
        ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: budgetMinutes * 60) / 60
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(0..<ScreenTimeConfiguration.maxWarnings, id: \.self) { i in
                    MinuteDial.reminder(slot(i),
                                        upperBound: upperBound(i),
                                        title: "Reminder \(i + 1)",
                                        color: colors[i])
                        .disabled(upperBound(i) == 0)
                        .opacity(upperBound(i) == 0 ? 0.4 : 1)
                }
            }
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var summary: String {
        let on = current.filter { $0 > 0 }
        guard !on.isEmpty else { return "No reminders — only the finish." }
        return on.map { "\($0) min" }.joined(separator: " → ") + " → finish"
    }

    private var current: [Int] {
        var m = minutes
        while m.count < ScreenTimeConfiguration.maxWarnings { m.append(0) }
        return m
    }

    private func upperBound(_ i: Int) -> Int {
        ScreenTimeConfiguration.warningDialUpperBound(index: i, minutes: current, capMinutes: capMinutes)
    }

    private func slot(_ i: Int) -> Binding<Int> {
        Binding(
            get: { current[i] },
            set: { newValue in
                var m = current
                m[i] = newValue
                minutes = ScreenTimeConfiguration.clampedDescendingMinutes(m,
                                                                          capMinutes: capMinutes,
                                                                          changedIndex: i)
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView(services: .mocks(), onSaved: {})
    }
}
