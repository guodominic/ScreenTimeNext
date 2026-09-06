//  WelcomeStepView.swift — PRD §6.1, D-016 / D-036
//
//  D-036 — the greeting no longer asks for a tap.
//
//  "Let's go" was a button whose only job was to agree with a screen nobody disagreed with: a
//  parent opening this app has a child waiting and already knows they want to set a timer. So the
//  greeting plays itself — Pip drops in, says hello, the words settle, and the flow walks on to
//  the time dial on its own. A tap anywhere skips straight there for the second time onward, when
//  the charm has worn off and the parent just wants the dial.
//
//  1.3 seconds, start to finish. A greeting that holds a parent for two-and-a-half seconds while a
//  child waits for the iPad is not charming, it is in the way — but under a second the words never
//  land. The three reveals finish by ~0.46s and the last beat is a moment to read them.
//
//  Reduce Motion still gets the whole thing, just without the movement, and still advances: the
//  animation is decoration, the advance is the behaviour.

import SwiftUI
import ScreenTimeNextCore

struct WelcomeStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far through the greeting we are. Each step reveals one thing.
    @State private var beat = 0
    /// The advance can be reached two ways (the timer and a tap) and must only happen once per
    /// visit — twice would push the time step onto the stack twice.
    ///
    /// Per VISIT is the part that was wrong. This is the root of the navigation stack, so SwiftUI
    /// keeps it alive while the time step sits on top of it and the flag survived the trip back:
    /// a parent who tapped Back landed on a greeting where nothing worked, with no way forward at
    /// all. `.onChange(of: viewModel.path)` resets it, rather than `.task` or `.onAppear`, because
    /// neither is guaranteed to run again for a root view that never actually went away.
    @State private var hasAdvanced = false
    /// Whether the greeting has already played. Coming back must NOT restart the animation and
    /// walk the parent forward again — that would be a screen they cannot stay on.
    @State private var hasPlayedOnce = false
    @State private var sparkle = false

    /// When each beat lands, and when the flow moves on. Front-loaded rather than spread evenly:
    /// all three reveals inside ~0.35s, then a breath, then the push.
    private var beatDelays: [Double] { reduceMotion ? [0, 0.12, 0.24] : [0, 0.24, 0.46] }
    private var totalDuration: Double { reduceMotion ? 0.8 : 1.3 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.sky.opacity(0.38), Color(.systemGroupedBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            PlayfulBackground(tint: Theme.sky, intensity: 1.0)

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    if sparkle { Sparkles(color: Theme.sun, count: 10, radius: 140) }
                    Mascot(mood: beat >= 3 ? .excited : .happy, size: 230, tint: Theme.sky)
                        .scaleEffect(beat >= 1 ? 1 : 0.55)
                        .opacity(beat >= 1 ? 1 : 0)
                        .rotationEffect(.degrees(beat >= 3 ? 0 : (beat >= 1 ? -4 : -14)))
                }

                Text("Hi, I'm Pip!")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .opacity(beat >= 2 ? 1 : 0)
                    .offset(y: beat >= 2 ? 0 : 16)

                Text("Let's make screen time end peacefully.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(beat >= 3 ? 1 : 0)
                    .offset(y: beat >= 3 ? 0 : 12)

                Spacer()
                // No progress hint and no button: under a second, a spinner would only flash.
            }
            .readableWidth(520)
        }
        // The whole screen skips ahead. No target to aim at, which is the point.
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hi, I'm Pip. Let's make screen time end peacefully.")
        .accessibilityHint("Tap to continue to the timer.")
        .accessibilityAddTraits(.isButton)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasPlayedOnce else { return }
            hasPlayedOnce = true
            await play()
        }
        .onChange(of: viewModel.path) { _, path in
            guard path.isEmpty else { return }
            // Back on the greeting. Show it settled and wait: a tap anywhere goes on again.
            hasAdvanced = false
            beat = beatDelays.count
        }
    }

    /// One `Task`, cancelled with the view. Beats rather than nested `withAnimation` completions,
    /// so a tap part-way through cannot leave the screen half-animated.
    ///
    /// The springs are longer than the gaps between beats on purpose: they overlap, so the three
    /// reveals read as one burst rather than three separate steps in under a second.
    private func play() async {
        var elapsed: Double = 0
        for (index, delay) in beatDelays.enumerated() {
            if delay > elapsed {
                do { try await Task.sleep(for: .seconds(delay - elapsed)) } catch { return }
                elapsed = delay
            }
            withAnimation(reduceMotion ? .easeOut(duration: 0.18)
                                       : .spring(response: 0.45, dampingFraction: 0.62)) {
                beat = index + 1
            }
            if index == 0 && !reduceMotion { sparkle = true }
        }
        if totalDuration > elapsed {
            do { try await Task.sleep(for: .seconds(totalDuration - elapsed)) } catch { return }
        }
        advance()
    }

    private func advance() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        viewModel.advance(to: .time)
    }
}

#Preview {
    NavigationStack { WelcomeStepView(viewModel: OnboardingViewModel(services: .mocks())) }
}
