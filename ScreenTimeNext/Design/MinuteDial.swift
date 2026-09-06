//  MinuteDial.swift
//  ScreenTimeNext
//
//  A watch-style dial: drag around the ring to set minutes (D-013). Snaps to `step`, gives haptic
//  ticks, and has +/– buttons for fine control and accessibility. Zero renders as "Off" when
//  `zeroMeansOff` is set (warning reminders).

import SwiftUI
import ScreenTimeNextCore

struct MinuteDial: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    /// D-034 — one step for the whole range. The fine/coarse split is gone: every dial in the app
    /// now moves a minute at a time, so no screen can round a parent's number to something else.
    let step: Int
    var title: String? = nil
    var color: Color = Theme.sky
    /// Base size; on iPad every dial is scaled up (see `size`), because the whole control is dragged.
    var baseSize: CGFloat = 230
    var zeroMeansOff = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var size: CGFloat { baseSize * sizeClass.controlScale }

    private var span: Int { range.upperBound - range.lowerBound }
    private var fraction: Double { span == 0 ? 0 : Double(minutes - range.lowerBound) / Double(span) }

    var body: some View {
        VStack(spacing: 12) {
            if let title {
                Text(title).font(.headline).foregroundStyle(.secondary)
            }
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: size * 0.085)
                ticks
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                knob
                VStack(spacing: 2) {
                    if zeroMeansOff && minutes == 0 {
                        Text("Off").font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    } else {
                        Text("\(minutes)")
                            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(minutes == 1 ? "minute" : "minutes")
                            .font(.system(size: size * 0.075, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: minutes)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let center = CGPoint(x: size / 2, y: size / 2)
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        // The middle of the dial is the READOUT, not a control: a tap on the number
                        // used to fling the value to whatever angle the finger happened to be at.
                        guard (dx * dx + dy * dy).squareRoot() > size * 0.30 else { return }
                        var angle = atan2(dy, dx) + .pi / 2          // 0 at 12 o'clock
                        if angle < 0 { angle += 2 * .pi }
                        let raw = Double(range.lowerBound) + (angle / (2 * .pi)) * Double(span)
                        set(raw)
                    }
            )
            .sensoryFeedback(.selection, trigger: minutes)
            .onChange(of: range.upperBound) { _, upper in
                if minutes > upper { minutes = upper }      // budget lowered below this reminder
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title ?? "Minutes")
            .accessibilityValue(zeroMeansOff && minutes == 0 ? "Off" : "\(minutes) minutes")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: nudge(1)
                case .decrement: nudge(-1)
                @unknown default: break
                }
            }

            stepperRow
        }
    }

    /// D-020 — `.borderless` is load-bearing, not decoration.
    ///
    /// Inside a `Form` or `List` row, a `Button` with the default style makes the WHOLE ROW the tap
    /// target, and two of them in one row collapse into a single ambiguous target — which is why
    /// these worked during setup (a ScrollView) and did nothing in Settings. `.borderless` keeps
    /// each button's own bounds. `contentShape` then guarantees the tappable area is the circle the
    /// parent can see, rather than the glyph's tight outline.
    private var stepperRow: some View {
        HStack(spacing: 28) {
            stepButton(-1, symbol: "minus.circle.fill", enabled: minutes > range.lowerBound)
            stepButton(1, symbol: "plus.circle.fill", enabled: minutes < range.upperBound)
        }
        .tint(color)
        .accessibilityHidden(true)          // the dial itself is the adjustable element
    }

    private func stepButton(_ direction: Int, symbol: String, enabled: Bool) -> some View {
        Button {
            nudge(direction)
        } label: {
            Image(systemName: symbol)
                .font(.title)
                .frame(width: 44, height: 44)      // a real 44pt target, not the glyph's outline
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private var ticks: some View {
        ForEach(0..<12, id: \.self) { i in
            Capsule()
                .fill(color.opacity(0.35))
                .frame(width: 3, height: size * 0.05)
                .offset(y: -size / 2 + size * 0.085 + 6)
                .frame(width: size, height: size)          // rotate about the dial's center
                .rotationEffect(.degrees(Double(i) * 30))
        }
    }

    private var knob: some View {
        Circle()
            .fill(.white)
            .frame(width: size * 0.12, height: size * 0.12)
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            .overlay(Circle().stroke(color, lineWidth: 3))
            .offset(y: -size / 2 + size * 0.0425)
            .frame(width: size, height: size)              // rotate about the dial's center
            .rotationEffect(.degrees(fraction * 360))
    }

    private func step(near value: Int) -> Int { step }

    private func set(_ raw: Double) {
        let st = step(near: Int(raw))
        let stepped = (raw / Double(st)).rounded() * Double(st)
        minutes = min(max(Int(stepped), range.lowerBound), range.upperBound)
    }

    private func nudge(_ direction: Int) {
        // Stepping DOWN across the threshold should use the finer step, so 16 → 14 → 13 … reads
        // naturally rather than jumping.
        let st = step(near: direction < 0 ? minutes - 1 : minutes)
        minutes = min(max(minutes + direction * st, range.lowerBound), range.upperBound)
    }
}

// MARK: Shared configurations
//
// D-020 — Settings had its own hand-written budget dial (2...120, fixed 2-minute steps) while
// setup used the values from `ScreenTimeConfiguration`. Same question, two different feels, and
// Settings could not express a one-minute budget at all. These factories are now the only way a
// budget or reminder dial gets built, so the two screens cannot drift apart again.

extension MinuteDial {

    /// Minutes of screen time: 1–90, one minute at a time (D-034).
    static func budget(_ minutes: Binding<Int>,
                       title: String? = nil,
                       color: Color = Theme.mint,
                       baseSize: CGFloat = 230) -> MinuteDial {
        // Built as a local first: a `...` at the start of a continuation line parses as the
        // PREFIX operator (PartialRangeThrough), not as the range we mean.
        let lowest = ScreenTimeConfiguration.budgetRangeSeconds.lowerBound / 60
        let highest = ScreenTimeConfiguration.budgetRangeSeconds.upperBound / 60
        return MinuteDial(minutes: minutes,
                   range: lowest...highest,
                   step: ScreenTimeConfiguration.budgetStepSeconds / 60,
                   title: title,
                   color: color,
                   baseSize: baseSize)
    }

    /// One reminder, in minutes before the end. 0 renders as "Off". The upper bound comes from the
    /// budget and from the reminder before it (D-019), so the caller passes it in.
    static func reminder(_ minutes: Binding<Int>,
                         upperBound: Int,
                         title: String,
                         color: Color,
                         baseSize: CGFloat = 104) -> MinuteDial {
        MinuteDial(minutes: minutes,
                   range: 0...max(0, upperBound),
                   step: ScreenTimeConfiguration.warningStepSeconds / 60,
                   title: title,
                   color: color,
                   baseSize: baseSize,
                   zeroMeansOff: true)
    }
}

#Preview("Budget") {
    struct Host: View {
        @State var m = 60
        var body: some View { MinuteDial.budget($m, title: "Daily budget", color: Theme.sky) }
    }
    return Host()
}

#Preview("Reminder") {
    struct Host: View {
        @State var m = 5
        var body: some View { MinuteDial(minutes: $m, range: 0...15, step: 1, title: "Reminder", color: Theme.sun, baseSize: 150, zeroMeansOff: true) }
    }
    return Host()
}
