//  ShieldCardView.swift
//  ScreenTimeNext
//
//  D-012 / D-018. A faithful mock of how iOS renders a ManagedSettings shield: a blurred backdrop
//  of the app the child is in, with a centered icon, title, subtitle and buttons on top.
//
//  D-018 — colour and expression carry ONE message: how close the end is.
//      calm     green      Pip is playing        first reminder, plenty of room
//      soon     orange     Pip is thinking       middle reminder, start wrapping up
//      last     red        Pip is excited        last reminder before the end
//      finished rainbow    Pip is cheering       the celebration, and the only multi-coloured card
//      spent    lavender   Pip is sleepy         opened later with the budget already gone
//  The chosen activity still shapes the WORDS and the little badge; it no longer picks the colour.
//
//  This is a PREVIEW. The real shield (Phase 1) is drawn by the system from a `ShieldConfiguration`
//  built out of the same `ShieldPresentation` values, so what is tuned here is what ships:
//      icon → UIImage(systemName: presentation.symbolName)
//      title / subtitle → ShieldConfiguration.Label
//      primaryButtonLabel (+ background color) → the button the child presses
//  Layout and typography are the system's, so treat small differences as expected.

import SwiftUI
import ScreenTimeNextCore

struct ShieldCardView: View {
    let presentation: ShieldPresentation
    var onPrimary: () -> Void = {}

    /// One flat colour for strokes and the mascot, even at the finish where the fill is a gradient.
    private var tint: Color { Theme.color(for: presentation.urgency) }
    /// The fill: a gradient at the finish, the urgency colour everywhere else.
    private var fill: AnyShapeStyle { Theme.style(for: presentation.urgency) }

    /// A different face at every step, so the child reads the moment before reading the words.
    private var mood: MascotMood {
        switch presentation.urgency {
        case .calm:     return .playing
        case .soon:     return .thinking
        case .last:     return .excited
        case .finished: return .cheering
        case .spent:    return .sleepy
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            badge
                .bounceIn()

            Text(presentation.title)
                .font(.system(.title2, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .bounceIn(delay: 0.08)

            Text(presentation.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .bounceIn(delay: 0.14)

            Button(action: onPrimary) {
                Text(presentation.primaryButtonLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(fill))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .bounceIn(delay: 0.2)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Pip with the moment's symbol pinned to his shoulder.
    private var badge: some View {
        ZStack(alignment: .bottomTrailing) {
            if presentation.urgency == .finished {
                Sparkles(color: tint, count: 10)
                    .frame(width: 150, height: 150)
            }
            Mascot(mood: mood, size: 104, tint: tint, animated: false)
            Image(systemName: presentation.symbolName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .offset(x: 6, y: 2)
        }
    }
}

/// The blurred "app behind the shield". Suggestive only — no real app is depicted.
struct PretendAppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemIndigo).opacity(0.8), Color(.systemPink).opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 14) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.25))
                        .frame(height: i % 3 == 0 ? 120 : 56)
                }
            }
            .padding(20)
        }
        .blur(radius: 18)
        .overlay(Color.black.opacity(0.15))
        .ignoresSafeArea()
    }
}

#Preview("1st reminder — green") {
    ZStack {
        PretendAppBackdrop()
        ShieldCardView(presentation: .make(for: .reminder(minutesLeft: 10, activity: .lego),
                                           childName: "Ivy", urgency: .calm))
    }
}

#Preview("2nd reminder — orange") {
    ZStack {
        PretendAppBackdrop()
        ShieldCardView(presentation: .make(for: .reminder(minutesLeft: 5, activity: .lego),
                                           childName: "Ivy", urgency: .soon))
    }
}

#Preview("Last reminder — red") {
    ZStack {
        PretendAppBackdrop()
        ShieldCardView(presentation: .make(for: .reminder(minutesLeft: 1, activity: .lego),
                                           childName: "Ivy", urgency: .last))
    }
}

#Preview("Finished — celebration") {
    ZStack {
        PretendAppBackdrop()
        ShieldCardView(presentation: .make(for: .finished(activity: .outside), childName: "Ivy"))
    }
}
