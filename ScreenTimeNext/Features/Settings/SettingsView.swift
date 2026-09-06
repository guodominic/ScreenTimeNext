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
    @State private var budgetMinutes = ScreenTimeConfiguration.defaultBudgetSeconds / 60
    @State private var warningMinutes: [Int] = [10, 5, 1]
    @State private var activities: Set<TransitionActivity> = []
    @State private var selection: SelectionSnapshot?
    @State private var picker = ContentPickerModel()
    @State private var pickerLoaded = false
    @State private var screenTimeApproved = false
    @State private var customActivities: [TransitionActivity] = []
    /// D-039 — built-ins the parent removed. Hidden, not deleted: they are `static let`s in code,
    /// and a family that drops "Bath" and wants it back should not have to retype it.
    @State private var hiddenActivityIDs: [String] = []
    @State private var showActivityEditor = false
    @State private var editingActivity: TransitionActivity?
    @State private var parentPIN: ParentPIN?
    @State private var showPINEditor = false
    @State private var activityOrder: [String] = []
    @State private var isReorderingActivities = false

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
                Text("Only used to greet your child by name. It stays on this device, and the app works fine without it.")
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
                if parentPIN != nil {
                    Button("Turn the PIN off", role: .destructive) { setPIN(nil) }
                }
            } header: {
                Text("Parent gate")
            }

            Section {
                // D-020 — the same dial as setup: 1–120, one-minute steps under fifteen.
                MinuteDial.budget($budgetMinutes, color: Theme.mint, baseSize: 200)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } header: {
                Text("Daily budget")
            } footer: {
                Text("Changes apply from the next session.")
            }

            Section {
                WarningDials(minutes: $warningMinutes, budgetMinutes: budgetMinutes)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Reminders (minutes before the end)")
            } footer: {
                Text("Two reminders, each a full-screen message inside whatever app your child is using. The first is a heads-up; the second asks them to pick what's next. Each must be shorter than the budget (up to \(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: budgetMinutes * 60) / 60) min); Off skips it. The end always interrupts, and is not a dial.")
            }

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
                // D-039 — only offered once something is missing, and it is the whole reason a
                // removed built-in is hidden rather than gone.
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
                // D-029 — "all eight" stopped being true the moment a parent could add a ninth.
                Text(activities.isEmpty
                     ? "None picked — everything here will be offered. Swipe any row to rename or remove it; Reorder to arrange them."
                     : "\(activities.count) picked. Swipe any row to rename or remove it; Reorder to arrange them.")
            }

            Section {
                if let summary = (picker.realSelection ?? selection)?.summary, !summary.isEmpty {
                    SelectionSummaryView(summary: summary)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                NavigationLink {
                    ContentPickerScreen(model: picker,
                                        screenTimeAccessAvailable: screenTimeApproved) { selection = $0 }
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
                    customActivities.append(saved)
                    activities.insert(saved)                 // a parent who adds one means to use it
                }
                persistCustomActivities()
            }
        }
        .onAppear(perform: load)
        .task { screenTimeApproved = await services.authorization.status == .approved }
        .onChange(of: budgetMinutes) { _, newBudget in
            // A shorter budget can invalidate every reminder at once — re-clamp the whole set
            // rather than each dial on its own, so the descending rule survives (D-019).
            let cap = ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: newBudget * 60) / 60
            warningMinutes = ScreenTimeConfiguration.clampedDescendingMinutes(warningMinutes, capMinutes: cap)
        }
    }

    @ViewBuilder
    private func activityRow(_ activity: TransitionActivity) -> some View {
        Button {
            if activities.contains(activity) { activities.remove(activity) } else { activities.insert(activity) }
        } label: {
            HStack {
                Label(activity.displayName, systemImage: activity.symbolName)
                    .foregroundStyle(Theme.color(for: activity))
                    .fontWeight(.medium)
                Spacer()
                if activities.contains(activity) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.color(for: activity))
                }
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
        activities.remove(activity)
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
        if activities.contains(builtIn) {
            activities.remove(builtIn)
            activities.insert(replacement)
        }
        hiddenActivityIDs.append(builtIn.id)
        persistCustomActivities()
    }

    /// D-029 — written straight away, the D-022 rule: a parent who adds an activity and leaves
    /// should not lose it because they did not also press Save.
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
        budgetMinutes = config.dailyBudgetSeconds / 60
        var mins = config.warningOffsetsSeconds.map { $0 / 60 }
        while mins.count < ScreenTimeConfiguration.maxWarnings { mins.append(0) }
        warningMinutes = mins
        activities = Set(config.selectedActivities)
        let preferences = (try? services.storage.loadPickerPreferences()) ?? .default
        customActivities = preferences.customActivities
        hiddenActivityIDs = preferences.hiddenActivityIDs
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
        let config = ScreenTimeConfiguration(
            dailyBudgetSeconds: budgetMinutes * 60,
            warningOffsetsSeconds: warningMinutes.map { min($0 * 60, ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: budgetMinutes * 60)) },
            selectedActivities: allActivities.filter { activities.contains($0) }
        )
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
