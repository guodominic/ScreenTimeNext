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

// MARK: - Adaptive layout (iPad)

/// iPad is this product's main device — a child's screen time mostly happens there — so nothing
/// may simply stretch to the full width of a 13" display. Text gets a readable measure; controls
/// that are dragged with a finger get bigger, not just wider.
struct ReadableWidth: ViewModifier {
    var max: CGFloat = 640
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: max)
            .frame(maxWidth: .infinity)      // centre within the available space
    }
}

extension View {
    func readableWidth(_ max: CGFloat = 640) -> some View { modifier(ReadableWidth(max: max)) }
}

extension Optional where Wrapped == UserInterfaceSizeClass {
    /// 1.0 on iPhone, 1.35 on iPad — for hit targets and dials, not for text.
    /// Read `@Environment(\.horizontalSizeClass)` in the view and call this, rather than deriving
    /// it from a computed EnvironmentValues property (SwiftUI's dependency tracking is only
    /// reliable for real environment keys).
    var controlScale: CGFloat {
        self == .regular ? 1.35 : 1.0
    }
}

// MARK: - Reusable pieces

struct CardStyle: ViewModifier {
    var tint: Color = .clear
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(tint.opacity(0.14)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(tint == .clear ? Color.primary.opacity(0.06) : tint.opacity(0.30), lineWidth: 2)
                    )
            )
            .shadow(color: (tint == .clear ? Color.black : tint).opacity(0.10), radius: 10, y: 4)
    }
}

/// A round, chunky icon chip — the friendlier replacement for a bare SF Symbol in a list row.
struct IconChip: View {
    let symbol: String
    var color: Color = Theme.sky
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1.5))
            .shadow(color: color.opacity(0.35), radius: 3, y: 2)
    }
}

/// A small speech bubble, so Pip can actually say things.
struct SpeechBubble<Content: View>: View {
    var color: Color = Theme.sky
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(color.opacity(0.35), lineWidth: 2))
            )
            .shadow(color: color.opacity(0.18), radius: 8, y: 3)
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
            .font(.system(.title3, design: .rounded).bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [color, color.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 2))
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.15 : 0.40),
                    radius: configuration.isPressed ? 3 : 10,
                    y: configuration.isPressed ? 1 : 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
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
