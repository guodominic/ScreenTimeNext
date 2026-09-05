//  Animations.swift
//  ScreenTimeNext
//
//  Small, consistent motion for the whole app: bounce-in on appear, floating and pulsing accents,
//  and a sparkle burst for Time's Up. Every effect respects Reduce Motion.

import SwiftUI

/// Scale + fade in when the view appears, with an optional stagger delay.
struct BounceIn: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.7)
            .opacity(shown || reduceMotion ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(delay)) { shown = true }
            }
    }
}

/// Gentle up-and-down drift, forever. For friendly icons on idle screens.
struct Floating: ViewModifier {
    var distance: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up && !reduceMotion ? -distance : distance)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { up = true }
            }
    }
}

/// Soft scale pulse, forever. For the final-minute ring.
struct Pulsing: ViewModifier {
    var scale: CGFloat = 1.04
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var big = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(big && !reduceMotion ? scale : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { big = true }
            }
    }
}

extension View {
    func bounceIn(delay: Double = 0) -> some View { modifier(BounceIn(delay: delay)) }
    func floating(distance: CGFloat = 6) -> some View { modifier(Floating(distance: distance)) }
    func pulsing(scale: CGFloat = 1.04) -> some View { modifier(Pulsing(scale: scale)) }
}

/// A one-shot burst of stars that scale in and drift outward. Purely decorative.
struct Sparkles: View {
    var color: Color = Theme.sun
    var count: Int = 8
    var radius: CGFloat = 110
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = Double(i) / Double(count) * 2 * .pi
                Image(systemName: i % 2 == 0 ? "sparkle" : "star.fill")
                    .font(.system(size: i % 3 == 0 ? 22 : 14))
                    .foregroundStyle(i % 2 == 0 ? color : Theme.coral)
                    .offset(x: burst ? cos(angle) * radius : 0,
                            y: burst ? sin(angle) * radius : 0)
                    .scaleEffect(burst ? 1 : 0.2)
                    .opacity(burst ? 0.9 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(Double(i) * 0.04), value: burst)
            }
        }
        .allowsHitTesting(false)
        .onAppear { if !reduceMotion { burst = true } }
    }
}
