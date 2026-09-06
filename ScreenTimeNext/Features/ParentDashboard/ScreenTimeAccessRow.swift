//  ScreenTimeAccessRow.swift
//  ScreenTimeNext
//
//  Task 004 (QA-02) — the parent-facing side of Family Controls authorization.
//
//  All four states are rendered, and every one that is not `.approved` carries a way out. §7 rule 6
//  keeps this on the PARENT side only: the child timer never mentions authorization, because a
//  child cannot fix it and being told about it only teaches them the app can be turned off.

import SwiftUI
import UIKit
import ScreenTimeNextCore

struct ScreenTimeAccessRow: View {
    let status: ScreenTimeAuthorizationStatus
    /// Non-nil while a request is in flight, so the button cannot be pressed twice.
    let isRequesting: Bool
    let onRequest: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconChip(symbol: symbol, color: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.semibold)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            action
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var action: some View {
        switch status {
        case .notDetermined:
            Button(action: onRequest) {
                if isRequesting {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Allow Screen Time access", systemImage: "checkmark.shield.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.mint)
            .disabled(isRequesting)

        case .denied, .revoked:
            // Once denied, iOS will not show the sheet again — only Settings can change it, so
            // offering "try again" here would be a button that does nothing.
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.orange)

        case .approved:
            EmptyView()
        }
    }

    // MARK: Copy

    private var title: String {
        switch status {
        case .notDetermined: return "Screen Time access needed"
        case .approved:      return "Screen Time access is on"
        case .denied:        return "Screen Time access was declined"
        case .revoked:       return "Screen Time access was turned off"
        }
    }

    private var detail: String {
        switch status {
        case .notDetermined:
            return "Needed to see which apps are open, warn before time runs out, and hold the line when it does."
        case .approved:
            return "Reminders and the end of the session are enforced inside the apps you picked."
        case .denied:
            return "Without it the timer still runs and reminders still show, but nothing stops the apps. Turn it on in Settings › Screen Time."
        case .revoked:
            return "It was on and is now off, so nothing is being enforced. Turn it back on in Settings › Screen Time."
        }
    }

    private var symbol: String {
        switch status {
        case .approved:      return "checkmark.shield.fill"
        case .notDetermined: return "shield.lefthalf.filled"
        case .denied:        return "shield.slash.fill"
        case .revoked:       return "exclamationmark.shield.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .approved:      return Theme.grass
        case .notDetermined: return Theme.sky
        case .denied:        return .orange
        case .revoked:       return Theme.ruby
        }
    }
}
