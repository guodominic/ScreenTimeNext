//  ChildTimerView.swift
//  ScreenTimeNext
//
//  Task 007/009/015 — PRD §6.10–§6.14, §7. Large remaining time, minimal controls, friendly
//  language, state-driven, colorful. No settings, no authorization detail, nothing technical.
//  D-013: warning copy uses the parent's configured minutes.

import SwiftUI
import ScreenTimeNextCore

struct ChildTimerView: View {
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel: ChildTimerViewModel

    init(services: ServiceContainer) {
        _viewModel = State(initialValue: ChildTimerViewModel(services: services))
    }

    private var snapshot: ChildSessionSnapshot { viewModel.snapshot }
    private var name: String { viewModel.childName }
    /// D-016 — the name is optional, so every greeting has a name-less form.
    private var greeting: String { name.isEmpty ? "Hi!" : "Hi \(name)!" }
    private var addressed: String { name.isEmpty ? "" : ", \(name)" }
    private var color: Color { Theme.color(for: snapshot.state) }

    var body: some View {
        ZStack {
            ChildBackdrop(color: color)
            ScrollView {
                VStack(spacing: 24) {
                    content
                        .id(snapshot.state)   // new state = new view → transition below runs
                        .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity),
                                                removal: .opacity))
                    if let error = viewModel.errorText {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(28)
                .readableWidth(620)
                .multilineTextAlignment(.center)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: snapshot.state)
        .onAppear { viewModel.appeared() }
        .onDisappear { viewModel.disappeared() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refresh() }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ParentGateButton { dismiss() }   // D-011
            }
        }
    }

    // MARK: States

    @ViewBuilder
    private var content: some View {
        switch snapshot.state {
        case .idle:
            Spacer(minLength: 12)
            Mascot(mood: .happy, size: 150 * sizeClass.controlScale, tint: Theme.sky)
            SpeechBubble(color: Theme.sky) {
                VStack(spacing: 6) {
                    Text(greeting).font(.system(.title, design: .rounded).bold())
                    Text("You have \(minutesText(snapshot.remainingSeconds)) of screen time today.")
                        .font(.title3).foregroundStyle(.secondary)
                }
            }
            .bounceIn(delay: 0.1)
            Button { viewModel.start() } label: { Label("Start", systemImage: "play.fill") }
                .buttonStyle(PillButtonStyle(color: Theme.mint))
                .padding(.top, 8)

        case .active:
            ring(big: true)
            mascotRow(.playing, name.isEmpty ? "Enjoy your screen time." : "Enjoy your screen time, \(name).")

        case .extended:
            ring(big: true)
            mascotRow(.playing, name.isEmpty ? "You've got some extra time!" : "You've got some extra time\(addressed)!")

        case .firstWarning, .secondWarning:
            if snapshot.isChoosingMoment {
                // D-016 — this is where the child decides, at the second-to-last reminder.
                Mascot(mood: .thinking, size: 108 * sizeClass.controlScale, tint: color)
                headline("\(remainingMinutesText) left 👋")
                subline("What do you want to do next?")
                WhatsNextChooser(
                    activities: viewModel.availableActivities,
                    chosen: snapshot.chosenActivity,
                    onChoose: { viewModel.choose($0) }
                )
                ring(big: false)
            } else {
                Mascot(mood: .playing, size: 100 * sizeClass.controlScale, tint: color)
                headline("\(remainingMinutesText) left")
                subline(snapshot.chosenActivity == nil
                        ? "You're almost done."
                        : "Time to finish up what you're doing.")
                if let activity = snapshot.chosenActivity { ChosenActivityBadge(activity: activity) }
                ring(big: false)
            }

        case .finalWarning:
            headline(snapshot.remainingSeconds <= 60 ? "One more minute!" : "\(remainingMinutesText) left!")
            subline("Finish your game.")
            if let activity = snapshot.chosenActivity {
                ChosenActivityBadge(activity: activity)
            } else if snapshot.isChoosingMoment {
                WhatsNextChooser(
                    activities: viewModel.availableActivities,
                    chosen: nil,
                    onChoose: { viewModel.choose($0) }
                )
            }
            ring(big: true).pulsing()
            Mascot(mood: .hurrying, size: 92 * sizeClass.controlScale, tint: color)

        case .finished:
            TimesUpView(childName: name,
                        chosenActivity: snapshot.chosenActivity,
                        budgetSpentEarlier: snapshot.window == nil)
        }
    }

    // MARK: Pieces

    /// Whole minutes remaining, rounded UP, so "5 minutes left" holds from 5:00 down to 4:01.
    private var remainingMinutesText: String {
        let m = max(1, Int((Double(snapshot.remainingSeconds) / 60).rounded(.up)))
        return m == 1 ? "1 minute" : "\(m) minutes"
    }

    private func headline(_ text: String) -> some View {
        Text(text).font(.system(.largeTitle, design: .rounded).bold())
    }

    private func subline(_ text: String) -> some View {
        Text(text).font(.title3).foregroundStyle(.secondary)
    }

    /// Pip alongside a line of encouragement — used while time is simply running.
    private func mascotRow(_ mood: MascotMood, _ text: String) -> some View {
        HStack(spacing: 14) {
            Mascot(mood: mood, size: 78 * sizeClass.controlScale, tint: color)
            SpeechBubble(color: color) {
                Text(text).font(.headline).foregroundStyle(.secondary)
            }
        }
        .bounceIn(delay: 0.1)
    }

    /// Countdown inside a progress ring; the ring is remaining ÷ window total. Big and bold —
    /// this is the one thing on the screen a child should read from across the room.
    private func ring(big: Bool) -> some View {
        let total = max(1, snapshot.window?.totalSeconds ?? 1)
        let fraction = Double(snapshot.remainingSeconds) / Double(total)
        let size: CGFloat = (big ? 340 : 260) * sizeClass.controlScale
        let digits = Self.clock(snapshot.remainingSeconds)
        let fontSize: CGFloat = (big ? 96 : 68) * sizeClass.controlScale * (digits.count > 5 ? 0.78 : 1)   // h:mm:ss fits
        return ZStack {
            Circle().fill(color.opacity(0.10))
            ProgressRing(fraction: fraction, lineWidth: big ? 24 : 16, color: color)
            VStack(spacing: 2) {
                Text(digits)
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("left").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
        }
        .frame(width: size, height: size)
        .padding(.vertical, 8)
    }

    private func minutesText(_ seconds: Int) -> String {
        let m = seconds / 60
        return m == 1 ? "1 minute" : "\(m) minutes"
    }

    /// m:ss up to an hour, then h:mm:ss. Budgets go to 120 minutes (§6.5).
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}

/// A "Parents" control that opens on press-and-hold. A tap only shows the hint. (D-011)
struct ParentGateButton: View {
    let onUnlock: () -> Void
    @State private var showHint = false

    var body: some View {
        Label(showHint ? "Hold to go back" : "Parents", systemImage: "lock.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(.thinMaterial))
            .contentShape(Capsule())
            .onTapGesture {
                showHint = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showHint = false
                }
            }
            .onLongPressGesture(minimumDuration: 1.0) { onUnlock() }
            .accessibilityLabel("Parents. Press and hold to go back.")
    }
}

/// PRD §6.11 — one tap to choose. Big colorful tiles, no text entry.
struct WhatsNextChooser: View {
    let activities: [TransitionActivity]
    let chosen: TransitionActivity?
    let onChoose: (TransitionActivity) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(activities) { activity in
                let isChosen = chosen == activity
                let tint = Theme.color(for: activity)
                Button { onChoose(activity) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: activity.symbolName).font(.title)
                        Text(activity.displayName).font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(isChosen ? .white : tint)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isChosen ? tint : tint.opacity(0.15)))
                    .overlay(alignment: .topTrailing) {
                        if isChosen {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                    }
                    .scaleEffect(isChosen ? 1.03 : 1)
                }
                .buttonStyle(.plain)
                .animation(.spring(duration: 0.25), value: isChosen)
            }
        }
    }
}

/// PRD §6.12 — remind the child what they picked, warmly, without offering to change it (§7.4).
struct ChosenActivityBadge: View {
    let activity: TransitionActivity

    var body: some View {
        Label("Next: \(activity.displayName)", systemImage: activity.symbolName)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Capsule().fill(Theme.color(for: activity)))
    }
}

#Preview("Idle") {
    NavigationStack { ChildTimerView(services: .mocks(storage: previewStorage())) }
}

private func previewStorage() -> InMemoryScreenTimeStorageService {
    let s = InMemoryScreenTimeStorageService()
    try? s.save(ChildProfile(name: "Ivy"))
    return s
}
