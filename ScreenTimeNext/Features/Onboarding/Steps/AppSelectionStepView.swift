//  AppSelectionStepView.swift — PRD §6.4
//
//  Phase 0: the picker is mocked. Task 005 swaps `SelectionPickerButton` for the
//  FamilyActivityPicker wrapper from ScreenTime/Selection/ (D-001). This step never sees
//  app names or tokens — only the display-safe summary (PRD §16).
import SwiftUI
import ScreenTimeNextCore

struct AppSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var name: String { viewModel.draft.trimmedChildName }

    var body: some View {
        OnboardingStepScaffold(
            title: "Choose what counts",
            subtitle: "Pick the apps, categories and websites that count toward \(name)'s screen time.",
            buttonTitle: viewModel.draft.hasSelection ? "Continue" : "Skip for now",
            action: { viewModel.advance(to: .budget) }
        ) {
            if let summary = viewModel.draft.selection?.summary, !summary.isEmpty {
                SelectionSummaryView(summary: summary)
                Button("Change selection") { viewModel.clearSelection() }
                    .buttonStyle(.bordered)
            } else {
                SelectionPickerButton { snapshot in
                    viewModel.applySelection(snapshot)
                }
            }
        }
    }
}

/// Counts only — never names, never tokens.
struct SelectionSummaryView: View {
    let summary: SelectionSummary

    var body: some View {
        HStack(spacing: 16) {
            stat(summary.applicationCount, "apps")
            stat(summary.categoryCount, "categories")
            stat(summary.webDomainCount, "websites")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1)))
    }

    private func stat(_ count: Int, _ label: String) -> some View {
        VStack {
            Text("\(count)").font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Phase 0 stand-in for Apple's FamilyActivityPicker. Produces a plausible sample selection.
struct SelectionPickerButton: View {
    let onPick: (SelectionSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Choose Apps & Categories") {
                onPick(MockScreenTimeSelectionService.sampleSnapshot(apps: 3, categories: 1, webDomains: 0))
            }
            .buttonStyle(.bordered)
            Text("Preview build: uses a sample selection. The real picker arrives with Screen Time access.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
