//  ShieldIconRenderer.swift
//  ScreenTimeNext
//
//  D-051 — draws Pip into the App Group so the real shield can wear his face.
//
//  The app is the only process with our SwiftUI views in it, and `ImageRenderer` needs a real view.
//  The shield extension needs an answer in milliseconds and has neither. So this runs here, once,
//  and leaves five PNGs behind.

import SwiftUI
import ScreenTimeNextCore

enum ShieldIconRenderer {

    /// Big enough that the system can scale it down cleanly; small enough to write in one go.
    private static let side: CGFloat = 240

    /// Re-render only when something is missing. `version` is bumped by hand when Pip's drawing or
    /// the palette changes — otherwise a family keeps the face they already have, which is right:
    /// re-rendering five images on every launch to produce identical bytes is work for nothing.
    private static let version = 1
    private static let versionKey = "screentimenext.shieldIconVersion"

    @MainActor
    static func renderIfNeeded(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        let stored = defaults?.integer(forKey: versionKey) ?? 0
        guard stored != version || !ShieldIconStore.isComplete() else { return }
        for urgency in ShieldUrgency.allCases {
            guard let data = render(urgency) else { continue }
            ShieldIconStore.write(data, for: urgency)
        }
        defaults?.set(version, forKey: versionKey)
    }

    @MainActor
    private static func render(_ urgency: ShieldUrgency) -> Data? {
        let renderer = ImageRenderer(content: face(for: urgency))
        // 1, not the screen's scale: the file is already 240pt square, and a 3x copy of it is three
        // times the bytes for a picture the system will shrink anyway.
        renderer.scale = 1
        return renderer.uiImage?.pngData()
    }

    /// Pip alone on a transparent background — no card, no gradient, no badge. The shield gives us
    /// one image slot and nothing around it (D-048), so what is drawn here is the whole picture.
    private static func face(for urgency: ShieldUrgency) -> some View {
        Mascot(mood: mood(for: urgency),
               size: side * 0.86,
               tint: Theme.color(for: urgency),
               animated: false)
            .frame(width: side, height: side)
    }

    /// The same faces as the preview, so a parent who showed their child the preview showed them
    /// the truth (D-018).
    private static func mood(for urgency: ShieldUrgency) -> MascotMood {
        switch urgency {
        case .calm:     return .playing
        case .soon:     return .thinking
        case .last:     return .excited
        case .finished: return .cheering
        case .spent:    return .sleepy
        }
    }
}
