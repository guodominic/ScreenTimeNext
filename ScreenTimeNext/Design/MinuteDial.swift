//  MinuteDial.swift
//  ScreenTimeNext
//
//  A watch-style dial: drag around the ring to set minutes (D-013). Snaps to `step`, gives haptic
//  ticks, and has +/– buttons for fine control and accessibility. Zero renders as "Off" when
//  `zeroMeansOff` is set (warning reminders).

import SwiftUI

struct MinuteDial: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    /// Constant step, or — when `fineBelow` is set — 1 minute under that threshold.
    let step: Int
    /// Below this many minutes the dial moves one minute at a time (D-017): short budgets are the
    /// common case and two-minute jumps are too coarse to say "seven more minutes".
    var fineBelow: Int? = nil
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

            HStack(spacing: 28) {
                Button { nudge(-1) } label: { Image(systemName: "minus.circle.fill").font(.title) }
                    .disabled(minutes <= range.lowerBound)
                Button { nudge(1) } label: { Image(systemName: "plus.circle.fill").font(.title) }
                    .disabled(minutes >= range.upperBound)
            }
            .tint(color)
        }
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

    /// The step in force around a given value.
    private func step(near value: Int) -> Int {
        if let fineBelow, value < fineBelow { return 1 }
        return step
    }

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

#Preview("Budget") {
    struct Host: View {
        @State var m = 60
        var body: some View { MinuteDial(minutes: $m, range: 2...120, step: 2, title: "Daily budget", color: Theme.sky) }
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
