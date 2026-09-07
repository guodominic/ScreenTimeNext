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
//  D-048 — WHAT THE SYSTEM ACTUALLY DRAWS, and why this file changed.
//
//  Dominic put the real shield next to this preview and they did not match. They could not have:
//  the shield is drawn by iOS, and a `ShieldConfiguration` gives us exactly five things —
//
//      icon                          UIImage
//      title / subtitle              ShieldConfiguration.Label (text + colour)
//      primaryButtonLabel            + its background colour
//      secondaryButtonLabel          + up to three submenu items (D-044, iOS 26.4+)
//      backgroundBlurStyle / colour
//
//  — and NOTHING else. No mascot, no gradient, no layout, no typography, no animation. Everything
//  this preview used to add was ours and could never appear on the real thing.
//
//  A preview that shows a parent something their child will never see is worse than no preview:
//  it is the one screen in the app whose whole job is to be accurate. So this now mirrors the
//  system's layout — icon, title, subtitle, buttons, stacked and centred on a blur — and Pip
//  appears only where he really can: as the ICON, which IS a `UIImage` we supply.

import SwiftUI
import ScreenTimeNextCore

struct ShieldCardView: View {
    let presentation: ShieldPresentation
    var onPrimary: () -> Void = {}

    /// One flat colour for strokes and the mascot, even at the finish where the fill is a gradient.
    private var tint: Color { Theme.color(for: presentation.urgency) }
    /// D-048 — flat, because `primaryButtonBackgroundColor` is a single `UIColor`. The finish's
    /// rainbow gradient lived here and could never have reached the real shield.
    private var fill: Color { tint }

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
        // The system's shield is a centred column on a blur, with generous spacing and no
        // decoration of its own. Matching that here is the point of this view.
        VStack(spacing: 18) {
            badge

            Text(presentation.title)
                .font(.system(.title2, design: .rounded).bold())
                .multilineTextAlignment(.center)

            Text(presentation.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

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

            // D-044 — the real shield puts these in a system submenu behind a second button. A
            // preview that hid them would let a parent sign off on a screen their child never
            // sees, so they are drawn here as the plain list the submenu amounts to.
            if let secondary = presentation.secondaryButtonLabel {
                VStack(spacing: 8) {
                    Text(secondary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(presentation.submenuItems, id: \.self) { item in
                        Text(item)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(.thinMaterial))
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// D-048 — the icon, and only the icon.
    ///
    /// `ShieldConfiguration.icon` is a single `UIImage`, so this is exactly one image at one size:
    /// no mascot beside it, no sparkles around it, no badge pinned to it. Pip is drawn INTO that
    /// image rather than next to it, which is the one way he can appear on a real shield at all.
    private var badge: some View {
        Mascot(mood: mood, size: 96, tint: tint, animated: false)
            .frame(width: 96, height: 96)
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
