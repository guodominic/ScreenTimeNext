//  Mascot.swift
//  ScreenTimeNext
//
//  "Pip" — the friendly face of ScreenTimeNext. Drawn entirely with SwiftUI shapes (no assets),
//  so it tints to any state color and scales to any size.
//
//  Why a mascot: a parental-control app that looks like a settings screen feels like enforcement.
//  A character that greets the child, waits with them, and cheers at the end makes the same
//  product feel like company. That is the whole premise (§2: a supportive guide, not a punishment
//  system) expressed in pixels rather than copy.
//
//  Pip echoes the app icon — round, warm, a little tuft on top — without reproducing it.

import SwiftUI

enum MascotMood: Equatable {
    case happy       // idle, greeting
    case playing     // session running
    case thinking    // first reminder — "what shall we do next?"
    case hurrying    // final minute
    case cheering    // finished
    case sleepy      // nothing left today
}

struct Mascot: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 120
    var tint: Color = Theme.sky
    /// Set false inside cards where a floating character would look unsettled.
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blink = false
    @State private var bob = false

    private var motionOK: Bool { animated && !reduceMotion }

    var body: some View {
        ZStack {
            body_
            face
            arms
            tuft
        }
        .frame(width: size, height: size)
        .offset(y: bob && motionOK ? -size * 0.03 : size * 0.03)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: bob)
        .onAppear {
            guard motionOK else { return }
            bob = true
            scheduleBlink()
        }
        .accessibilityHidden(true)
    }

    // MARK: Parts

    private var body_: some View {
        Ellipse()
            .fill(
                LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.75)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: size * 0.82, height: size * 0.78)
            .overlay(
                Ellipse().stroke(.white.opacity(0.5), lineWidth: size * 0.02)
            )
            .shadow(color: tint.opacity(0.35), radius: size * 0.08, y: size * 0.04)
    }

    private var tuft: some View {
        Capsule()
            .fill(tint)
            .frame(width: size * 0.06, height: size * 0.16)
            .rotationEffect(.degrees(-18))
            .offset(y: -size * 0.44)
            .overlay(
                Circle()
                    .fill(Theme.sun)
                    .frame(width: size * 0.09, height: size * 0.09)
                    .offset(x: -size * 0.03, y: -size * 0.52)
            )
    }

    private var face: some View {
        VStack(spacing: size * 0.055) {
            HStack(spacing: size * 0.17) {
                eye
                eye
            }
            mouth
        }
        .offset(y: size * 0.02)
    }

    @ViewBuilder
    private var eye: some View {
        if mood == .sleepy {
            // Closed, contented eyes.
            Capsule()
                .fill(.white)
                .frame(width: size * 0.11, height: size * 0.025)
        } else if blink {
            Capsule()
                .fill(.white)
                .frame(width: size * 0.11, height: size * 0.022)
        } else {
            ZStack {
                Circle().fill(.white).frame(width: size * 0.135, height: size * 0.135)
                Circle()
                    .fill(Color(red: 0.16, green: 0.19, blue: 0.28))
                    .frame(width: size * 0.075, height: size * 0.075)
                    .offset(x: mood == .thinking ? size * 0.022 : 0,
                            y: mood == .thinking ? -size * 0.012 : size * 0.008)
                Circle().fill(.white).frame(width: size * 0.028, height: size * 0.028)
                    .offset(x: size * 0.03, y: -size * 0.028)
            }
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .cheering, .hurrying:
            // Open, excited.
            Ellipse()
                .fill(Color(red: 0.35, green: 0.16, blue: 0.22))
                .frame(width: size * 0.17, height: size * 0.13)
        case .thinking:
            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: size * 0.09, height: size * 0.028)
        case .sleepy:
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: size * 0.07, height: size * 0.07)
        default:
            Smile()
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.032, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.1)
        }
    }

    @ViewBuilder
    private var arms: some View {
        switch mood {
        case .happy:
            arm(angle: -34, flipped: false)     // a little wave
        case .cheering:
            arm(angle: -58, flipped: false)
            arm(angle: 58, flipped: true)
        case .playing, .hurrying:
            arm(angle: -12, flipped: false)
            arm(angle: 12, flipped: true)
        case .thinking:
            arm(angle: 24, flipped: true)       // hand near the chin
        case .sleepy:
            EmptyView()
        }
    }

    private func arm(angle: Double, flipped: Bool) -> some View {
        Capsule()
            .fill(tint)
            .frame(width: size * 0.075, height: size * 0.26)
            .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: size * 0.016))
            .offset(x: (flipped ? 1 : -1) * size * 0.38, y: size * 0.02)
            .rotationEffect(.degrees(angle), anchor: .center)
    }

    private func scheduleBlink() {
        Task { @MainActor in
            while motionOK {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.5)))
                withAnimation(.easeInOut(duration: 0.08)) { blink = true }
                try? await Task.sleep(for: .milliseconds(130))
                withAnimation(.easeInOut(duration: 0.08)) { blink = false }
            }
        }
    }
}

/// A simple upward curve — Pip's smile.
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY * 1.9))
        return p
    }
}

#Preview("Moods") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach([MascotMood.happy, .playing, .thinking, .hurrying, .cheering, .sleepy], id: \.self) { mood in
                HStack(spacing: 20) {
                    Mascot(mood: mood, size: 110, tint: Theme.sky)
                    Text(String(describing: mood)).font(.headline)
                }
            }
        }
        .padding()
    }
}
