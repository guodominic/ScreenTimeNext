//  ShieldCardView.swift
//  ScreenTimeNext
//
//  D-012. A faithful mock of how iOS renders a ManagedSettings shield: a blurred backdrop of the
//  app the child is in, with a centered icon, title, subtitle and buttons on top.
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

    private var tint: Color {
        presentation.activity.map(Theme.color(for:)) ?? Theme.sky
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(Circle().fill(tint))
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
                    .background(Capsule().fill(tint))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .bounceIn(delay: 0.2)
        }
        .padding(28)
        .frame(maxWidth: 380)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
        .padding(24)
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

#Preview("Reminder") {
    ZStack {
        PretendAppBackdrop()
        ShieldCardView(presentation: .make(for: .reminder(minutesLeft: 5, activity: .lego), childName: "Ivy"))
    }
}

#Preview("Finished") {
    ZStack {
        PretendAppBackdrop()
        ShieldCardView(presentation: .make(for: .finished(activity: .outside), childName: "Ivy"))
    }
}
