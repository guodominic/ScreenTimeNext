//  Mascot.swift
//  ScreenTimeNext
//
//  "Pip" — the friendly face of ScreenTimeNext. Drawn entirely with SwiftUI shapes (no assets),
//  so it tints to any state colour, scales to any size and costs nothing in the bundle.
//
//  Why a mascot: a parental-control app that looks like a settings screen reads as enforcement.
//  A character who greets the child, waits with them, wonders what's next and cheers at the end
//  makes the same product feel like company — the premise (§2: a supportive guide, not a
//  punishment system) expressed in pixels rather than copy.
//
//  Construction: ground shadow ▸ legs ▸ body ▸ far arm ▸ head (gradient + gloss) ▸ ears ▸ face
//  (brows, eyes with tracking pupils, cheeks, mouth) ▸ near arm ▸ antenna. Kawaii proportions —
//  head ≈ 60% of the figure. Idle motion is a bob with squash-and-stretch, plus a slow arm swing
//  and irregular blinking; `.cheering` adds a jump. All motion stops under Reduce Motion.

import SwiftUI

enum MascotMood: Hashable {
    case happy       // idle, greeting — waves
    case playing     // session running — arms swing
    case thinking    // reminder — head tilt, eyes up, one hand at the chin
    case hurrying    // final minute — wide eyes, open mouth, quick bounce
    case cheering    // finished — both arms up, jumping
    case sleepy      // nothing left today — eyes closed, gentle sway
}

struct Mascot: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 120
    var tint: Color = Theme.sky
    /// Set false inside cards where a moving character would look unsettled.
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false      // drives the idle loop
    @State private var blink = false
    @State private var glance = false     // occasional look to the side

    private var motionOK: Bool { animated && !reduceMotion }

    // Proportions, all relative to `size`.
    private var head: CGFloat { size * 0.60 }
    private var bodyW: CGFloat { size * 0.44 }
    private var bodyH: CGFloat { size * 0.32 }

    private var bobbing: Bool { motionOK && phase }

    /// Vertical travel of the idle loop; `.cheering` and `.hurrying` are springier.
    private var lift: CGFloat {
        switch mood {
        case .cheering: return size * 0.075
        case .hurrying: return size * 0.05
        case .sleepy:   return size * 0.012
        default:        return size * 0.028
        }
    }

    private var loopDuration: Double {
        switch mood {
        case .hurrying: return 0.42
        case .cheering: return 0.55
        case .sleepy:   return 2.6
        default:        return 1.5
        }
    }

    var body: some View {
        ZStack {
            groundShadow
            figure
                .offset(y: bobbing ? -lift : lift)
                // Squash on the way down, stretch on the way up — the trick that makes a
                // bouncing shape feel alive rather than merely translated.
                .scaleEffect(x: bobbing ? 0.98 : 1.03, y: bobbing ? 1.03 : 0.97, anchor: .bottom)
                .rotationEffect(.degrees(mood == .sleepy && bobbing ? 3 : mood == .sleepy ? -3 : 0))
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: loopDuration).repeatForever(autoreverses: true), value: phase)
        .onAppear {
            guard motionOK else { return }
            phase = true
            runBlinkLoop()
        }
        .accessibilityHidden(true)
    }

    // MARK: Figure

    private var figure: some View {
        ZStack {
            legs
            bodyShape
            arm(side: -1, far: true)
            headShape
            ears
            face
            arm(side: 1, far: false)
            antenna
        }
    }

    private var groundShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.10))
            .frame(width: size * (bobbing ? 0.34 : 0.44), height: size * 0.055)
            .blur(radius: size * 0.012)
            .offset(y: size * 0.46)
            .animation(.easeInOut(duration: loopDuration).repeatForever(autoreverses: true), value: phase)
    }

    private var legs: some View {
        HStack(spacing: size * 0.10) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: size * 0.085, height: size * 0.11)
            }
        }
        .offset(y: size * 0.40)
    }

    private var bodyShape: some View {
        RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
            .fill(
                LinearGradient(colors: [tint.opacity(0.92), tint.opacity(0.70)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: bodyW, height: bodyH)
            .overlay(
                // A little belly patch, so the body isn't a flat slab.
                Ellipse()
                    .fill(.white.opacity(0.22))
                    .frame(width: bodyW * 0.55, height: bodyH * 0.55)
                    .offset(y: bodyH * 0.10)
            )
            .offset(y: size * 0.26)
    }

    private var headShape: some View {
        Circle()
            .fill(
                LinearGradient(colors: [tint.opacity(1.0), tint.opacity(0.78)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: head, height: head)
            .overlay(
                // Gloss highlight — the single cheapest thing that makes a flat circle look round.
                Ellipse()
                    .fill(.white.opacity(0.32))
                    .frame(width: head * 0.34, height: head * 0.20)
                    .rotationEffect(.degrees(-22))
                    .offset(x: -head * 0.19, y: -head * 0.26)
            )
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: size * 0.014))
            .shadow(color: tint.opacity(0.35), radius: size * 0.07, y: size * 0.035)
            .offset(y: -size * 0.08)
            .rotationEffect(.degrees(headTilt), anchor: .bottom)
    }

    private var headTilt: Double {
        switch mood {
        case .thinking: return -9
        case .sleepy:   return 7
        default:        return 0
        }
    }

    private var ears: some View {
        HStack(spacing: head * 0.86) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .fill(tint.opacity(0.88))
                    .frame(width: size * 0.09, height: size * 0.09)
            }
        }
        .offset(y: -size * 0.08)
        .rotationEffect(.degrees(headTilt), anchor: .bottom)
    }

    private var antenna: some View {
        VStack(spacing: -size * 0.005) {
            Circle()
                .fill(Theme.sun)
                .frame(width: size * 0.075, height: size * 0.075)
                .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: size * 0.008))
                .shadow(color: Theme.sun.opacity(0.6), radius: size * 0.03)
            Capsule()
                .fill(tint.opacity(0.9))
                .frame(width: size * 0.022, height: size * 0.10)
        }
        .offset(y: -size * 0.42)
        .rotationEffect(.degrees(bobbing ? 7 : -7), anchor: .bottom)
        .animation(.easeInOut(duration: loopDuration * 1.1).repeatForever(autoreverses: true), value: phase)
    }

    // MARK: Face

    private var face: some View {
        VStack(spacing: head * 0.055) {
            brows
            HStack(spacing: head * 0.24) {
                eye
                eye
            }
            .overlay(cheeks)
            mouth
        }
        .offset(y: -size * 0.07)
        .rotationEffect(.degrees(headTilt), anchor: .bottom)
    }

    @ViewBuilder
    private var brows: some View {
        HStack(spacing: head * 0.22) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: head * 0.20, height: head * 0.045)
                    .rotationEffect(.degrees(browAngle * (i == 0 ? 1 : -1)))
            }
        }
        .opacity(mood == .sleepy ? 0.4 : 1)
        .frame(height: head * 0.05)
    }

    private var browAngle: Double {
        switch mood {
        case .thinking: return -16
        case .hurrying: return -22
        case .cheering: return 12
        default:        return -6
        }
    }

    @ViewBuilder
    private var eye: some View {
        let w = head * 0.24
        if mood == .sleepy || blink {
            // A contented closed arc rather than a flat line.
            ClosedEye()
                .stroke(.white, style: StrokeStyle(lineWidth: head * 0.045, lineCap: .round))
                .frame(width: w, height: w * 0.4)
        } else {
            ZStack {
                Circle().fill(.white).frame(width: w, height: w)
                Circle()
                    .fill(Color(red: 0.15, green: 0.18, blue: 0.27))
                    .frame(width: w * (mood == .hurrying ? 0.62 : 0.52),
                           height: w * (mood == .hurrying ? 0.62 : 0.52))
                    .offset(x: pupilOffset.x * w, y: pupilOffset.y * w)
                Circle().fill(.white)
                    .frame(width: w * 0.20, height: w * 0.20)
                    .offset(x: w * 0.14, y: -w * 0.16)
            }
            .frame(width: w, height: w)
        }
    }

    /// Pupils drift: up-and-aside when thinking, a slow glance the rest of the time.
    private var pupilOffset: (x: CGFloat, y: CGFloat) {
        switch mood {
        case .thinking: return (0.14, -0.16)
        case .hurrying: return (0, 0.04)
        case .cheering: return (0, -0.04)
        default:        return (glance ? 0.10 : -0.06, 0.06)
        }
    }

    private var cheeks: some View {
        HStack(spacing: head * 0.46) {
            ForEach(0..<2, id: \.self) { _ in
                Ellipse()
                    .fill(Theme.coral.opacity(0.42))
                    .frame(width: head * 0.16, height: head * 0.10)
                    .blur(radius: head * 0.012)
            }
        }
        .offset(y: head * 0.16)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .cheering, .hurrying:
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.34, green: 0.15, blue: 0.21))
                    .frame(width: head * (mood == .cheering ? 0.30 : 0.24),
                           height: head * (mood == .cheering ? 0.24 : 0.20))
                Ellipse()                       // tongue
                    .fill(Theme.coral.opacity(0.85))
                    .frame(width: head * 0.14, height: head * 0.08)
                    .offset(y: head * 0.06)
            }
        case .thinking:
            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: head * 0.14, height: head * 0.045)
                .offset(x: head * 0.06)
        case .sleepy:
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: head * 0.10, height: head * 0.10)
        default:
            Smile()
                .stroke(.white, style: StrokeStyle(lineWidth: head * 0.052, lineCap: .round))
                .frame(width: head * 0.34, height: head * 0.15)
        }
    }

    // MARK: Arms

    private func arm(side: CGFloat, far: Bool) -> some View {
        Capsule()
            .fill(tint.opacity(far ? 0.72 : 0.92))
            .frame(width: size * 0.075, height: size * 0.24)
            .overlay(
                Circle()                        // a little hand
                    .fill(tint.opacity(far ? 0.72 : 0.95))
                    .frame(width: size * 0.085, height: size * 0.085)
                    .offset(y: size * 0.10)
            )
            .offset(x: side * size * 0.24, y: size * 0.20)
            .rotationEffect(.degrees(armAngle(side: side)), anchor: .top)
            .animation(.easeInOut(duration: loopDuration).repeatForever(autoreverses: true), value: phase)
    }

    private func armAngle(side: CGFloat) -> Double {
        let outward = Double(side)
        switch mood {
        case .cheering:
            return outward * (bobbing ? 155 : 140)
        case .happy:
            // One arm waves, the other rests.
            return side > 0 ? (bobbing ? 145 : 115) : 12
        case .playing:
            return outward * (bobbing ? 28 : 12)
        case .hurrying:
            return outward * (bobbing ? 55 : 30)
        case .thinking:
            return side > 0 ? 128 : 10          // hand up near the chin
        case .sleepy:
            return outward * 6
        }
    }

    // MARK: Loops

    private func runBlinkLoop() {
        Task { @MainActor in
            while motionOK {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.4...5.5)))
                guard motionOK else { return }
                withAnimation(.easeInOut(duration: 0.07)) { blink = true }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeInOut(duration: 0.07)) { blink = false }
                if Bool.random() {
                    withAnimation(.easeInOut(duration: 0.5)) { glance.toggle() }
                }
            }
        }
    }
}

/// A downward arc — Pip's closed, contented eye.
private struct ClosedEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.8))
        return p
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 28) {
            ForEach([MascotMood.happy, .playing, .thinking, .hurrying, .cheering, .sleepy], id: \.self) { mood in
                VStack(spacing: 8) {
                    Mascot(mood: mood, size: 140, tint: Theme.sky)
                    Text(String(describing: mood)).font(.caption.weight(.semibold))
                }
            }
        }
        .padding(28)
    }
}
