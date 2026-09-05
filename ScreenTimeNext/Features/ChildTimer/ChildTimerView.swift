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
    @State private var viewModel: ChildTimerViewModel

    init(services: ServiceContainer) {
        _viewModel = State(initialValue: ChildTimerViewModel(services: services))
    }

    private var snapshot: ChildSessionSnapshot { viewModel.snapshot }
    private var name: String { viewModel.childName }
    private var color: Color { Theme.color(for: snapshot.state) }

    var body: some View {
        ZStack {
            Theme.gradient(for: snapshot.state).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    content
                    if let error = viewModel.errorText {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
        }
        .animation(.easeInOut, value: snapshot.state)
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
            Spacer(minLength: 24)
            Image(systemName: "sun.max.fill").font(.system(size: 64)).foregroundStyle(Theme.sun)
            headline("Hi \(name)!")
            subline("You have \(minutesText(snapshot.remainingSeconds)) of screen time today.")
            Button { viewModel.start() } label: { Label("Start", systemImage: "play.fill") }
                .buttonStyle(PillButtonStyle(color: Theme.mint))
                .padding(.top, 8)

        case .active:
            ring(big: true)
            subline("Enjoy your screen time, \(name).")

        case .extended:
            ring(big: true)
            subline("You've got some extra time, \(name)!")

        case .firstWarning:
            headline("\(warningMinutes) left 👋")
            subline("You're almost done. What do you want to do next?")
            WhatsNextChooser(
                activities: viewModel.availableActivities,
                chosen: snapshot.chosenActivity,
                onChoose: { viewModel.choose($0) }
            )
            ring(big: false)

        case .secondWarning:
            headline("\(warningMinutes) left")
            subline("Time to finish up what you're doing.")
            if let activity = snapshot.chosenActivity { ChosenActivityBadge(activity: activity) }
            ring(big: false)

        case .finalWarning:
            headline(snapshot.activeWarningMinutes == 1 ? "One more minute!" : "\(warningMinutes) left!")
            subline("Finish your game.")
            if let activity = snapshot.chosenActivity { ChosenActivityBadge(activity: activity) }
            ring(big: true)

        case .finished:
            TimesUpView(childName: name,
                        chosenActivity: snapshot.chosenActivity,
                        budgetSpentEarlier: snapshot.window == nil)
        }
    }

    // MARK: Pieces

    private var warningMinutes: String { minutesText((snapshot.activeWarningMinutes ?? 1) * 60) }

    private func headline(_ text: String) -> some View {
        Text(text).font(.system(.largeTitle, design: .rounded).bold())
    }

    private func subline(_ text: String) -> some View {
        Text(text).font(.title3).foregroundStyle(.secondary)
    }

    /// Countdown inside a progress ring; the ring is remaining ÷ window total.
    private func ring(big: Bool) -> some View {
        let total = max(1, snapshot.window?.totalSeconds ?? 1)
        let fraction = Double(snapshot.remainingSeconds) / Double(total)
        let size: CGFloat = big ? 280 : 180
        return ZStack {
            ProgressRing(fraction: fraction, lineWidth: big ? 18 : 12, color: color)
            VStack(spacing: 4) {
                Text(Self.clock(snapshot.remainingSeconds))
                    .font(.system(size: big ? 64 : 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("left").font(.headline).foregroundStyle(.secondary)
            }
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
