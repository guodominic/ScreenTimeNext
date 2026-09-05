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
                MinuteDial(minutes: $budgetMinutes, range: 2...120, step: 2, color: Theme.mint, baseSize: 200)
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
        let profile = ChildProfile(id: existingProfileID ?? UUID(), name: name)   // empty name is fine (D-016)
        let config = ScreenTimeConfiguration(
            dailyBudgetSeconds: budgetMinutes * 60,
            warningOffsetsSeconds: warningMinutes.map { min($0 * 60, ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: budgetMinutes * 60)) },
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

/// Three small dials: reminders, in minutes before the end. 0 = off. Bounded by the budget —
/// a reminder must be strictly shorter than the window it runs in (D-013).
struct WarningDials: View {
    @Binding var minutes: [Int]
    let budgetMinutes: Int

    private let colors = [Theme.sun, Theme.peach, Theme.coral]

    private var upperBound: Int {
        ScreenTimeConfiguration.maxWarningOffset(forBudgetSeconds: budgetMinutes * 60) / 60
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<ScreenTimeConfiguration.maxWarnings, id: \.self) { i in
                MinuteDial(minutes: slot(i),
                           range: 0...upperBound,
                           step: 1,
                           title: "Reminder \(i + 1)",
                           color: colors[i],
                           baseSize: 104,
                           zeroMeansOff: true)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func slot(_ i: Int) -> Binding<Int> {
        Binding(
            get: { i < minutes.count ? minutes[i] : 0 },
            set: { newValue in
                var m = minutes
                while m.count < ScreenTimeConfiguration.maxWarnings { m.append(0) }
                m[i] = newValue
                minutes = m
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView(services: .mocks(), onSaved: {})
    }
}
