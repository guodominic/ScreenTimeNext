//  SlideToAct.swift
//  ScreenTimeNext
//
//  D-055 — the shared parts of the dashboard's two slide controls, so they cannot drift apart.
//
//  There are exactly two things on this screen that a stray tap must not be able to do: unblock a
//  child's whole device, and erase the setup. Both are now the same gesture, with the same
//  geometry, the same shimmer and the same commit threshold — a parent learns the control once.
//
//  The design rule, written down because it is the thing that keeps getting broken:
//  SATURATION IS FOR THE CHANGE, NOT FOR THE STATE. At rest a track is its colour at low opacity
//  with a hairline edge and coloured text — calm, and readable at a glance. Full colour appears
//  only under the thumb. A control that stays quiet until you touch it and then commits fully
//  reads as considered; one that shouts at rest has nowhere left to go when it actually changes.
//
//  The drag IS the confirmation. Neither of these puts a dialog behind it, and that is deliberate:
//  both already sit behind the parent gate, and a sheet that always gets the same answer teaches a
//  parent to dismiss sheets.

import SwiftUI

enum SlideMetrics {
    static let height: CGFloat = 54
    static let inset: CGFloat = 4
    static var knob: CGFloat { height - inset * 2 }
    /// Far enough that a knuckle brushing the screen cannot do it; short of the end, because
    /// demanding the last pixel makes a control feel broken rather than careful.
    static let commitFraction: CGFloat = 0.72
    /// Leaves the words clear of the knob at rest, so they are never half under a thumb.
    static var textInset: CGFloat { knob + inset * 2 + 8 }
}

/// The words inside a track, with a slow highlight passing over them. One sweep says "this moves"
/// without the blinking chevrons that date a control to 2013.
struct SlideLabel: View {
    let text: String
    let symbol: String
    let tint: Color
    var shimmering = false

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var content: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            Text(text).font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).opacity(0.45)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.leading, SlideMetrics.textInset)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        content
            .foregroundStyle(tint)
            .overlay {
                if shimmering && !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 110)
                            .offset(x: phase * (geo.size.width + 110) - 110)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard shimmering, !reduceMotion else { return }
                withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

/// The thumb. System background rather than pure white, so it is still a raised object in dark mode.
struct SlideKnob: View {
    let symbol: String
    let tint: Color
    let isDragging: Bool

    var body: some View {
        Circle()
            .fill(Color(.systemBackground))
            .overlay(Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
            .frame(width: SlideMetrics.knob, height: SlideMetrics.knob)
            .shadow(color: .black.opacity(isDragging ? 0.20 : 0.12),
                    radius: isDragging ? 7 : 3, y: isDragging ? 3 : 1)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(isDragging ? 1.04 : 1)
            .animation(.snappy(duration: 0.18), value: isDragging)
    }
}

/// The resting track: the state's colour, tinted, with a hairline edge. Without the edge a tinted
/// capsule reads as a patch of background rather than as a control.
struct SlideTrackBackground: View {
    let tint: Color
    let isEnabled: Bool

    var body: some View {
        Capsule()
            .fill(isEnabled ? AnyShapeStyle(tint.opacity(0.13))
                            : AnyShapeStyle(Color(.tertiarySystemFill)))
            .overlay(
                Capsule().strokeBorder(isEnabled ? tint.opacity(0.28) : .clear, lineWidth: 0.5)
            )
    }
}

// MARK: - One-shot: slide to do something irreversible

/// D-055 — "Start over" was a red row plus a confirmation dialog. The dialog was theatre: it always
/// got the same answer, and a parent who has already unlocked the gate and tapped a destructive row
/// is not helped by being asked again in different words. The slide replaces both — the deliberate
/// travel is the confirmation, and the footer beside it is where the consequences are actually read.
struct ConfirmSlide: View {

    let title: String
    let symbol: String
    var tint: Color = .red
    let onConfirm: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @State private var committed = 0

    var body: some View {
        GeometryReader { geo in
            let travel = max(1, geo.size.width - SlideMetrics.knob - SlideMetrics.inset * 2)

            ZStack(alignment: .leading) {
                SlideTrackBackground(tint: tint, isEnabled: true)
                SlideLabel(text: title, symbol: symbol, tint: tint, shimmering: true)

                // The commitment, filling in under the thumb.
                ZStack {
                    Capsule().fill(tint.gradient)
                    SlideLabel(text: title, symbol: symbol, tint: .white)
                }
                .mask(alignment: .leading) {
                    Rectangle().frame(width: SlideMetrics.inset * 2 + SlideMetrics.knob + dragX)
                }

                SlideKnob(symbol: symbol, tint: tint, isDragging: isDragging)
                    .offset(x: SlideMetrics.inset + dragX)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                isDragging = true
                                dragX = min(travel, max(0, value.translation.width))
                            }
                            .onEnded { _ in
                                isDragging = false
                                if dragX >= travel * SlideMetrics.commitFraction {
                                    withAnimation(.snappy(duration: 0.2)) { dragX = travel }
                                    committed += 1
                                    onConfirm()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { dragX = 0 }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { dragX = 0 }
                                }
                            }
                    )
            }
            .frame(height: SlideMetrics.height)
        }
        .frame(height: SlideMetrics.height)
        .sensoryFeedback(.warning, trigger: committed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits([.isButton, .isSelected])
        // VoiceOver cannot drag, and "slide it" is not an instruction we get to give someone who
        // navigates by taps. The gesture guards against a stray thumb; it is not a requirement.
        .accessibilityAction { committed += 1; onConfirm() }
    }
}

#Preview("Confirm") {
    ConfirmSlide(title: "Slide to erase and start over", symbol: "arrow.counterclockwise") {}
        .padding()
}
