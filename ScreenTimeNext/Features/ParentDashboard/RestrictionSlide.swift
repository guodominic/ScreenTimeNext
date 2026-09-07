//  RestrictionSlide.swift
//  ScreenTimeNext
//
//  D-053 / D-055 — the control that turns every restriction off for the rest of today, and back on.
//
//  Slide-to-confirm rather than a switch, on purpose: a toggle is one stray tap, and this unblocks
//  a child's whole device. See `SlideToAct.swift` for the shared geometry and the design rule.
//
//  The label always states what is TRUE right now, never what the control will do: a parent
//  glancing at the dashboard is asking "is anything blocked?", not "what happens if I pull this".
//  What it WILL do is uncovered under the thumb as they drag.
//
//  No Screen Time framework is touched here. It reports a boolean; `Enforcement` owns the rule.

import SwiftUI

struct RestrictionSlide: View {

    /// True when every restriction is currently OFF (green). False when they are in force (orange).
    let isCleared: Bool
    /// D-052 — dead while the countdown runs: nothing is shielded during a session, so a slide
    /// there would claim to do something it is not doing.
    let isEnabled: Bool
    let onChange: (Bool) -> Void

    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @State private var committed = 0

    private var appliedColor: Color { Theme.tangerine }
    private var removedColor: Color { Theme.grass }

    /// Where the parent is now.
    private var currentColor: Color { isCleared ? removedColor : appliedColor }
    private var currentText: String { isCleared ? "App restriction removed" : "App restriction applied" }
    private var currentSymbol: String { isCleared ? "lock.open.fill" : "lock.fill" }

    /// Where they are heading.
    private var nextColor: Color { isCleared ? appliedColor : removedColor }
    private var nextText: String { isCleared ? "App restriction applied" : "App restriction removed" }
    private var nextSymbol: String { isCleared ? "lock.fill" : "lock.open.fill" }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            statusLine
            track
        }
        .sensoryFeedback(.success, trigger: committed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentText)
        .accessibilityValue(isEnabled ? "" : "Unavailable while time is left")
        .accessibilityHint(isCleared ? "Double tap to put restrictions back"
                                     : "Double tap to remove all restrictions")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if isEnabled { commit() } }
    }

    /// The state said once, quietly, above the control — so the control itself does not have to
    /// shout it. Small caps and tracking read as a status field rather than as a sentence.
    private var statusLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isEnabled ? currentColor : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(isEnabled && isCleared ? "EVERYTHING IS OPEN" : "RESTRICTIONS ACTIVE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(isEnabled ? currentColor : Color.secondary)
            Spacer(minLength: 0)
        }
        .animation(.snappy(duration: 0.25), value: isCleared)
    }

    private var track: some View {
        GeometryReader { geo in
            let travel = max(1, geo.size.width - SlideMetrics.knob - SlideMetrics.inset * 2)
            let progress = min(1, dragX / travel)

            ZStack(alignment: .leading) {
                SlideTrackBackground(tint: currentColor, isEnabled: isEnabled)

                SlideLabel(text: currentText, symbol: currentSymbol,
                           tint: isEnabled ? currentColor : .secondary,
                           shimmering: isEnabled)

                // The destination, uncovered exactly as far as the thumb has travelled. One mask
                // does both halves of what a parent sees — the colour fills in and the new words
                // appear, in place, at the edge their thumb is on.
                ZStack {
                    Capsule().fill(nextColor.gradient)
                    SlideLabel(text: nextText, symbol: nextSymbol, tint: .white)
                }
                .mask(alignment: .leading) {
                    Rectangle().frame(width: SlideMetrics.inset * 2 + SlideMetrics.knob + dragX)
                }
                // D-070 — invisible until the thumb actually moves. A circular knob cannot mask a
                // rectangular reveal, so the reveal must not be there to mask.
                .opacity(isEnabled ? min(1, dragX / 20) : 0)

                SlideKnob(symbol: progress > 0.5 ? nextSymbol : currentSymbol,
                          tint: isEnabled ? (progress > 0.5 ? nextColor : currentColor) : .secondary,
                          isDragging: isDragging)
                    .offset(x: SlideMetrics.inset + dragX)
                    .gesture(drag(travel: travel))
            }
            .frame(height: SlideMetrics.height)
        }
        .frame(height: SlideMetrics.height)
    }

    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard isEnabled else { return }
                isDragging = true
                dragX = min(travel, max(0, value.translation.width))
            }
            .onEnded { _ in
                isDragging = false
                guard isEnabled else { return }
                if dragX >= travel * SlideMetrics.commitFraction {
                    // Run the fill to the end first: the parent let go meaning "yes", and the
                    // control finishing the stroke for them is what confirms it was heard.
                    withAnimation(.snappy(duration: 0.2)) { dragX = travel }
                    commit()
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) { dragX = 0 }
                }
            }
    }

    /// Flip the state, then put the knob back at the start with no animation — by then the track
    /// behind it is already the new colour, so the reset is invisible and the control is armed
    /// again in the opposite direction.
    private func commit() {
        committed += 1
        onChange(!isCleared)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dragX = 0 }
        }
    }
}

#Preview("Restrictions applied") {
    RestrictionSlide(isCleared: false, isEnabled: true) { _ in }.padding()
}

#Preview("Restrictions removed") {
    RestrictionSlide(isCleared: true, isEnabled: true) { _ in }.padding()
}

#Preview("While time is left") {
    RestrictionSlide(isCleared: false, isEnabled: false) { _ in }.padding()
}
