//  SettingsView.swift
//  ScreenTimeNext
//
//  Task 014 — parent settings after onboarding: name, budget (§6.5 presets), warnings (§6.6),
//  activities (§6.7), protected content (§6.4, mocked in Phase 0), and "start over".
//  Edits are held locally and written on Save, through the same protocols onboarding used.

import SwiftUI
import ScreenTimeNextCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let services: ServiceContainer
    let onSaved: () -> Void
    let onReset: () -> Void

    @State private var childName = ""
    @State private var budgetSeconds = ScreenTimeConfiguration.defaultBudgetSeconds
    @State private var warning10 = true
    @State private var warning5 = true
    @State private var warning1 = true
    @State private var activities: Set<TransitionActivity> = []
    @State private var selection: SelectionSnapshot?
    @State private var existingProfileID: UUID?
    @State private var confirmReset = false
    @State private var errorText: String?

    var body: some View {
        Form {
            Section("Child") {
                TextField("First name", text: $childName)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
            }

            Section {
                Picker("Daily budget", selection: $budgetSeconds) {
                    ForEach(ScreenTimeConfiguration.budgetPresetsSeconds, id: \.self) { seconds in
                        Text("\(seconds / 60) minutes").tag(seconds)
                    }
                }
            } footer: {
                Text("Changes apply from the next session.")
            }

            Section("Gentle warnings") {
                Toggle("10 minutes left", isOn: $warning10)
                Toggle("5 minutes left", isOn: $warning5)
                Toggle("1 minute left", isOn: $warning1)
            }

            Section {
                ForEach(TransitionActivity.allCases) { activity in
                    Button {
                        if activities.contains(activity) { activities.remove(activity) } else { activities.insert(activity) }
                    } label: {
                        HStack {
                            Label(activity.displayName, systemImage: activity.symbolName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if activities.contains(activity) {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("What's next")
            } footer: {
                Text(activities.isEmpty ? "None picked — all eight will be offered." : "\(activities.count) picked.")
            }

            Section {
                if let summary = selection?.summary, !summary.isEmpty {
                    SelectionSummaryView(summary: summary)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    Button("Clear selection", role: .destructive) { selection = nil }
                } else {
                    SelectionPickerButton { selection = $0 }
                }
            } header: {
                Text("Protected content")
            }

            Section {
                Button("Start over", role: .destructive) { confirmReset = true }
            } footer: {
                Text("Erases the child profile and all settings on this device.")
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
                    .disabled(childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("Start over?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase and start over", role: .destructive) { onReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear(perform: load)
    }

    // MARK: Load / save

    private func load() {
        let storage = services.storage
        if let profile = try? storage.loadChildProfile() {
            childName = profile.name
            existingProfileID = profile.id
        }
        let config = (try? storage.loadConfiguration()) ?? .default
        budgetSeconds = config.dailyBudgetSeconds
        warning10 = config.warning10Enabled
        warning5 = config.warning5Enabled
        warning1 = config.warning1Enabled
        activities = Set(config.selectedActivities)
        selection = try? services.selection.loadSelection()
    }

    private func save() {
        let name = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = ChildProfile(id: existingProfileID ?? UUID(), name: name)
        let config = ScreenTimeConfiguration(
            dailyBudgetSeconds: budgetSeconds,
            warning10Enabled: warning10,
            warning5Enabled: warning5,
            warning1Enabled: warning1,
            selectedActivities: TransitionActivity.allCases.filter { activities.contains($0) }
        )
        do {
            try services.storage.save(profile)
            try services.storage.save(config)
            if let selection {
                try services.selection.save(selection)
            } else {
                try services.selection.clearSelection()
            }
            try? services.makeSessionController().rescheduleNotifications()
            errorText = nil
            onSaved()
            dismiss()
        } catch {
            errorText = "Couldn't save. Please try again."
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(services: .mocks(), onSaved: {}, onReset: {})
    }
}
