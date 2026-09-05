//  AppSelectionStepView.swift — PRD §6.4, D-015 (category-first)
//
//  Phase 0: the picker is mocked. Task 005 swaps `SelectionPickerButton` for the
//  FamilyActivityPicker wrapper from ScreenTime/Selection/ (D-001). This step never sees app names
//  or tokens — only the display-safe summary (PRD §16).
//
//  The copy here is the product decision, not decoration: parents who pick two or three apps by
//  name get a budget the child walks around (TikTok instead of YouTube, Safari instead of either).
//  Categories — including WEB categories — are what actually hold.

import SwiftUI
import ScreenTimeNextCore

struct AppSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var name: String { viewModel.draft.trimmedChildName }

    var body: some View {
        OnboardingStepScaffold(
            title: "Choose what counts",
            subtitle: "Pick the apps, categories and websites that count toward \(name)'s screen time.",
            symbol: "square.grid.2x2.fill",
            color: Theme.coral,
            buttonTitle: viewModel.draft.hasSelection ? "Continue" : "Skip for now",
            action: { viewModel.advance(to: .budget) }
        ) {
            if let summary = viewModel.draft.selection?.summary, !summary.isEmpty {
                SelectionSummaryView(summary: summary)
                Button("Change selection") { viewModel.clearSelection() }
                    .buttonStyle(.bordered)
            } else {
                advice
                SelectionPickerButton { snapshot in
                    viewModel.applySelection(snapshot)
                }
            }
        }
    }

    /// D-015 — the one piece of advice that decides whether the budget means anything.
    private var advice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Pick **categories**, not single apps").font(.subheadline)
            } icon: {
                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Theme.coral)
            }
            Text("Choosing “Games”, “Entertainment” and “Social” covers apps you haven't thought of — and the ones \(name) installs next.")
                .font(.footnote).foregroundStyle(.secondary)

            Divider().padding(.vertical, 2)

            Label {
                Text("Include the **website** categories too").font(.subheadline)
            } icon: {
                Image(systemName: "globe").foregroundStyle(Theme.sky)
            }
            Text("Otherwise the browser is an open door: the app is paused, the website version isn't.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .card(tint: Theme.coral)
    }
}

/// Counts only — never names, never tokens.
struct SelectionSummaryView: View {
    let summary: SelectionSummary

    var body: some View {
        HStack(spacing: 16) {
            stat(summary.applicationCount, "apps", "app.badge")
            stat(summary.categoryCount, "categories", "square.stack.3d.up.fill")
            stat(summary.webDomainCount, "websites", "globe")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.coral.opacity(0.12)))
    }

    private func stat(_ count: Int, _ label: String, _ symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.footnote).foregroundStyle(Theme.coral)
            Text("\(count)").font(.title2.bold()).contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Phase 0 stand-in for Apple's FamilyActivityPicker. Produces a category-first sample selection,
/// so the preview shows the shape we recommend rather than a handful of named apps.
struct SelectionPickerButton: View {
    let onPick: (SelectionSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onPick(MockScreenTimeSelectionService.sampleSnapshot(apps: 0, categories: 3, webDomains: 2))
            } label: {
                Label("Choose Apps & Categories", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.bordered)
            .tint(Theme.coral)
            Text("Preview build: uses a sample selection. Apple's real picker arrives with Screen Time access.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
