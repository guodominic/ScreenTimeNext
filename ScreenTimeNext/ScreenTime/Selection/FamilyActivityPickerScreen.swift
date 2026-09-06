//  FamilyActivityPickerScreen.swift
//  ScreenTimeNext
//
//  Task 005 / D-026 — the wrapper that hosts Apple's `FamilyActivityPicker`.
//
//  Rule 1 has exactly one documented exception (D-001) and this is it: `FamilyActivityPicker` is an
//  Apple SwiftUI view that must bind to a live `FamilyActivitySelection`, so the framework type and
//  the view have to meet. The exception is confined to this file — it hands back an opaque
//  `SelectionSnapshot` and nothing above it ever sees a token.
//
//  Only a human tapping in this picker can produce tokens. Nothing can be pre-selected
//  programmatically from a category name (B-005), which is why this screen exists at all.

import SwiftUI
import FamilyControls
import ScreenTimeNextCore

struct FamilyActivityPickerScreen: View {
    @Environment(\.dismiss) private var dismiss

    /// Seeded from what the parent picked last time, so reopening the picker shows their choices
    /// ticked rather than a blank slate.
    @State private var selection: FamilyActivitySelection
    @State private var errorText: String?

    private let onSave: (SelectionSnapshot?) -> Void

    init(existing: SelectionSnapshot?, onSave: @escaping (SelectionSnapshot?) -> Void) {
        // A record we cannot decode starts the picker empty rather than failing to open: the parent
        // is here to choose, and an error screen in the way of that helps nobody. The dashboard is
        // where a lost selection gets reported (§6.4).
        let restored = existing.flatMap { try? FamilyActivitySelectionCoding.selection(from: $0) }
        _selection = State(initialValue: restored ?? FamilyActivitySelection())
        self.onSave = onSave
    }

    var body: some View {
        FamilyActivityPicker(selection: $selection)
            .navigationTitle("Pick apps and categories")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { footer }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                }
            }
    }

    /// The live counts, so the parent can see the picker's effect without counting rows themselves.
    private var footer: some View {
        VStack(spacing: 6) {
            SelectionSummaryView(summary: FamilyActivitySelectionCoding.summary(of: selection))
            if let errorText {
                Text(errorText).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .readableWidth(560)
    }

    private func save() {
        guard !FamilyActivitySelectionCoding.isEmpty(selection) else {
            // Saving nothing is a legitimate choice — it means "the budget covers nothing yet".
            onSave(nil)
            dismiss()
            return
        }
        do {
            onSave(try FamilyActivitySelectionCoding.snapshot(from: selection))
            dismiss()
        } catch {
            errorText = "Couldn't save that selection. Please try again."
        }
    }
}
