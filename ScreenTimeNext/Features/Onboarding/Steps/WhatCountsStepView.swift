//  WhatCountsStepView.swift — PRD §6.4, D-015 / D-016
//
//  What the budget applies to. Skippable — a working timer without a selection is more useful in
//  the moment than a parent stuck on a picker. Phase 0 uses a sample selection; Task 005 swaps in
//  Apple's FamilyActivityPicker behind the same button.

import SwiftUI
import ScreenTimeNextCore

struct WhatCountsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onStart: () -> Void

    private var minutes: Int { viewModel.draft.dailyBudgetSeconds / 60 }
    private var hasSelection: Bool { viewModel.draft.hasSelection }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.coral.opacity(0.28), Color(.systemGroupedBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            PlayfulBackground(tint: Theme.coral, intensity: 0.7)

            ScrollView {
                VStack(spacing: 20) {
                    Mascot(mood: .thinking, size: 130, tint: Theme.coral)
                        .bounceIn()
                    Text("What counts?")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .bounceIn(delay: 0.06)

                    if let summary = viewModel.draft.selection?.summary, !summary.isEmpty {
                        SelectionSummaryView(summary: summary)
                            .bounceIn(delay: 0.1)
                        Button("Change") { viewModel.clearSelection() }
                            .buttonStyle(.bordered)
                            .tint(Theme.coral)
                    } else {
                        Text("Pick categories — Games, Entertainment, Social — and the website ones too.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .bounceIn(delay: 0.1)
                        SelectionPickerButton { viewModel.applySelection($0) }
                            .bounceIn(delay: 0.14)
                        if let message = viewModel.authorizationMessage {
                            Text(message).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(24)
                .readableWidth(520)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button { if viewModel.startNow() { onStart() } } label: {
                        Label("Start \(minutes) minutes", systemImage: "play.fill")
                    }
                    .buttonStyle(PillButtonStyle(color: Theme.mint))
                    if !hasSelection {
                        Text("You can choose this later in Settings.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let error = viewModel.commitError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .readableWidth()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAuthorizationStatus() }
    }
}

/// Counts only — never names, never tokens (§16).
struct SelectionSummaryView: View {
    let summary: SelectionSummary

    var body: some View {
        HStack(spacing: 12) {
            stat(summary.applicationCount, "apps", "app.badge")
            stat(summary.categoryCount, "categories", "square.stack.3d.up.fill")
            stat(summary.webDomainCount, "websites", "globe")
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

/// Phase 0 stand-in for Apple's FamilyActivityPicker (Task 005). Category-first, per D-015.
struct SelectionPickerButton: View {
    let onPick: (SelectionSnapshot) -> Void

    var body: some View {
        Button {
            onPick(MockScreenTimeSelectionService.sampleSnapshot(apps: 0, categories: 3, webDomains: 2))
        } label: {
            Label("Choose apps & categories", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.bordered)
        .tint(Theme.coral)
    }
}

#Preview {
    NavigationStack { WhatCountsStepView(viewModel: OnboardingViewModel(services: .mocks()), onStart: {}) }
}
