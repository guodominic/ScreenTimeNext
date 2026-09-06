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

    /// The child's name if the parent gave one. D-018 — never a stand-in like "your child";
    /// screens that need a heading fall back to something true instead.
    private var name: String { viewModel.profile?.name ?? "" }

    var body: some View {
        NavigationStack {
            List {
                heroSection
                if viewModel.authorization != .approved { screenTimeAccessSection }
                if viewModel.notificationsDenied { notificationAlertSection }
                contentSection
                whatsNextSection
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
                ShieldPreviewView(childName: name,
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

    /// D-017/D-018 — the ring IS the session: it shows the state and it is the way into the child
    /// timer, so it carries no label telling you to tap it. Only End and Extend remain, and they
    /// are real buttons: the card is tappable through `onTapGesture`, not wrapped in a `Button`,
    /// because a Button inside a Button swallows the inner taps.
    private var heroSection: some View {
        Section {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    Text(name.isEmpty ? "Today" : name)
                        .font(.system(.title2, design: .rounded).bold())
                    Spacer(minLength: 0)
                    Mascot(mood: heroMood, size: 76, tint: .white, animated: false)
                }

                if viewModel.sessionIsRunning || viewModel.session.state == .finished {
                    runningRing
                } else {
                    quickStart
                }
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.heroGradient))
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onTapGesture { onOpenTimer() }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the timer")
            .bounceIn()
            .readableWidth(720)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            if viewModel.sessionIsRunning {
                Text("Press and hold “Parents” in the timer to come back here.")
            }
        }
    }

    /// Mid-session: the ring, number unobstructed, and the two controls a parent actually uses.
    private var runningRing: some View {
        VStack(spacing: 12) {
            ZStack {
                ProgressRing(fraction: viewModel.remainingFraction, lineWidth: 12, color: .white.opacity(0.95))
                VStack(spacing: 0) {
                    Text(ChildTimerView.clock(viewModel.session.window != nil ? viewModel.session.remainingSeconds : viewModel.remainingTodaySeconds))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(viewModel.session.window != nil ? "in session" : "left today")
                        .font(.caption2.weight(.semibold))
                        .opacity(0.85)
                }
            }
            .frame(width: 132, height: 132)

            HStack(spacing: 12) {
                if viewModel.sessionIsRunning {
                    Button(role: .destructive) { confirmEndSession = true } label: {
                        heroChip("End", "stop.fill")
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("End today's session now?", isPresented: $confirmEndSession, titleVisibility: .visible) {
                        Button("End session", role: .destructive) { viewModel.endSession() }
                        Button("Keep going", role: .cancel) {}
                    } message: {
                        Text("The time used so far counts toward today's budget.")
                    }
                }
                if viewModel.canExtend {
                    Button { showExtend = true } label: {
                        heroChip("Extend", "plus")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func heroChip(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(.subheadline, design: .rounded).bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.22)))
    }

    /// Idle: the whole point of the app in two taps — set the minutes, hand it over.
    private var quickStart: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Button { viewModel.adjustQuickMinutes(-1) } label: {
                    Image(systemName: "minus.circle.fill").font(.title)
                }
                .buttonStyle(.plain)
                VStack(spacing: -2) {
                    Text("\(viewModel.quickMinutes)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("minutes").font(.caption.weight(.semibold)).opacity(0.85)
                }
                .frame(minWidth: 110)
                Button { viewModel.adjustQuickMinutes(1) } label: {
                    Image(systemName: "plus.circle.fill").font(.title)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .sensoryFeedback(.selection, trigger: viewModel.quickMinutes)

            Button {
                viewModel.startSession()
                onOpenTimer()
            } label: {
                Label("Start now", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(Theme.sky)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.remainingTodaySeconds == 0)
            .opacity(viewModel.remainingTodaySeconds == 0 ? 0.5 : 1)
        }
    }

    private var heroMood: MascotMood {
        switch viewModel.session.state {
        case .idle: return .happy
        case .finished: return .sleepy
        case .firstWarning, .secondWarning: return .thinking
        case .finalWarning: return .excited
        default: return .playing
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
            Text("With Screen Time access, a full-screen message appears inside the app being used — at each reminder, and when time is up. Preview it above; enforcement itself arrives with that access.")
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

    /// Task 004 — shown only while access is missing, for the same reason as the notification row
    /// below: a dashboard of things that are fine is noise, but this one means nothing is being
    /// enforced, which the parent cannot discover any other way.
    private var screenTimeAccessSection: some View {
        Section {
            ScreenTimeAccessRow(status: viewModel.authorization,
                                isRequesting: viewModel.isRequestingAuthorization,
                                onRequest: { viewModel.requestAuthorization() })
            if let error = viewModel.authorizationError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
    }

    /// D-018 — the "Status" list is gone: a dashboard of things that are fine is noise. What
    /// survives is the one line that means the app is not doing its job, shown only when true.
    private var notificationAlertSection: some View {
        Section {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "bell.slash.fill", color: .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications are off").fontWeight(.semibold)
                        Text("Reminders will only show inside the app.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                Text("Erases the profile, the budget and the reminders on this device. Your category order and “my usual” are kept. This cannot be undone.")
            }
        } footer: {
            Text("Erases the child profile, the budget and the reminders. Your picker arrangement is kept.")
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
                Text(childName.isEmpty ? "More time" : "Give \(childName) more time")
                    .font(.system(.title2, design: .rounded).bold())
                // D-020 — "give five more minutes" is the common case, so extra time gets the
                // same fine steps as the budget rather than jumping two at a time.
                MinuteDial.budget($minutes, color: Theme.lavender)
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
