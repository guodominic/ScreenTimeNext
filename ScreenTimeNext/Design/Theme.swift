//  Theme.swift
//  ScreenTimeNext
//
//  One playful, consistent palette (Dominic: "the UI is too plain"). Child screens get gradients
//  and big rounded shapes; parent screens stay calm but warm. Every activity has its own color.

import SwiftUI
import ScreenTimeNextCore

enum Theme {
    // Palette
    static let sky      = Color(red: 0.36, green: 0.62, blue: 0.98)
    static let mint     = Color(red: 0.31, green: 0.80, blue: 0.62)
    static let sun      = Color(red: 1.00, green: 0.78, blue: 0.24)
    static let coral    = Color(red: 1.00, green: 0.49, blue: 0.43)
    static let lavender = Color(red: 0.62, green: 0.54, blue: 0.96)
    static let peach    = Color(red: 1.00, green: 0.67, blue: 0.45)
    static let ink      = Color.primary

    /// Session-state color for timers, rings and backgrounds.
    static func color(for state: ScreenTimeState) -> Color {
        switch state {
        case .idle:          return sky
        case .active:        return mint
        case .extended:      return lavender
        case .firstWarning:  return sun
        case .secondWarning: return peach
        case .finalWarning:  return coral
        case .finished:      return lavender
        }
    }

    static func gradient(for state: ScreenTimeState) -> LinearGradient {
        let c = color(for: state)
        return LinearGradient(colors: [c.opacity(0.55), c.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func color(for activity: TransitionActivity) -> Color {
        switch activity {
        case .lego:       return coral
        case .drawing:    return lavender
        case .reading:    return sky
        case .outside:    return mint
        case .snack:      return sun
        case .bath:       return Color(red: 0.40, green: 0.80, blue: 0.95)
        case .homework:   return peach
        case .familyTime: return Color(red: 0.95, green: 0.55, blue: 0.75)
        }
    }

    /// The parent-side hero gradient.
    static let heroGradient = LinearGradient(colors: [sky.opacity(0.9), lavender.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Reusable pieces

struct CardStyle: ViewModifier {
    var tint: Color = .clear
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(tint.opacity(0.12)))
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

extension View {
    func card(tint: Color = .clear) -> some View { modifier(CardStyle(tint: tint)) }
}

/// Big rounded pill button used on every child-facing and onboarding screen.
struct PillButtonStyle: ButtonStyle {
    var color: Color = Theme.sky
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(color))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A circular progress ring — remaining vs. total.
struct ProgressRing: View {
    let fraction: Double          // 0…1 remaining
    var lineWidth: CGFloat = 14
    var color: Color = Theme.sky

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: fraction)
        }
    }
}
