//  ParentDashboardView.swift
//  ScreenTimeNext
//
//  Task 014 — PRD §6.9: today's budget, remaining time, protection status, selected content,
//  selected activities. Parent controls are explicit and deliberate (§7.5). Extend time is a dial
//  (D-013); Start over lives at the bottom of this screen.

import SwiftUI
import Combine
import UIKit
import ScreenTimeNextCore

struct ParentDashboardView: View {
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ParentDashboardViewModel
    @State private var confirmReset = false
    @State private var showExtend = false
    @State private var showCoveredContent = false
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
                restrictionSection
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
            // D-028 — the picker writes its selection the moment it closes, so the dashboard has
            // to hear about it then, not on the next foreground.
            .onReceive(NotificationCenter.default.publisher(for: .configurationDidChange)) { _ in
                viewModel.reload()
            }
            .sheet(isPresented: $showExtend) {
                ExtendTimeSheet(childName: name) { minutes in
                    viewModel.adjust(minutes: minutes)
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
                    // D-036 — no "are you sure?". This button is already behind the parent PIN,
                    // and the parent pressing it is usually standing next to a child who has just
                    // been told the timer is stopping. A second tap turns a decision into a delay.
                    Button(role: .destructive) { viewModel.endSession() } label: {
                        heroChip("End", "stop.fill")
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.canExtend {
                    Button { showExtend = true } label: {
                        heroChip("Time", "plusminus")
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
            } else if let snapshot = viewModel.selection {
                Button { showCoveredContent = true } label: {
                    SelectionSummaryView(summary: viewModel.selectionSummary)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .sheet(isPresented: $showCoveredContent) {
                    CoveredContentSheet(snapshot: snapshot)
                }
            }
        } header: {
            Text("Protected content")
        } footer: {
            Text("A full-screen message appears inside the app your child is using — at each reminder, and when time is up.")
        }
    }

    /// D-053 — a read-out, not a control.
    ///
    /// D-052 put the ticks here, and that was wrong twice over: choosing which activities are
    /// offered is configuration a parent does once, and a tappable list sitting next to the ring
    /// made the screen a parent opens every evening read like a settings page. What belongs here
    /// is the answer to "what will my child be asked?" — so that is all it shows now. Editing is
    /// back in Settings, next to the list it edits.
    private var whatsNextSection: some View {
        Section {
            let offered = viewModel.offeredActivities
            // The order is the answer: a system shield can show three (D-044), and it takes them
            // off the front. Marking the cut-off is the only way a parent can tell, from here,
            // that reordering in Settings changes what their child sees.
            ForEach(Array(offered.enumerated()), id: \.element.id) { index, activity in
                HStack(spacing: 12) {
                    IconChip(symbol: activity.symbolName, color: Theme.color(for: activity), size: 30)
                    Text(activity.displayName).fontWeight(.medium)
                    Spacer(minLength: 0)
                    if index < viewModel.shieldChoiceCount {
                        Text("On the shield")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.color(for: activity))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.color(for: activity).opacity(0.14)))
                    }
                }
            }
        } header: {
            HStack {
                Text("What's next")
                Spacer()
                NavigationLink {
                    SettingsView(services: services, onSaved: { viewModel.reload() })
                } label: {
                    Text("Edit").font(.caption.weight(.bold)).textCase(nil)
                }
            }
        } footer: {
            Text(viewModel.offersEverything
                 ? "Nothing picked yet, so your child is offered all of these. Choose in Settings."
                 : "Your child sees the first \(viewModel.shieldChoiceCount) on the transition screen, in this order.")
        }
    }

    /// D-053 — the slide that clears every restriction for the rest of today, and puts them back.
    ///
    /// Disabled while time remains, because there is nothing to clear then: the apps are already
    /// open. A control that appears to do something it is not doing is worse than a missing one.
    private var restrictionSection: some View {
        Section {
            RestrictionSlide(isCleared: viewModel.restrictionsAreCleared,
                             isEnabled: viewModel.canClearRestrictions) { cleared in
                viewModel.setRestrictionsCleared(cleared)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .listRowBackground(Color.clear)
        } footer: {
            Text(viewModel.canClearRestrictions
                 // It ends by itself, which is the point: a parent who says yes to a film night
                 // should not have to remember to say no again in the morning.
                 ? "Slide to unblock every app for the rest of today. Restrictions come back by themselves at midnight, or slide again to bring them back now."
                 : "Available once today's time has run out — nothing is blocked while the timer is running.")
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
                Text("Erases the profile, the budget and the reminders on this device. The websites you typed, your saved sets and your own activities are kept. This cannot be undone.")
            }
        } footer: {
            Text("Erases the child profile, the budget and the reminders. What you made — saved sets, websites, your own activities — is kept.")
        }
    }
}

/// D-052 — add time OR take it back, on the same dial as everywhere else (1–90, D-034).
///
/// Two changes from the old "Extend" sheet, both from watching it used:
///   · the default is 3 minutes, not 10. "Two more minutes and then dinner" is the sentence a
///     parent actually says; ten was a number they had to dial down from every time.
///   · time can come off as well as on. A parent who gave twenty minutes and then remembered
///     bedtime had no way back except ending the session outright.
struct ExtendTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let childName: String
    /// Positive adds, negative takes back.
    let onExtend: (Int) -> Void

    @State private var minutes = 3
    @State private var isAdding = true

    private var tint: Color { isAdding ? Theme.lavender : Theme.peach }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Mascot(mood: isAdding ? .cheering : .thinking, size: 84, tint: tint)

                Picker("", selection: $isAdding) {
                    Text("Add time").tag(true)
                    Text("Take back").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .readableWidth(460)

                MinuteDial.budget($minutes, color: tint)

                Text(isAdding
                     ? "Added from now, so it means the same whether the timer is still running or already finished."
                     : "Taken off the end. The session never rewinds past this moment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    onExtend(isAdding ? minutes : -minutes)
                    dismiss()
                } label: {
                    Text(isAdding ? "Add \(minutes) minutes" : "Take back \(minutes) minutes")
                }
                .buttonStyle(PillButtonStyle(color: tint))
                .padding(.horizontal, 24)
                .readableWidth(460)
            }
            .padding(.top, 20)
            .navigationTitle(childName.isEmpty ? "Change time" : "Change \(childName)'s time")
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
    c.selectedActivities = [.familyTime, .outside, .cleanUp]
    try? s.save(c)
    return s
}
