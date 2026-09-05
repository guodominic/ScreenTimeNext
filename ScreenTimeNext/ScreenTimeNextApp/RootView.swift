//  RootView.swift
//  ScreenTimeNext
//
//  Task 002 placeholder: proves views reach services only through the environment.
//  Task 003 replaces this with real onboarding + root navigation.

import SwiftUI
import ScreenTimeNextCore

struct RootView: View {
    @Environment(\.services) private var services

    @State private var authorization: ScreenTimeAuthorizationStatus = .notDetermined
    @State private var configuration: ScreenTimeConfiguration = .default
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("ScreenTimeNext")
                .font(.largeTitle.bold())
            Text("Make screen time end peacefully.")
                .foregroundStyle(.secondary)
            Divider().padding(.vertical)

            LabeledContent("Authorization", value: authorization.rawValue)
            LabeledContent("Daily budget", value: "\(configuration.dailyBudgetSeconds / 60) min")
            LabeledContent("Warnings", value: warningSummary)
            LabeledContent("Stage at 5:00 left", value: WarningStateEngine.stage(remainingSeconds: 300).rawValue)

            if let errorText {
                Text(errorText).foregroundStyle(.red).font(.footnote)
            }

            Button("Request authorization (mock)") {
                Task { await requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .font(.callout)
        .padding()
        .task { await load() }
    }

    private var warningSummary: String {
        [configuration.warning10Enabled ? "10" : nil,
         configuration.warning5Enabled ? "5" : nil,
         configuration.warning1Enabled ? "1" : nil]
            .compactMap { $0 }
            .joined(separator: " / ") + " min"
    }

    private func load() async {
        authorization = await services.authorization.status
        configuration = (try? services.storage.loadConfiguration()) ?? .default
    }

    private func requestAuthorization() async {
        do {
            authorization = try await services.authorization.requestAuthorization()
            errorText = nil
        } catch {
            errorText = "Authorization failed: \(error)"
            authorization = await services.authorization.status
        }
    }
}

#Preview("Approved") {
    RootView().services(.mocks())
}

#Preview("Denied") {
    RootView().services(.mocks(authorization: MockScreenTimeAuthorizationService(script: .deny)))
}
