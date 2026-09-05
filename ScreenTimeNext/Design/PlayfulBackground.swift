//  PlayfulBackground.swift
//  ScreenTimeNext
//
//  Soft drifting shapes behind every screen. Deliberately low-contrast: it should read as a
//  friendly, hand-made space rather than decoration competing with the content — especially on
//  the child timer, where one number has to dominate.

import SwiftUI

struct PlayfulBackground: View {
    var tint: Color = Theme.sky
    /// Child screens can take more; parent screens stay calm.
    var intensity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    private struct Blob: Identifiable {
        let id: Int
        let symbol: String?
        let size: CGFloat
        let x: CGFloat        // unit position
        let y: CGFloat
        let rotation: Double
        let color: Color
        let delay: Double
    }

    private var blobs: [Blob] {
        [
            Blob(id: 0, symbol: nil, size: 190, x: 0.86, y: 0.10, rotation: 0, color: tint, delay: 0),
            Blob(id: 1, symbol: "cloud.fill", size: 84, x: 0.14, y: 0.16, rotation: 0, color: .white, delay: 0.6),
            Blob(id: 2, symbol: "star.fill", size: 26, x: 0.24, y: 0.05, rotation: -12, color: Theme.sun, delay: 1.1),
            Blob(id: 3, symbol: nil, size: 130, x: 0.06, y: 0.72, rotation: 0, color: Theme.mint, delay: 0.3),
            Blob(id: 4, symbol: "sparkle", size: 22, x: 0.92, y: 0.62, rotation: 8, color: Theme.coral, delay: 1.6),
            Blob(id: 5, symbol: "cloud.fill", size: 62, x: 0.80, y: 0.88, rotation: 0, color: .white, delay: 0.9),
            Blob(id: 6, symbol: "heart.fill", size: 20, x: 0.10, y: 0.44, rotation: -8, color: Theme.coral, delay: 2.0),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(blobs) { blob in
                    Group {
                        if let symbol = blob.symbol {
                            Image(systemName: symbol)
                                .font(.system(size: blob.size))
                                .foregroundStyle(blob.color)
                        } else {
                            Circle().fill(blob.color)
                                .frame(width: blob.size, height: blob.size)
                        }
                    }
                    .opacity((blob.symbol == nil ? 0.10 : 0.22) * intensity)
                    .rotationEffect(.degrees(blob.rotation))
                    .position(x: geo.size.width * blob.x, y: geo.size.height * blob.y)
                    .offset(y: drift && !reduceMotion ? -10 : 10)
                    .animation(.easeInOut(duration: 3.2 + blob.delay)
                        .repeatForever(autoreverses: true).delay(blob.delay), value: drift)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { drift = true }
    }
}

/// The standard child-screen backdrop: state gradient + drifting shapes.
struct ChildBackdrop: View {
    var color: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [color.opacity(0.42), color.opacity(0.10), Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom)
            PlayfulBackground(tint: color, intensity: 1.0)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        ChildBackdrop(color: Theme.mint)
        Mascot(mood: .playing, size: 140, tint: Theme.mint)
    }
}
