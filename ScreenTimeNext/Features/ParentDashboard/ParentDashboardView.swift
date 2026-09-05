//  ParentDashboardView.swift
//  ScreenTimeNext
//
//  Task 014 — PRD §6.9: today's budget, remaining time, protection status, selected content,
//  selected activities. Parent controls are explicit and deliberate (§7.5); nothing here is one
//  tap from the child timer.

import SwiftUI
import ScreenTimeNextCore

struct ParentDashboardView: View {
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ParentDashboardViewModel
    @State private var confirmEndSession = false
    let onReset: () -> Void

    init(services: ServiceContainer, onReset: @escaping () -> Void) {
        _viewModel = State(initialValue: ParentDashboardViewModel(services: services))
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
        }
    }

    private var childSection: some View {
        Section {
            NavigationLink {
                ChildTimerView(services: services)
            } label: {
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
            Text("Hand the device to \(viewModel.profile?.name ?? "your child") on the timer screen. There is no way back to this screen mid-session.")
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
            LabeledContent("Extend time") {
                Text("Coming with Screen Time access").foregroundStyle(.secondary)
            }
        } header: {
            Text("Parent")
        } footer: {
            Text("+10 / +20 minutes and Allow Once arrive in Phase 1.")
        }
    }
}

#Preview {
    ParentDashboardView(services: .mocks(storage: dashboardPreviewStorage()), onReset: {})
}

private func dashboardPreviewStorage() -> InMemoryScreenTimeStorageService {
    let s = InMemoryScreenTimeStorageService()
    try? s.save(ChildProfile(name: "Ivy"))
    var c = ScreenTimeConfiguration.default
    c.selectedActivities = [.lego, .reading, .outside]
    try? s.save(c)
    return s
}
