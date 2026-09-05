//  ParentDashboardView.swift
//  ScreenTimeNext
//
//  Task 014 — PRD §6.9: today's budget, remaining time, protection status, selected content,
//  selected activities. Parent controls are explicit and deliberate (§7.5). Extend time is a dial
//  (D-013); Start over lives at the bottom of this screen.

import SwiftUI
import UIKit
import ScreenTimeNextCore

struct ParentDashboardView: View {
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ParentDashboardViewModel
    @State private var confirmEndSession = false
    @State private var confirmReset = false
    @State private var showExtend = false
    @State private var showShieldPreview = false
    let onOpenTimer: () -> Void
    let onReset: () -> Void

    init(services: ServiceContainer, onOpenTimer: @escaping () -> Void, onReset: @escaping () -> Void) {
        _viewModel = State(initialValue: ParentDashboardViewModel(services: services))
        self.onOpenTimer = onOpenTimer
        self.onReset = onReset
    }

    private var name: String { viewModel.profile?.name ?? "your child" }

    var body: some View {
        NavigationStack {
            List {
                heroSection
                childSection
                contentSection
                whatsNextSection
                parentSection
                dangerSection
            }
            .listSectionSpacing(14)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ScreenTimeNext")
            .toolbar {
                NavigationLink {
                    SettingsView(services: services, onSaved: { viewModel.reload() })
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .onAppear { viewModel.appeared() }
            .onDisappear { viewModel.disappeared() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { viewModel.reload() }
            }
            .sheet(isPresented: $showShieldPreview) {
                ShieldPreviewView(childName: viewModel.profile?.name ?? "your child",
                                  activities: viewModel.configuration.selectedActivities.isEmpty
                                      ? TransitionActivity.allCases
                                      : viewModel.configuration.selectedActivities)
            }
            .sheet(isPresented: $showExtend) {
                ExtendTimeSheet(childName: name) { minutes in
                    viewModel.extend(minutes: minutes)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: Sections

    private var heroSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    ProgressRing(fraction: viewModel.remainingFraction, lineWidth: 12, color: .white.opacity(0.95))
                    VStack(spacing: 0) {
                        Text(ChildTimerView.clock(viewModel.session.window != nil ? viewModel.session.remainingSeconds : viewModel.remainingTodaySeconds))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(viewModel.session.window != nil ? "in session" : "left today")
                            .font(.caption2.weight(.semibold))
                            .opacity(0.85)
                    }
                    Mascot(mood: heroMood, size: 52, tint: .white, animated: false)
                        .offset(x: -10, y: 8)
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(.system(.title2, design: .rounded).bold())
                    statChip("clock.fill", "\(viewModel.configuration.dailyBudgetSeconds / 60) min a day")
                    statChip(sessionSymbol, viewModel.sessionStatusText)
                    statChip("shield.lefthalf.filled", viewModel.protectionText)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.heroGradient))
            .bounceIn()
            .readableWidth(720)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var heroMood: MascotMood {
        switch viewModel.session.state {
        case .idle: return .happy
        case .finished: return .sleepy
        case .firstWarning, .secondWarning: return .thinking
        case .finalWarning: return .hurrying
        default: return .playing
        }
    }

    private var sessionSymbol: String {
        switch viewModel.session.state {
        case .idle: return "pause.circle.fill"
        case .finished: return "checkmark.circle.fill"
        case .firstWarning, .secondWarning, .finalWarning: return "bell.badge.fill"
        default: return "play.circle.fill"
        }
    }

    private func statChip(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.18)))
    }

    private var childSection: some View {
        Section {
            Button(action: onOpenTimer) {
                HStack(spacing: 12) {
                    IconChip(symbol: "hourglass", color: Theme.mint)
                    Text("Open child timer").fontWeight(.semibold).foregroundStyle(Theme.mint)
                }
            }
            if viewModel.canExtend {
                Button { showExtend = true } label: {
                    HStack(spacing: 12) {
                        IconChip(symbol: "plus", color: Theme.lavender)
                        Text("Extend time").fontWeight(.semibold).foregroundStyle(Theme.lavender)
                    }
                }
            }
            if viewModel.sessionIsRunning {
                Button(role: .destructive) { confirmEndSession = true } label: {
                    HStack(spacing: 12) {
                        IconChip(symbol: "stop.fill", color: .red)
                        Text("End session now").fontWeight(.semibold).foregroundStyle(.red)
                    }
                }
                // Anchored to the button so the iPad popover points at it (Dominic, 2026-09-05).
                .confirmationDialog("End today's session now?", isPresented: $confirmEndSession, titleVisibility: .visible) {
                    Button("End session", role: .destructive) { viewModel.endSession() }
                    Button("Keep going", role: .cancel) {}
                } message: {
                    Text("The time used so far counts toward today's budget.")
                }
            }
        } header: {
            Text("Session")
        } footer: {
            Text("Hand the device to \(name) on the timer screen. While a session runs, opening the app shows the timer; press and hold \u{201C}Parents\u{201D} to come back here.")
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
            Button { showShieldPreview = true } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "sparkles", color: Theme.coral)
                    Text("Preview the transition screen").fontWeight(.semibold).foregroundStyle(Theme.coral)
                }
            }
        } header: {
            Text("Protected content")
        } footer: {
            Text("With Screen Time access, a full-screen message appears inside the app your child is using — at each reminder, and when time is up. Preview it above; enforcement itself arrives with that access.")
        }
    }

    private var whatsNextSection: some View {
        Section("What's next") {
            if viewModel.configuration.selectedActivities.isEmpty {
                Text("All activities offered").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.configuration.selectedActivities) { activity in
                    HStack(spacing: 12) {
                        IconChip(symbol: activity.symbolName, color: Theme.color(for: activity), size: 30)
                        Text(activity.displayName).fontWeight(.medium)
                    }
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
                    Label("Notifications are off — reminders only show in the app", systemImage: "bell.slash")
                }
            } else {
                LabeledContent("Notifications", value: "On")
            }
            LabeledContent("Screen Time access", value: viewModel.authorizationText)
            LabeledContent("Reminders", value: reminderSummary)
        } header: {
            Text("Status")
        }
    }

    private var reminderSummary: String {
        let config = viewModel.configuration
        let mins = config.effectiveWarningOffsets(forWindowSeconds: config.dailyBudgetSeconds).map { "\($0 / 60)" }
        return mins.isEmpty ? "Finish only" : mins.joined(separator: " / ") + " min"
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) { confirmReset = true } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "arrow.counterclockwise", color: .red)
                    Text("Start over").fontWeight(.semibold).foregroundStyle(.red)
                }
            }
            // Anchored here, not on the List: on iPad an unanchored confirmationDialog drifts to
            // the screen edge instead of pointing at the button.
            .confirmationDialog("Start over?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase and start over", role: .destructive) { onReset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Erases \(name)'s profile and all settings on this device. This cannot be undone.")
            }
        } footer: {
            Text("Erases the child profile and all settings on this device.")
        }
    }
}

/// D-013: extension minutes on a dial, 2–120 in 2-minute steps.
struct ExtendTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let childName: String
    let onExtend: (Int) -> Void
    @State private var minutes = 10

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Mascot(mood: .cheering, size: 84, tint: Theme.lavender)
                Text("Give \(childName) more time")
                    .font(.system(.title2, design: .rounded).bold())
                MinuteDial(minutes: $minutes, range: 2...120, step: 2, color: Theme.lavender)
                Text("Extra minutes are beyond today's budget.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button { onExtend(minutes); dismiss() } label: { Text("Add \(minutes) minutes") }
                    .buttonStyle(PillButtonStyle(color: Theme.lavender))
                    .padding(.horizontal, 24)
                    .readableWidth(460)
            }
            .padding(.top, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
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
