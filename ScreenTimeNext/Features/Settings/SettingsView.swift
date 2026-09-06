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
    @State private var showActivityEditor = false
    @State private var editingActivity: TransitionActivity?

    private var allActivities: [TransitionActivity] { TransitionActivity.allCases + customActivities }
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
                Text("Your child is asked what to do next at the second-to-last reminder. Up to three, each shorter than the budget (up to \(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: budgetMinutes * 60) / 60) min). Off skips that reminder. A finish notification is always sent.")
            }

            Section {
                ForEach(allActivities) { activity in
                    activityRow(activity)
                }
                Button { editingActivity = nil; showActivityEditor = true } label: {
                    Label("Add your own", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.mint)
                }
            } header: {
                Text("What's next")
            } footer: {
                // D-029 — "all eight" stopped being true the moment a parent could add a ninth.
                Text(activities.isEmpty
                     ? "None picked — everything here will be offered."
                     : "\(activities.count) picked. Swipe a custom one to edit or delete it.")
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
                        picker.clear()
                        picker.applyRealSelection(nil)      // D-027 — clears the stored one too
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
        .sheet(isPresented: $showActivityEditor) {
            ActivityEditorSheet(existing: editingActivity) { saved in
                if let index = customActivities.firstIndex(of: saved) {
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
        // Only the family's own activities can be changed or removed; the built-in eight are ours.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if activity.isCustom {
                Button(role: .destructive) { remove(activity) } label: { Label("Delete", systemImage: "trash") }
                Button { editingActivity = activity; showActivityEditor = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(Theme.sky)
            }
        }
    }

    private func remove(_ activity: TransitionActivity) {
        customActivities.removeAll { $0 == activity }
        activities.remove(activity)
        persistCustomActivities()
    }

    /// D-029 — written straight away, the D-022 rule: a parent who adds an activity and leaves
    /// should not lose it because they did not also press Save.
    private func persistCustomActivities() {
        guard var preferences = try? services.storage.loadPickerPreferences() else { return }
        preferences.customActivities = customActivities
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
        customActivities = (try? services.storage.loadPickerPreferences())?.customActivities ?? []
        selection = try? services.selection.loadSelection()
        // Only on first appear: coming back from the picker must not undo what was just arranged.
        if !pickerLoaded {
            // D-022 — autosaving: "Save as my usual" and a drag write themselves immediately here,
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
            selectedActivities: allActivities.filter { activities.contains($0) },
            selectedCategories: picker.order.filter { picker.categories.contains($0) }
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
