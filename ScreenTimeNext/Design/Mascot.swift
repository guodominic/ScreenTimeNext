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

/// Every mood is positive. Pip is never anxious and never scolds — urgency is carried entirely by
/// colour (D-017). A worried face at the one-minute mark would teach a child that the ending is
/// something to dread, which is the opposite of what this product is for (§7).
enum MascotMood: Hashable {
    case happy       // idle, greeting — waves
    case playing     // session running — arms swing
    case thinking    // reminder — head tilt, eyes up, curious
    case excited     // final stretch — big grin, bouncy, looking forward to what's next
    case cheering    // finished — both arms up, jumping
    case sleepy      // nothing left today — eyes closed, peaceful
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

    /// D-073 — built once, named, reused. It appeared inline in three chains, and each one made
    /// the checker solve it again as part of a larger system.
    private var idleLoop: Animation {
        .easeInOut(duration: loopDuration).repeatForever(autoreverses: true)
    }

    private var antennaLoop: Animation {
        .easeInOut(duration: loopDuration * 1.1).repeatForever(autoreverses: true)
    }

    /// Vertical travel of the idle loop; `.cheering` and `.excited` are springier.
    private var lift: CGFloat {
        switch mood {
        case .cheering: return size * 0.075
        case .excited: return size * 0.06
        case .sleepy:   return size * 0.012
        default:        return size * 0.028
        }
    }

    private var loopDuration: Double {
        switch mood {
        case .excited: return 0.50
        case .cheering: return 0.55
        case .sleepy:   return 2.6
        default:        return 1.5
        }
    }

    /// Sleepy Pip sways; everyone else stays upright.
    private var sway: Double {
        guard mood == .sleepy else { return 0 }
        return bobbing ? 3 : -3
    }

    private var animatedFigure: some View {
        // Squash on the way down, stretch on the way up — the trick that makes a bouncing shape
        // feel alive rather than merely translated.
        let sx: CGFloat = bobbing ? 0.98 : 1.03
        let sy: CGFloat = bobbing ? 1.03 : 0.97
        return figure
            .offset(y: bobbing ? -lift : lift)
            .scaleEffect(x: sx, y: sy, anchor: .bottom)
            .rotationEffect(.degrees(sway))
    }

    var body: some View {
        ZStack {
            groundShadow
            animatedFigure
        }
        .frame(width: size, height: size)
        .animation(idleLoop, value: phase)
        .onAppear {
            guard motionOK else { return }
            phase = true
            runBlinkLoop()
        }
        .accessibilityHidden(true)
    }

    // MARK: Figure

    /// D-073 — two groups of four rather than one of eight.
    ///
    /// A `ZStack` of eight children is a `TupleView` of eight distinct opaque types, and the
    /// builder has to solve all of them together. The drawing order is unchanged — back half,
    /// then front half — so the picture is identical.
    private var figure: some View {
        ZStack {
            behindTheFace
            theFace
        }
    }

    private var behindTheFace: some View {
        ZStack {
            legs
            bodyShape
            arm(side: -1, far: true)
            headShape
        }
    }

    private var theFace: some View {
        ZStack {
            ears
            face
            arm(side: 1, far: false)
            antenna
        }
    }

    private var groundShadow: some View {
        let spread: CGFloat = bobbing ? 0.34 : 0.44
        let shadowW: CGFloat = size * spread
        let shadowH: CGFloat = size * 0.055
        let softness: CGFloat = size * 0.012
        let below: CGFloat = size * 0.46
        return Ellipse()
            .fill(Color.black.opacity(0.10))
            .frame(width: shadowW, height: shadowH)
            .blur(radius: softness)
            .offset(y: below)
            .animation(idleLoop, value: phase)
    }

    private var legs: some View {
        let gap: CGFloat = size * 0.10
        let legW: CGFloat = size * 0.085
        let legH: CGFloat = size * 0.11
        let down: CGFloat = size * 0.40
        return HStack(spacing: gap) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: legW, height: legH)
            }
        }
        .offset(y: down)
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(colors: [tint.opacity(0.92), tint.opacity(0.70)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// A little belly patch, so the body isn't a flat slab.
    private var bellyPatch: some View {
        let w: CGFloat = bodyW * 0.55
        let h: CGFloat = bodyH * 0.55
        let down: CGFloat = bodyH * 0.10
        return Ellipse()
            .fill(Color.white.opacity(0.22))
            .frame(width: w, height: h)
            .offset(y: down)
    }

    private var bodyShape: some View {
        let corner: CGFloat = size * 0.16
        let down: CGFloat = size * 0.26
        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(bodyGradient)
            .frame(width: bodyW, height: bodyH)
            .overlay(bellyPatch)
            .offset(y: down)
    }

    private var headGradient: LinearGradient {
        LinearGradient(colors: [tint.opacity(1.0), tint.opacity(0.78)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Gloss highlight — the cheapest thing that makes a flat circle look round.
    private var headGloss: some View {
        let w: CGFloat = head * 0.34
        let h: CGFloat = head * 0.20
        let dx: CGFloat = -head * 0.19
        let dy: CGFloat = -head * 0.26
        return Ellipse()
            .fill(Color.white.opacity(0.32))
            .frame(width: w, height: h)
            .rotationEffect(.degrees(-22))
            .offset(x: dx, y: dy)
    }

    /// D-073 (revised) — THIS is the expression the compiler gave up on, twice.
    ///
    /// Eight generic modifiers on one `Circle()`, two of them `overlay`s carrying their own
    /// chains, and four `CGFloat` products written inline. Every modifier returns a fresh opaque
    /// type, so the checker was solving one system with a dozen unknowns in it. The first D-073
    /// pass fixed five other expressions in this file and missed the longest one — which is the
    /// argument for naming every number rather than trimming until it happens to pass.
    ///
    /// Same circle, same order, same picture.
    private var headShape: some View {
        let d: CGFloat = head
        let ring: CGFloat = size * 0.014
        let glow: CGFloat = size * 0.07
        let glowDrop: CGFloat = size * 0.035
        let raise: CGFloat = -size * 0.08
        let outline = Circle().stroke(Color.white.opacity(0.35), lineWidth: ring)
        let ball = Circle()
            .fill(headGradient)
            .frame(width: d, height: d)

        return ball
            .overlay(headGloss)
            .overlay(outline)
            .shadow(color: tint.opacity(0.35), radius: glow, y: glowDrop)
            .offset(y: raise)
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
        let gap: CGFloat = head * 0.86
        let earD: CGFloat = size * 0.09
        let raise: CGFloat = -size * 0.08
        return HStack(spacing: gap) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .fill(tint.opacity(0.88))
                    .frame(width: earD, height: earD)
            }
        }
        .offset(y: raise)
        .rotationEffect(.degrees(headTilt), anchor: .bottom)
    }

    private var antenna: some View {
        let overlap: CGFloat = -size * 0.005
        let bulbD: CGFloat = size * 0.075
        let bulbRing: CGFloat = size * 0.008
        let bulbGlow: CGFloat = size * 0.03
        let stalkW: CGFloat = size * 0.022
        let stalkH: CGFloat = size * 0.10
        let raise: CGFloat = -size * 0.42
        let tilt: Double = bobbing ? 7 : -7
        let bulb = Circle()
            .fill(Theme.sun)
            .frame(width: bulbD, height: bulbD)
        let stalk = Capsule()
            .fill(tint.opacity(0.9))
            .frame(width: stalkW, height: stalkH)

        return VStack(spacing: overlap) {
            bulb
                .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: bulbRing))
                .shadow(color: Theme.sun.opacity(0.6), radius: bulbGlow)
            stalk
        }
        .offset(y: raise)
        .rotationEffect(.degrees(tilt), anchor: .bottom)
        .animation(antennaLoop, value: phase)
    }

    // MARK: Face

    private var face: some View {
        let rowGap: CGFloat = head * 0.055
        let eyeGap: CGFloat = head * 0.24
        let raise: CGFloat = -size * 0.07
        let eyes = HStack(spacing: eyeGap) {
            eye
            eye
        }
        return VStack(spacing: rowGap) {
            brows
            eyes.overlay(cheeks)
            mouth
        }
        .offset(y: raise)
        .rotationEffect(.degrees(headTilt), anchor: .bottom)
    }

    /// D-073 — no longer `@ViewBuilder`: the body is one expression with an explicit `return`,
    /// which disables the builder anyway. Keeping the attribute earned a warning and nothing else.
    private var brows: some View {
        let gap: CGFloat = head * 0.22
        let browW: CGFloat = head * 0.20
        let browH: CGFloat = head * 0.045
        let rowH: CGFloat = head * 0.05
        let dimmed: Double = mood == .sleepy ? 0.4 : 1
        return HStack(spacing: gap) {
            ForEach(0..<2, id: \.self) { i in
                let mirror: Double = i == 0 ? 1 : -1
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: browW, height: browH)
                    .rotationEffect(.degrees(browAngle * mirror))
            }
        }
        .opacity(dimmed)
        .frame(height: rowH)
    }

    /// Brows always read as friendly: raised and open, never drawn together (which reads as worry).
    private var browAngle: Double {
        switch mood {
        case .thinking: return -14
        case .excited: return 14
        case .cheering: return 16
        default:        return 8
        }
    }

    private var eyeW: CGFloat { head * 0.24 }
    private var pupilW: CGFloat { eyeW * (mood == .excited ? 0.60 : 0.52) }
    private var eyesClosed: Bool { mood == .sleepy || blink }

    private var openEye: some View {
        let w: CGFloat = eyeW
        let p: CGFloat = pupilW
        let shine: CGFloat = w * 0.20
        let dx: CGFloat = pupilOffset.x * w
        let dy: CGFloat = pupilOffset.y * w
        return ZStack {
            Circle().fill(Color.white).frame(width: w, height: w)
            Circle()
                .fill(Color(red: 0.15, green: 0.18, blue: 0.27))
                .frame(width: p, height: p)
                .offset(x: dx, y: dy)
            Circle().fill(Color.white)
                .frame(width: shine, height: shine)
                .offset(x: w * 0.14, y: -w * 0.16)
        }
        .frame(width: w, height: w)
    }

    /// A contented closed arc rather than a flat line.
    private var closedEye: some View {
        ClosedEye()
            .stroke(Color.white, style: StrokeStyle(lineWidth: head * 0.045, lineCap: .round))
            .frame(width: eyeW, height: eyeW * 0.4)
    }

    @ViewBuilder
    private var eye: some View {
        if eyesClosed { closedEye } else { openEye }
    }

    /// Pupils drift: up-and-aside when thinking, a slow glance the rest of the time.
    private var pupilOffset: (x: CGFloat, y: CGFloat) {
        switch mood {
        case .thinking:  return (x: 0.14, y: -0.16)
        case .excited:   return (x: 0, y: -0.06)
        case .cheering:  return (x: 0, y: -0.04)
        default:
            // D-073 — pulled out of the tuple: a ternary inside a tuple element inside a switch
            // is three nested inference problems for one number.
            let drift: CGFloat = glance ? 0.10 : -0.06
            return (x: drift, y: 0.06)
        }
    }

    private var cheeks: some View {
        let gap: CGFloat = head * 0.46
        let cheekW: CGFloat = head * 0.16
        let cheekH: CGFloat = head * 0.10
        let softness: CGFloat = head * 0.012
        let down: CGFloat = head * 0.16
        return HStack(spacing: gap) {
            ForEach(0..<2, id: \.self) { _ in
                Ellipse()
                    .fill(Theme.coral.opacity(0.42))
                    .frame(width: cheekW, height: cheekH)
                    .blur(radius: softness)
            }
        }
        .offset(y: down)
        .allowsHitTesting(false)
    }

    private var openMouth: some View {
        let wide: Bool = mood == .cheering
        let wRatio: CGFloat = wide ? 0.30 : 0.24
        let hRatio: CGFloat = wide ? 0.24 : 0.20
        let mw: CGFloat = head * wRatio
        let mh: CGFloat = head * hRatio
        let tongueW: CGFloat = head * 0.14
        let tongueH: CGFloat = head * 0.08
        let tongueDrop: CGFloat = head * 0.06
        return ZStack {
            Ellipse()
                .fill(Color(red: 0.34, green: 0.15, blue: 0.21))
                .frame(width: mw, height: mh)
            Ellipse()                       // tongue
                .fill(Theme.coral.opacity(0.85))
                .frame(width: tongueW, height: tongueH)
                .offset(y: tongueDrop)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .cheering, .excited:
            openMouth
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

    private func hand(far: Bool) -> some View {
        let d: CGFloat = size * 0.085
        let down: CGFloat = size * 0.10
        let shade: Double = far ? 0.72 : 0.95
        return Circle()
            .fill(tint.opacity(shade))
            .frame(width: d, height: d)
            .offset(y: down)
    }

    private func arm(side: CGFloat, far: Bool) -> some View {
        let w: CGFloat = size * 0.075
        let h: CGFloat = size * 0.24
        let shade: Double = far ? 0.72 : 0.92
        let dx: CGFloat = side * size * 0.24
        let dy: CGFloat = size * 0.20
        let angle: Double = armAngle(side: side)
        let limb = Capsule()
            .fill(tint.opacity(shade))
            .frame(width: w, height: h)
            .overlay(hand(far: far))

        return limb
            .offset(x: dx, y: dy)
            .rotationEffect(.degrees(angle), anchor: .top)
            .animation(idleLoop, value: phase)
    }

    /// D-073 — every literal spelled `Double`. They were untyped integers inside ternaries inside
    /// a `Double` return, which is eleven separate little inference problems in one function.
    private func armAngle(side: CGFloat) -> Double {
        let outward = Double(side)
        let up: Bool = bobbing
        let leading: Bool = side > 0
        switch mood {
        case .cheering:
            let sweep: Double = up ? 155 : 140
            return outward * sweep
        case .happy:
            // One arm waves, the other rests.
            let wave: Double = up ? 145 : 115
            return leading ? wave : 12
        case .playing:
            let swing: Double = up ? 28 : 12
            return outward * swing
        case .excited:
            // Arms swinging up — eagerness, not panic.
            let swing: Double = up ? 95 : 60
            return outward * swing
        case .thinking:
            return leading ? 128 : 10           // hand up near the chin
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

/// D-073 — the preview's own view, hoisted out of the `#Preview` expression.
///
/// It was one expression: a ScrollView around a LazyVGrid around a ForEach over an array literal
/// of implicit members. Every leading dot in `[MascotMood.happy, .playing, …]` stays an open
/// question until the whole nest resolves, and the nest is five levels deep — which is how a file
/// that draws a cartoon ends up being the one the type-checker gives up on.
private struct MascotMoodGallery: View {
    private let moods: [MascotMood] = [.happy, .playing, .thinking, .excited, .cheering, .sleepy]
    private let columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(moods, id: \.self) { mood in
                    cell(for: mood)
                }
            }
            .padding(28)
        }
    }

    private func cell(for mood: MascotMood) -> some View {
        VStack(spacing: 8) {
            Mascot(mood: mood, size: 140, tint: Theme.sky)
            Text(String(describing: mood)).font(.caption.weight(.semibold))
        }
    }
}

#Preview("Moods") {
    MascotMoodGallery()
}
