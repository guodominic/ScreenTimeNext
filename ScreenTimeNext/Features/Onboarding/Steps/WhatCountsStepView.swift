//  WhatCountsStepView.swift — PRD §6.4, D-015 / D-016 / D-018
//
//  "Pick apps & categories" — the last screen before the timer starts.
//
//  D-018: the old screen was a mascot, a coy question ("What counts?") and a button that opened
//  something else. Now the list IS the screen: scroll, tap, watch the counts move, start. The
//  title says what to do instead of hinting at it, and the Start button is always in reach.
//
//  Still skippable — a running timer with nothing selected is more useful in the moment than a
//  parent stuck on a picker.

import SwiftUI
import ScreenTimeNextCore

struct WhatCountsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onStart: () -> Void

    private var minutes: Int { viewModel.draft.dailyBudgetSeconds / 60 }
    private var picker: ContentPickerModel { viewModel.picker }
    private var hasSelection: Bool { !picker.isEmpty }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.coral.opacity(0.24), Color(.systemGroupedBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()

            ContentPickerView(model: picker,
                              screenTimeAccessAvailable: viewModel.authorization == .approved,
                              headline: "Pick apps and categories",
                              subheadline: "The \(minutes)-minute timer covers whatever you tick.")
                .scrollContentBackground(.hidden)
                .onChange(of: picker.summary) { _, _ in viewModel.selectionChanged() }
                .safeAreaInset(edge: .bottom) { startBar }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAuthorizationStatus() }
    }

    private var startBar: some View {
        VStack(spacing: 6) {
            Button { if viewModel.startNow() { onStart() } } label: {
                Label("Start \(minutes) minutes", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle(color: Theme.mint))

            Text(hasSelection ? selectionLine : "Nothing ticked yet — you can pick later in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = viewModel.commitError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            if let message = viewModel.authorizationMessage {
                Text(message).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    /// "3 categories · 1 website · 3 apps" — only the parts that are non-zero.
    private var selectionLine: String {
        let s = picker.summary
        var parts: [String] = []
        if s.categoryCount > 0 { parts.append(count(s.categoryCount, "category", "categories")) }
        if s.webDomainCount > 0 { parts.append(count(s.webDomainCount, "website", "websites")) }
        if s.applicationCount > 0 { parts.append(count(s.applicationCount, "app", "apps")) }
        return parts.joined(separator: " · ")
    }

    private func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }
}

/// Counts only — never names, never tokens (§16). Used on the parent dashboard.
struct SelectionSummaryView: View {
    let summary: SelectionSummary

    var body: some View {
        HStack(spacing: 12) {
            stat(summary.categoryCount, "categories", "square.stack.3d.up.fill")
            stat(summary.webDomainCount, "websites", "globe")
            stat(summary.applicationCount, "apps", "app.badge")
        }
        .frame(maxWidth: .infinity)
        .card(tint: Theme.coral)
    }

    private func stat(_ count: Int, _ label: String, _ symbol: String) -> some View {
        VStack(spacing: 4) {
            IconChip(symbol: symbol, color: Theme.coral, size: 28)
            Text("\(count)").font(.title3.bold()).contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { WhatCountsStepView(viewModel: OnboardingViewModel(services: .mocks()), onStart: {}) }
}
