//  PipMark.swift
//  ScreenTimeNextWidgets
//
//  D-019 — Pip in the Dynamic Island, the Lock Screen and the status area, instead of an SF Symbol.
//
//  Why a second drawing of the mascot rather than reusing `Mascot.swift`: that file lives in the
//  app target, and a widget extension is a separate binary. Sharing it would mean moving it into
//  the package (which is deliberately framework-free — no SwiftUI) or adding it to both targets.
//  A widget mark also has different needs: it renders at 16–24pt inside a black pill, is often
//  drawn in a single tint by the system, and must survive `.widgetAccentedRenderingMode`. So this
//  is a compact MARK — Pip's head and antenna only — kept in step with the app's mascot by hand.
//
//  Everything is a SwiftUI shape: no assets, no image scaling, crisp at any size.

import SwiftUI

/// Pip's expression, mirroring the app's `MascotMood` for the states a widget can be in.
enum PipMarkMood {
    case playing     // session running
    case thinking    // a reminder is up
    case excited     // last stretch
    case cheering    // finished
    case sleepy      // nothing left today

    init(stateName: String) {
        switch stateName {
        case "firstWarning":  self = .thinking
        case "secondWarning": self = .thinking
        case "finalWarning":  self = .excited
        case "finished":      self = .cheering
        default:              self = .playing
        }
    }
}

/// Pip's head, drawn to read at 16pt. `tint` colours the head; the face is always dark ink so it
/// stays legible against every state colour.
struct PipMark: View {
    var mood: PipMarkMood = .playing
    var size: CGFloat = 22
    var tint: Color = .white
    /// When true the whole mark is drawn in `tint` alone (for the system's monochrome treatments).
    var monochrome: Bool = false

    private var ink: Color { monochrome ? tint.opacity(0.35) : Color.black.opacity(0.72) }

    var body: some View {
        ZStack {
            antenna
            head
            face
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: Pieces

    private var antenna: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(monochrome ? tint : tint.opacity(0.95))
                .frame(width: size * 0.16, height: size * 0.16)
            Rectangle()
                .fill(monochrome ? tint : tint.opacity(0.85))
                .frame(width: size * 0.06, height: size * 0.12)
        }
        .offset(y: -size * 0.42)
    }

    private var head: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(headFill)
            .frame(width: size * 0.86, height: size * 0.74)
            .offset(y: size * 0.06)
    }

    private var headFill: AnyShapeStyle {
        if monochrome { return AnyShapeStyle(tint) }
        return AnyShapeStyle(
            LinearGradient(colors: [tint, tint.opacity(0.78)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var face: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.20) {
                eye
                eye
            }
            mouth
        }
        .offset(y: size * 0.06)
    }

    @ViewBuilder
    private var eye: some View {
        if mood == .sleepy || mood == .cheering {
            // A closed, happy arc.
            Capsule()
                .fill(ink)
                .frame(width: size * 0.16, height: size * 0.05)
        } else {
            Circle()
                .fill(ink)
                .frame(width: eyeSize, height: eyeSize)
        }
    }

    private var eyeSize: CGFloat {
        mood == .excited ? size * 0.15 : size * 0.12
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .thinking:
            // A small flat line — attentive, not sad.
            Capsule().fill(ink).frame(width: size * 0.16, height: size * 0.045)
        case .excited, .cheering:
            // Open, delighted.
            Circle().fill(ink).frame(width: size * 0.20, height: size * 0.20)
        case .sleepy:
            Capsule().fill(ink).frame(width: size * 0.12, height: size * 0.04)
        case .playing:
            Smile().stroke(ink, style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round))
                .frame(width: size * 0.26, height: size * 0.11)
        }
    }
}

/// A single upward arc — Pip's default smile.
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        return path
    }
}

#Preview {
    HStack(spacing: 16) {
        PipMark(mood: .playing, size: 44, tint: .green)
        PipMark(mood: .thinking, size: 44, tint: .orange)
        PipMark(mood: .excited, size: 44, tint: .red)
        PipMark(mood: .cheering, size: 44, tint: .purple)
        PipMark(mood: .sleepy, size: 44, tint: .blue)
    }
    .padding()
    .background(.black)
}
