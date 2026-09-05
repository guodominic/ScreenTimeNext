//  HomePlaceholderView.swift
//  ScreenTimeNext
//
//  Task 003 placeholder for "setup is complete". Task 014 (parent dashboard) and Task 007
//  (child timer) replace this. The reset control exists so onboarding can be re-run while iterating.

import SwiftUI
import ScreenTimeNextCore

struct HomePlaceholderView: View {
    @Environment(\.services) private var services
    let onReset: () -> Void

    @State private var profile: ChildProfile?
    @State private var configuration: ScreenTimeConfiguration = .default
    @State private var selectionSummary: SelectionSummary = .empty

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    LabeledContent("Name", value: profile?.name ?? "—")
                }
                Section("Screen time") {
                    LabeledContent("Daily budget", value: "\(configuration.dailyBudgetSeconds / 60) min")
                    LabeledContent("Warnings", value: warningSummary)
                    LabeledContent("Protected", value: selectionSummary.isEmpty ? "Nothing yet" : "\(selectionSummary.applicationCount) apps · \(selectionSummary.categoryCount) categories")
                }
                Section("Child") {
                    NavigationLink("Open child timer") {
                        ChildTimerView(services: services)
                    }
                    Button("End session now", role: .destructive) {
                        _ = try? SessionController(storage: services.storage).endEarly()
                    }
                }
                Section("What's next") {
                    if configuration.selectedActivities.isEmpty {
                        Text("No activities chosen").foregroundStyle(.secondary)
                    } else {
                        ForEach(configuration.selectedActivities) { Text($0.displayName) }
                    }
                }
                Section {
                    Button("Reset setup", role: .destructive, action: onReset)
                } footer: {
                    Text(services.storageIsVolatile
                         ? "Storage unavailable — settings will not survive a relaunch."
                         : "Settings are saved on this device. The parent dashboard and child timer are coming next.")
                }
            }
            .navigationTitle("ScreenTimeNext")
            .task { load() }
        }
    }

    private var warningSummary: String {
        [configuration.warning10Enabled ? "10" : nil,
         configuration.warning5Enabled ? "5" : nil,
         configuration.warning1Enabled ? "1" : nil]
            .compactMap { $0 }
            .joined(separator: " / ") + " min"
    }

    private func load() {
        profile = try? services.storage.loadChildProfile()
        configuration = (try? services.storage.loadConfiguration()) ?? .default
        selectionSummary = (try? services.selection.loadSelection())?.summary ?? .empty
    }
}
