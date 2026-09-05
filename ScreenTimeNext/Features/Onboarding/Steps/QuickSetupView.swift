//  QuickSetupView.swift — D-016
//
//  The only screen with decisions on it: how long, and what counts. Then straight into a running
//  timer — the parent hands the device over, they do not walk through a wizard.

import SwiftUI
import ScreenTimeNextCore

struct QuickSetupView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onStart: () -> Void

    private var minutes: Binding<Int> {
        Binding(get: { viewModel.draft.dailyBudgetSeconds / 60 },
                set: { viewModel.draft.dailyBudgetSeconds = $0 * 60 })
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.mint.opacity(0.30), Color(.systemGroupedBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            PlayfulBackground(tint: Theme.mint, intensity: 0.7)

            ScrollView {
                VStack(spacing: 20) {
                    Text("How long today?")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .bounceIn()

                    MinuteDial(minutes: minutes,
                               range: ScreenTimeConfiguration.budgetRangeSeconds.lowerBound / 60...ScreenTimeConfiguration.budgetRangeSeconds.upperBound / 60,
                               step: ScreenTimeConfiguration.budgetStepSeconds / 60,
                               color: Theme.mint)
                        .bounceIn(delay: 0.06)

                    contentCard
                        .bounceIn(delay: 0.12)
                }
                .padding(24)
                .readableWidth()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button { if viewModel.startNow() { onStart() } } label: {
                        Label("Start \(minutes.wrappedValue) minutes", systemImage: "play.fill")
                    }
                    .buttonStyle(PillButtonStyle(color: Theme.mint))
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

    /// What the budget applies to. Optional — skipping it still gives a working timer, which is
    /// the point: the parent can be useful in ten seconds and refine later.
    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconChip(symbol: "square.grid.2x2.fill", color: Theme.coral, size: 32)
                Text("What counts").font(.headline)
                Spacer()
            }

            if let summary = viewModel.draft.selection?.summary, !summary.isEmpty {
                SelectionSummaryView(summary: summary)
                Button("Change") { viewModel.clearSelection() }
                    .buttonStyle(.bordered)
                    .tint(Theme.coral)
            } else {
                Text("Pick **categories** — Games, Entertainment, Social — and the matching **website** categories, so the browser isn't an open door.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                SelectionPickerButton { viewModel.applySelection($0) }
                if let message = viewModel.authorizationMessage {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(tint: Theme.coral)
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

/// Phase 0 stand-in for Apple's FamilyActivityPicker (Task 005). Produces a category-first sample,
/// matching the shape D-015 recommends.
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
    NavigationStack { QuickSetupView(viewModel: OnboardingViewModel(services: .mocks()), onStart: {}) }
}
