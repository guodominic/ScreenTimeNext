//  RootView.swift
//  ScreenTimeNext
//
//  Task 001 placeholder. Its only job is to prove the app target links ScreenTimeNextCore.
//  Task 002 replaces this with real root navigation behind injected services.

import SwiftUI
import ScreenTimeNextCore

struct RootView: View {
    private let configuration = ScreenTimeConfiguration.default

    var body: some View {
        VStack(spacing: 12) {
            Text("ScreenTimeNext")
                .font(.largeTitle.bold())
            Text("Make screen time end peacefully.")
                .foregroundStyle(.secondary)
            Divider().padding(.vertical)
            Text("Default budget: \(configuration.dailyBudgetSeconds / 60) minutes")
            Text("Warnings: \(warningSummary)")
            Text("Stage at 5:00 left: \(WarningStateEngine.stage(remainingSeconds: 300).rawValue)")
        }
        .font(.callout)
        .padding()
    }

    private var warningSummary: String {
        [configuration.warning10Enabled ? "10" : nil,
         configuration.warning5Enabled ? "5" : nil,
         configuration.warning1Enabled ? "1" : nil]
            .compactMap { $0 }
            .joined(separator: " / ") + " min"
    }
}

#Preview {
    RootView()
}
