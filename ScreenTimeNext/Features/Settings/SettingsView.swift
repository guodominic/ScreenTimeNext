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
    @State private var existingProfileID: UUID?
    @State private var errorText: String?

    var body: some View {
        Form {
            Section("Child") {
                TextField("First name", text: $childName)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
            }

            Section {
                HStack {
                    Spacer()
                    MinuteDial(minutes: $budgetMinutes, range: 2...120, step: 2, color: Theme.mint, size: 200)
                    Spacer()
                }
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
                Text("Up to three, each shorter than the budget (up to \(ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: budgetMinutes * 60) / 60) min). Off skips that reminder. A finish notification is always sent.")
            }

            Section {
                ForEach(TransitionActivity.allCases) { activity in
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
        .onAppear(perform: load)
        .onChange(of: budgetMinutes) { _, newBudget in
            let cap = ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: newBudget * 60) / 60
            warningMinutes = warningMinutes.map { min($0, cap) }
        }
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
        selection = try? services.selection.loadSelection()
    }

    private func save() {
        let name = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = ChildProfile(id: existingProfileID ?? UUID(), name: name)
        let config = ScreenTimeConfiguration(
            dailyBudgetSeconds: budgetMinutes * 60,
            warningOffsetsSeconds: warningMinutes.map { $0 * 60 },
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
        SettingsView(services: .mocks(), onSaved: {})
    }
}
