//  RestrictionSlide.swift
//  ScreenTimeNext
//
//  D-053 — the one control that turns every restriction off for the rest of today, and back on.
//
//  It is a slide-to-confirm rather than a switch on purpose. A toggle is one stray tap, and this
//  is the control that unblocks a child's whole device; the deliberate drag IS the confirmation,
//  which is also why there is no "are you sure?" sheet behind it.
//
//  The label always states what is TRUE right now, never what the control will do — a parent
//  glancing at the dashboard is asking "is anything blocked?", not "what happens if I pull this".
//  What it will do is revealed underneath as they drag, in the colour of the state they are
//  heading for.
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
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let height: CGFloat = 62
    private let inset: CGFloat = 5
    private var knob: CGFloat { height - inset * 2 }

    /// Far enough that a knuckle brushing the screen cannot do it; short of the end, because
    /// demanding the last pixel makes a control feel broken rather than careful.
    private let commitFraction: CGFloat = 0.72

    private var appliedColor: Color { Theme.tangerine }
    private var removedColor: Color { Theme.grass }

    /// The state shown behind the knob — where the parent is now.
    private var currentColor: Color { isCleared ? removedColor : appliedColor }
    private var currentText: String { isCleared ? "App restriction removed" : "App restriction applied" }
    private var currentSymbol: String { isCleared ? "lock.open.fill" : "lock.fill" }

    /// The state revealed by dragging — where they are heading.
    private var nextColor: Color { isCleared ? appliedColor : removedColor }
    private var nextText: String { isCleared ? "App restriction applied" : "App restriction removed" }
    private var nextSymbol: String { isCleared ? "lock.fill" : "lock.open.fill" }

    var body: some View {
        GeometryReader { geo in
            let travel = max(1, geo.size.width - knob - inset * 2)
            let progress = min(1, dragX / travel)

            ZStack(alignment: .leading) {
                // Where we are.
                Capsule().fill(isEnabled ? AnyShapeStyle(currentColor.gradient)
                                         : AnyShapeStyle(Color.gray.opacity(0.28)))
                label(currentText, currentSymbol, on: isEnabled ? .white : Color.secondary)

                // Where we are heading, uncovered exactly as far as the knob has travelled. One
                // mask does both halves of what a parent sees: the colour changes and the new
                // words appear, in place, at the same edge their thumb is on.
                ZStack {
                    Capsule().fill(nextColor.gradient)
                    label(nextText, nextSymbol, on: .white)
                }
                .mask(alignment: .leading) {
                    Rectangle().frame(width: inset * 2 + knob + dragX)
                }
                .opacity(isEnabled ? 1 : 0)

                if isEnabled { hints(progress: progress) }

                knobView(progress: progress)
                    .offset(x: inset + dragX)
                    .gesture(drag(travel: travel))
            }
            .frame(height: height)
            .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: isCleared)
        }
        .frame(height: height)
        .onAppear { pulse = true }
        .sensoryFeedback(.success, trigger: committed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentText)
        .accessibilityValue(isEnabled ? "" : "Unavailable while time is left")
        .accessibilityHint(isCleared ? "Double tap to put restrictions back"
                                     : "Double tap to remove all restrictions")
        .accessibilityAddTraits(.isButton)
        // VoiceOver cannot drag, and "slide it" is not an instruction we get to give someone who
        // navigates by taps. The gesture guards against a stray thumb; it is not a requirement.
        .accessibilityAction { if isEnabled { commit() } }
    }

    // MARK: Pieces

    private func label(_ text: String, _ symbol: String, on tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.system(.subheadline, design: .rounded).weight(.bold))
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        // Clear of the knob at rest, so the words are never half under a thumb.
        .padding(.leading, knob * 0.6)
        .padding(.trailing, 10)
    }

    private func knobView(progress: CGFloat) -> some View {
        Circle()
            .fill(.white)
            .frame(width: knob, height: knob)
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            .overlay {
                Image(systemName: progress > 0.5 ? nextSymbol : currentSymbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(progress > 0.5 ? nextColor : currentColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(isDragging ? 1.06 : 1)
            .animation(.snappy(duration: 0.18), value: isDragging)
    }

    /// Three chevrons that breathe toward the end of the track. They are the only thing on this
    /// control that says "pull me", and they fade out as the parent does.
    private func hints(progress: CGFloat) -> some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "chevron.compact.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(pulse && !reduceMotion ? 0.9 : 0.3))
                    .animation(reduceMotion ? nil
                               : .easeInOut(duration: 0.7).repeatForever().delay(Double(i) * 0.16),
                               value: pulse)
            }
        }
        .padding(.trailing, 18)
        .opacity(max(0, 1 - progress * 1.6))
        .allowsHitTesting(false)
    }

    // MARK: Behaviour

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
                if dragX >= travel * commitFraction {
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
