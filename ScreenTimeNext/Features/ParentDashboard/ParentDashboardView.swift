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
    @State private var showExtend = false
    /// D-060 — raised BEFORE a timer starts, when starting it would not do what it looks like.
    @State private var startWarning: StartWarning?
    @State private var showSettings = false
    /// D-062 — the picker itself, reachable in one tap from the warning that needs it.
    @State private var showPicker = false
    @State private var picker = ContentPickerModel()
    @State private var pickerLoaded = false
    /// Once per visit, not once per redraw — the dashboard reloads on a timer.
    @State private var hasWarnedThisVisit = false
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
                    SettingsView(services: services, onSaved: { viewModel.configurationChanged() })
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .onAppear {
                viewModel.appeared()
                warnIfNothingIsCovered()
            }
            .onDisappear { viewModel.disappeared() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.reload()
                    warnIfNothingIsCovered()
                } else if phase == .background {
                    // A new visit is a new chance to have forgotten.
                    hasWarnedThisVisit = false
                }
            }
            // D-028 — the picker writes its selection the moment it closes, so the dashboard has
            // to hear about it then, not on the next foreground.
            .onReceive(NotificationCenter.default.publisher(for: .configurationDidChange)) { _ in
                viewModel.configurationChanged()
            }
            .sheet(isPresented: $showExtend) {
                // D-060 — once the clock has run out there is nothing left to take back, so the
                // sheet opens as "add" only. Offering a subtraction that cannot apply is a control
                // that exists to be refused.
                ExtendTimeSheet(childName: name, canTakeBack: viewModel.sessionIsRunning) { minutes in
                    viewModel.adjust(minutes: minutes)
                }
                .presentationDetents([.large])
            }
            .alert(item: $startWarning) { warning in
                Alert(title: Text(warning.title),
                      message: Text(warning.message),
                      primaryButton: .default(Text(warning.fixLabel)) {
                          switch warning {
                          case .restrictionsCleared:
                              viewModel.restoreRestrictionsAndStart()
                              onOpenTimer()
                          case .nothingCovered:
                              // D-062 — straight to the list. Sending a parent to Settings to find
                              // a row that opens the picker is two more decisions than the moment
                              // needs; the warning already told them exactly what to do.
                              showPicker = true
                          }
                      },
                      secondaryButton: .cancel(Text(warning.proceedLabel)) {
                          viewModel.startSession()
                          onOpenTimer()
                      })
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(services: services, onSaved: { viewModel.configurationChanged() })
            }
            .sheet(isPresented: $showPicker) {
                NavigationStack {
                    ContentPickerScreen(model: picker,
                                        screenTimeAccessAvailable: viewModel.authorization == .approved,
                                        onRequestAccess: { viewModel.requestAuthorization() },
                                        isRequestingAccess: viewModel.isRequestingAuthorization,
                                        accessDenied: viewModel.authorization == .denied) { _ in
                        picker.persist(to: services.storage)
                        viewModel.configurationChanged()
                    }
                }
                .task {
                    guard !pickerLoaded else { return }
                    picker = ContentPickerModel.loaded(from: services.storage,
                                                       selection: services.selection,
                                                       autosaving: true)
                    pickerLoaded = true
                }
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
            VStack(spacing: 18) {
                heroHeader
                // A FIXED height for the middle band, whatever is in it. The card used to change
                // shape between "ready" and "in session" — two different compositions in the same
                // frame — and a card that jumps when the state changes reads as two screens rather
                // than one thing in two moods.
                heroCentre.frame(height: 150)
                heroActions
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.heroGradient))
            // A single hairline is the difference between a gradient that reads as a card and one
            // that reads as a coloured area of the screen.
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
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
                Text("Hold “Parents” in the timer to come back.")
            }
        }
    }

    /// D-055 — the name reads as a name, the state reads as a status field, and the mascot stops
    /// competing with them. It was 76pt in the corner opposite a left-aligned title, with a
    /// centred ring underneath: three anchors, no relationship between them.
    private var heroHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "Today" : name)
                    .font(.title3.weight(.semibold))
                Text(viewModel.sessionStatusText.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.9)
                    .opacity(0.75)
            }
            Spacer(minLength: 0)
            Mascot(mood: heroMood, size: 48, tint: .white, animated: false)
        }
    }

    @ViewBuilder
    private var heroCentre: some View {
        if viewModel.sessionIsRunning || viewModel.session.state == .finished {
            runningRing
        } else {
            quickStart
        }
    }

    /// Mid-session: the ring alone in the middle band, centred, with nothing beside it to pull the
    /// eye off the number. Rounded digits, everything else in the system face — a clock should look
    /// friendly; a dashboard should not look like a toy.
    private var runningRing: some View {
        ZStack {
            ProgressRing(fraction: viewModel.remainingFraction, lineWidth: 10, color: .white.opacity(0.95))
            VStack(spacing: 2) {
                Text(ChildTimerView.clock(viewModel.session.window != nil
                                          ? viewModel.session.remainingSeconds
                                          : viewModel.remainingTodaySeconds))
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(viewModel.session.window != nil ? "REMAINING" : "LEFT TODAY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .opacity(0.75)
            }
        }
        .frame(width: 150, height: 150)
    }

    /// Idle: the same band, the same weight of type — set the minutes, hand it over.
    private var quickStart: some View {
        HStack(spacing: 18) {
            stepper("minus", -1)
            VStack(spacing: 0) {
                Text("\(viewModel.quickMinutes)")
                    .font(.system(size: 60, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("MINUTES")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .opacity(0.75)
            }
            .frame(minWidth: 96)
            stepper("plus", 1)
        }
        .sensoryFeedback(.selection, trigger: viewModel.quickMinutes)
    }

    private func stepper(_ symbol: String, _ delta: Int) -> some View {
        Button { viewModel.adjustQuickMinutes(delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
                .background(Circle().fill(.white.opacity(0.18)))
                .overlay(Circle().strokeBorder(.white.opacity(0.24), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    /// One row of equal-width actions, edge to edge. The old chips were two different widths
    /// floating under a centred ring, which is what made the card look unresolved.
    @ViewBuilder
    private var heroActions: some View {
        HStack(spacing: 10) {
            if viewModel.sessionIsRunning {
                // D-036 — no "are you sure?". This is already behind the parent PIN, and the parent
                // pressing it is usually standing next to a child who has just been told the timer
                // is stopping. A second tap turns a decision into a delay.
                heroButton("End", "stop.fill", filled: false) { viewModel.endSession() }
                heroButton("Time", "plusminus", filled: false) { showExtend = true }
            } else if viewModel.canExtend {
                // D-060 — "plus", not "plusminus". The clock has run out; there is nothing under
                // zero to take back, and an icon promising both is promising one that cannot work.
                heroButton("Add time", "plus", filled: true) { showExtend = true }
            } else {
                heroButton("Start now", "play.fill", filled: true) { start() }
                    .disabled(viewModel.remainingTodaySeconds == 0)
                    .opacity(viewModel.remainingTodaySeconds == 0 ? 0.5 : 1)
            }
        }
    }

    /// D-060 — everything that starts a timer goes through here.
    ///
    /// Two states make a timer do nothing while looking exactly like a timer that works: every
    /// restriction slid off for the day, and no apps ever picked. A parent finds out fifteen
    /// minutes later, when the end arrives and nothing happens. So they are told at the one moment
    /// the information is useful, with the fix offered as the first button.
    /// D-061 — an empty selection is worth saying on ARRIVAL, not only when Start is pressed.
    ///
    /// A parent who has just finished Start over is looking at a dashboard that looks complete: a
    /// dial, a ring, a green slide. The one thing missing is the thing the whole app rests on, and
    /// the only sign of it was a grey "Nothing selected yet" three sections down.
    ///
    /// Once per visit. A dashboard that reloads every second must not raise an alert every second.
    private func warnIfNothingIsCovered() {
        guard !hasWarnedThisVisit, startWarning == nil,
              viewModel.selectionSummary.isEmpty else { return }
        hasWarnedThisVisit = true
        startWarning = .nothingCovered
    }

    private func start() {
        if let warning = viewModel.startWarning {
            startWarning = warning
            return
        }
        viewModel.startSession()
        onOpenTimer()
    }

    private func heroButton(_ title: String, _ symbol: String, filled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? Theme.sky : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().fill(filled ? AnyShapeStyle(Color.white)
                                                  : AnyShapeStyle(Color.white.opacity(0.18))))
                .overlay(filled ? nil : Capsule().strokeBorder(.white.opacity(0.24), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
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
            Text("Covered apps show a full-screen message at each reminder, and when time is up.")
        }
    }

    /// D-072 — ONE row: what is actually happening after this session.
    ///
    /// D-052 put ticks here; D-053 moved them to Settings and left a read-out; D-057 cut that
    /// read-out to the three a shield fits. Each step was smaller than the last and none of them
    /// answered the question a parent opens this screen with, which is not "what could my child
    /// pick" but "what did they pick". Three rows that never change say nothing on a dashboard.
    ///
    /// So: the answer, or an honest blank until there is one. The list itself is in Settings.
    private var whatsNextSection: some View {
        Section {
            if let activity = viewModel.whatsNextActivity {
                HStack(spacing: 12) {
                    IconChip(symbol: activity.symbolName, color: Theme.color(for: activity), size: 30)
                    Text(activity.displayName).fontWeight(.medium)
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 12) {
                    IconChip(symbol: "questionmark", color: Color.secondary, size: 30)
                    Text("Not chosen yet").foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        } header: {
            HStack {
                Text("What's next")
                Spacer()
                NavigationLink {
                    SettingsView(services: services, onSaved: { viewModel.configurationChanged() })
                } label: {
                    Text("Edit").font(.caption.weight(.bold)).textCase(nil)
                }
            }
        } footer: {
            Text(whatsNextFooter)
        }
    }

    /// D-072 — says who decided, because that is the part a parent cannot see from the name.
    private var whatsNextFooter: String {
        guard viewModel.whatsNextActivity != nil else {
            return "Your child picks on the transition screen. Tick one in Settings to decide for them."
        }
        return viewModel.whatsNextByParent
            ? "You decided this. Starting a new session clears it."
            : "Your child picked this."
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
            // It ends by itself, which is the point: a parent who says yes to a film night
            // should not have to remember to say no again in the morning.
            Text(viewModel.canClearRestrictions
                 ? "Comes back on its own at midnight."
                 : "Available once today's time is up.")
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

    /// D-055 — a slide, and no dialog behind it.
    ///
    /// The confirmation sheet was theatre: it always got the same answer, and a parent who has
    /// already passed the gate and reached for a destructive row is not helped by being asked the
    /// same question in different words. The travel is the confirmation; the footer is where the
    /// consequences are actually read, which is why it says exactly what goes and what stays.
    private var dangerSection: some View {
        Section {
            ConfirmSlide(title: "Slide to erase and start over",
                         symbol: "arrow.counterclockwise") { onReset() }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
        } footer: {
            Text("Erases the profile, budget and reminders. Your sets, websites, activities and PIN are kept.")
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
    /// D-060 — false once the clock has run out: there is nothing under zero to take back.
    var canTakeBack: Bool = true
    /// Positive adds, negative takes back.
    let onExtend: (Int) -> Void

    @State private var minutes = 3
    @State private var isAdding = true

    private var tint: Color { isAdding ? Theme.lavender : Theme.peach }

    var body: some View {
        NavigationStack {
            // D-060 — scrolling content, pinned button.
            //
            // The button used to be the last thing in a VStack, so on a shorter phone — or with
            // larger text — it sat below the edge of the sheet with nothing to scroll. A parent
            // could set the minutes and then not be able to apply them, which is the worst possible
            // place for a layout to fail. The action is now in a bottom bar that cannot be pushed
            // anywhere, and everything above it scrolls.
            ScrollView {
                VStack(spacing: 20) {
                    Mascot(mood: isAdding ? .cheering : .thinking, size: 84, tint: tint)

                    if canTakeBack {
                        Picker("", selection: $isAdding) {
                            Text("Add time").tag(true)
                            Text("Take back").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 24)
                        .readableWidth(460)
                    }

                    MinuteDial.budget($minutes, color: tint)

                    Text(explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onExtend(isAdding ? minutes : -minutes)
                    dismiss()
                } label: {
                    Text(isAdding ? "Add \(minutes) minutes" : "Take back \(minutes) minutes")
                }
                .buttonStyle(PillButtonStyle(color: tint))
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .readableWidth(460)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { if !canTakeBack { isAdding = true } }
        }
    }

    private var navigationTitle: String {
        if !canTakeBack { return childName.isEmpty ? "Add time" : "Add time for \(childName)" }
        return childName.isEmpty ? "Change time" : "Change \(childName)'s time"
    }

    private var explanation: String {
        if !canTakeBack {
            return "The timer has finished, so these minutes start from now."
        }
        return isAdding
            ? "Added from now, so it means the same whether the timer is still running or already finished."
            : "Taken off the end. The session never rewinds past this moment."
    }
}

#Preview {
    ParentDashboardView(services: .mocks(storage: dashboardPreviewStorage()), onOpenTimer: {}, onReset: {})
}

private func dashboardPreviewStorage() -> InMemoryScreenTimeStorageService {
    let s = InMemoryScreenTimeStorageService()
    try? s.save(ChildProfile(name: "Ivy"))
    try? s.save(ScreenTimeConfiguration.default)
    return s
}
