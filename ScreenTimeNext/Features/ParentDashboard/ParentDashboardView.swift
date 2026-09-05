//  ParentDashboardView.swift
//  ScreenTimeNext
//
//  Task 014 — PRD §6.9: today's budget, remaining time, protection status, selected content,
//  selected activities. Parent controls are explicit and deliberate (§7.5); nothing here is one
//  tap from the child timer.

import SwiftUI
import UIKit
import ScreenTimeNextCore

struct ParentDashboardView: View {
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ParentDashboardViewModel
    @State private var confirmEndSession = false
    @State private var pendingExtension: Int?
    let onOpenTimer: () -> Void
    let onReset: () -> Void

    init(services: ServiceContainer, onOpenTimer: @escaping () -> Void, onReset: @escaping () -> Void) {
        _viewModel = State(initialValue: ParentDashboardViewModel(services: services))
        self.onOpenTimer = onOpenTimer
        self.onReset = onReset
    }

    var body: some View {
        NavigationStack {
            List {
                todaySection
                childSection
                contentSection
                whatsNextSection
                parentSection
            }
            .navigationTitle(viewModel.profile.map { "\($0.name)'s screen time" } ?? "ScreenTimeNext")
            .toolbar {
                NavigationLink {
                    SettingsView(services: services, onSaved: { viewModel.reload() }, onReset: onReset)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .onAppear { viewModel.appeared() }
            .onDisappear { viewModel.disappeared() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { viewModel.reload() }
            }
            .confirmationDialog("End today's session now?", isPresented: $confirmEndSession, titleVisibility: .visible) {
                Button("End session", role: .destructive) { viewModel.endSession() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("The time used so far counts toward today's budget.")
            }
        }
    }

    // MARK: Sections

    private var todaySection: some View {
        Section("Today") {
            LabeledContent("Daily budget", value: "\(viewModel.configuration.dailyBudgetSeconds / 60) min")
            LabeledContent("Remaining today", value: ChildTimerView.clock(viewModel.remainingTodaySeconds))
            LabeledContent("Session", value: viewModel.sessionStatusText)
            LabeledContent("Protection", value: viewModel.protectionText)
            LabeledContent("Screen Time access", value: viewModel.authorizationText)
        }
    }

    private var childSection: some View {
        Section {
            Button(action: onOpenTimer) {
                Label("Open child timer", systemImage: "hourglass")
            }
            if viewModel.sessionIsRunning {
                Button(role: .destructive) {
                    confirmEndSession = true
                } label: {
                    Label("End session now", systemImage: "stop.circle")
                }
            }
        } header: {
            Text("Child")
        } footer: {
            Text("Hand the device to \(viewModel.profile?.name ?? "your child") on the timer screen. While a session runs, opening the app shows the timer; press and hold \u{201C}Parents\u{201D} to come back here.")
        }
    }

    private var contentSection: some View {
        Section {
            if viewModel.selectionSummary.isEmpty {
                Text("Nothing selected yet").foregroundStyle(.secondary)
            } else {
                SelectionSummaryView(summary: viewModel.selectionSummary)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("Protected content")
        } footer: {
            Text("Enforcement arrives with Screen Time access. In this preview build the budget is a timer only.")
        }
    }

    private var whatsNextSection: some View {
        Section("What's next") {
            if viewModel.configuration.selectedActivities.isEmpty {
                Text("All activities offered").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.configuration.selectedActivities) { activity in
                    Label(activity.displayName, systemImage: activity.symbolName)
                }
            }
        }
    }

    private var parentSection: some View {
        Section {
            if viewModel.notificationsDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Notifications are off — warnings only show in the app", systemImage: "bell.slash")
                }
            } else {
                LabeledContent("Notifications", value: "On")
            }
            if viewModel.canExtend {
                Menu {
                    Button("+10 minutes") { pendingExtension = 10 }
                    Button("+20 minutes") { pendingExtension = 20 }
                } label: {
                    Label("Extend time", systemImage: "plus.circle")
                }
            } else {
                LabeledContent("Extend time") {
                    Text("No session today yet").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Parent")
        } footer: {
            Text("Extra minutes are beyond today's budget. Allow Once arrives with Screen Time access.")
        }
        .confirmationDialog("Give \(viewModel.profile?.name ?? "your child") \(pendingExtension ?? 0) more minutes?",
                            isPresented: Binding(get: { pendingExtension != nil }, set: { if !$0 { pendingExtension = nil } }),
                            titleVisibility: .visible) {
            Button("Add \(pendingExtension ?? 0) minutes") {
                if let m = pendingExtension { viewModel.extend(minutes: m) }
                pendingExtension = nil
            }
            Button("Cancel", role: .cancel) { pendingExtension = nil }
        }
    }
}

#Preview {
    ParentDashboardView(services: .mocks(storage: dashboardPreviewStorage()), onOpenTimer: {}, onReset: {})
}

private func dashboardPreviewStorage() -> InMemoryScreenTimeStorageService {
    let s = InMemoryScreenTimeStorageService()
    try? s.save(ChildProfile(name: "Ivy"))
    var c = ScreenTimeConfiguration.default
    c.selectedActivities = [.lego, .reading, .outside]
    try? s.save(c)
    return s
}
