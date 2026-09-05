//  ChildTimerView.swift
//  ScreenTimeNext
//
//  Task 007 — PRD §6.10–§6.14, §7. Large remaining time, minimal controls, friendly language,
//  state-driven. No settings, no authorization detail, nothing technical on this screen.
//  Task 009 fills the "what's next" slot; Task 015 expands the finished state.

import SwiftUI
import ScreenTimeNextCore

struct ChildTimerView: View {
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ChildTimerViewModel

    init(services: ServiceContainer) {
        _viewModel = State(initialValue: ChildTimerViewModel(services: services))
    }

    private var snapshot: ChildSessionSnapshot { viewModel.snapshot }
    private var name: String { viewModel.childName }

    var body: some View {
        ZStack {
            tint.opacity(0.12).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                content
                Spacer()
                if let error = viewModel.errorText {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(32)
            .multilineTextAlignment(.center)
        }
        .animation(.easeInOut, value: snapshot.displayState)
        .onAppear { viewModel.appeared() }
        .onDisappear { viewModel.disappeared() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refresh() }
        }
        .navigationBarBackButtonHidden(snapshot.window != nil)   // no way out mid-session (§7.6)
    }

    // MARK: States

    @ViewBuilder
    private var content: some View {
        switch snapshot.displayState {
        case .idle:
            headline("Hi \(name)!")
            subline("You have \(minutes(snapshot.remainingSeconds)) of screen time today.")
            Button {
                viewModel.start()
            } label: {
                Text("Start")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .active, .extended:
            bigTime(snapshot.remainingSeconds)
            subline("Enjoy your screen time, \(name).")

        case .warning10:
            headline("10 minutes left 👋")
            subline("You're almost done. What do you want to do next?")
            WhatsNextSlot()
            smallTime(snapshot.remainingSeconds)

        case .warning5:
            headline("5 minutes left")
            subline("Time to finish up what you're doing.")
            smallTime(snapshot.remainingSeconds)

        case .warning1:
            headline("One more minute!")
            subline("Finish your game.")
            bigTime(snapshot.remainingSeconds)

        case .finished:
            headline("Screen time is finished ❤️")
            subline(snapshot.window == nil
                    ? "You've used today's screen time. See you tomorrow, \(name)!"
                    : "Nice job, \(name). Let's do something else now.")
        }
    }

    // MARK: Pieces

    private func headline(_ text: String) -> some View {
        Text(text).font(.largeTitle.bold())
    }

    private func subline(_ text: String) -> some View {
        Text(text).font(.title3).foregroundStyle(.secondary)
    }

    private func bigTime(_ seconds: Int) -> some View {
        Text(Self.clock(seconds))
            .font(.system(size: 88, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private func smallTime(_ seconds: Int) -> some View {
        Text(Self.clock(seconds))
            .font(.system(size: 44, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(.secondary)
    }

    private func minutes(_ seconds: Int) -> String {
        let m = seconds / 60
        return m == 1 ? "1 minute" : "\(m) minutes"
    }

    /// m:ss up to an hour, then h:mm:ss. Budgets go to 120 minutes (§6.5).
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    private var tint: Color {
        switch snapshot.displayState {
        case .idle, .active, .extended: return .accentColor
        case .warning10: return .yellow
        case .warning5, .warning1: return .orange
        case .finished: return .pink
        }
    }
}

/// Task 009 replaces this with the child's activity chooser. Kept as a named slot so the timer's
/// layout does not change when it arrives.
struct WhatsNextSlot: View {
    var body: some View {
        Text("Pick something fun for after")
            .font(.headline)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
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
