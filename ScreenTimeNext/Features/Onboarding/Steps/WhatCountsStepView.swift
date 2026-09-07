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

    /// D-061 — the door a parent comes through after "Start over", and the one that had no check.
    @State private var warning: StartWarning?

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
                              // D-058 — the row that asks. Without it this screen states a
                              // prerequisite it gives no way to satisfy, which on a fresh install
                              // is every parent's first run.
                              onRequestAccess: { Task { await viewModel.requestAuthorization() } },
                              isRequestingAccess: viewModel.isRequestingAuthorization,
                              accessDenied: viewModel.authorization == .denied,
                              headline: "Pick apps and categories",
                              subheadline: "The \(minutes)-minute timer covers whatever you tick.")
                .scrollContentBackground(.hidden)
                .onChange(of: picker.summary) { _, _ in viewModel.selectionChanged() }
                .safeAreaInset(edge: .bottom) { startBar }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // D-059 — ASK, don't wait to be asked.
        //
        // D-058 added a row a parent could tap to grant access. Better than nothing, but it still
        // put the burden on them to notice a prerequisite and act on it, on the one screen where
        // they are trying to do something else. iOS shows its own dialog and only ever asks once,
        // so the honest place for it is the moment this screen opens: the parent sees the system
        // prompt, allows, and the list underneath is live by the time they look at it.
        //
        // The row stays, for the parent who declined and later changed their mind — `.denied` is
        // not `.notDetermined`, and re-prompting someone who said no is not asking, it is nagging.
        .alert(item: $warning) { warning in
            Alert(title: Text(warning.title),
                  message: Text(warning.message),
                  // The fix is right here on this screen, so the first button just closes the
                  // alert and leaves them looking at the list they need.
                  primaryButton: .default(Text(warning.fixLabel)),
                  secondaryButton: .cancel(Text(warning.proceedLabel)) {
                      if viewModel.startNow() { onStart() }
                  })
        }
        .task {
            // D-063 — `ContentPickerView` asks on arrival now, for every door into it. Asking
            // here as well would be two requests racing for one system dialog.
            await viewModel.loadAuthorizationStatus()
        }
    }

    private var startBar: some View {
        VStack(spacing: 6) {
            Button { attemptStart() } label: {
                Label("Start \(minutes) minutes", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle(color: Theme.mint))

            // D-061 — this line used to read "you can pick later in Settings", which told a parent
            // the empty state was fine. It is not fine: it is a timer that will do nothing. Saying
            // so plainly here, and stopping once at the button, is the whole fix.
            Text(hasSelection ? selectionLine : "Nothing ticked — the timer will not cover anything.")
                .font(.caption)
                .foregroundStyle(hasSelection ? .secondary : Color.orange)

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

    /// D-061 — the same question the dashboard asks, in the same words, at the other door.
    private func attemptStart() {
        guard hasSelection else {
            warning = .nothingCovered
            return
        }
        if viewModel.startNow() { onStart() }
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
