//  ActivityEditorSheet.swift
//  ScreenTimeNext
//
//  D-029 — a parent adds their own "what's next" activity: a name and an icon, kept on the device.
//
//  The eight built-ins are ours; this list is the family's. A child whose next thing is piano, or
//  walking the dog, or Nana's house should see that word on the tile — the whole point of §6.11 is
//  that the child picks something they actually want, and a generic list undercuts it.

import SwiftUI
import ScreenTimeNextCore

struct ActivityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// nil when adding; the existing activity when editing.
    let existing: TransitionActivity?
    let onSave: (TransitionActivity) -> Void

    @State private var name: String
    @State private var symbolName: String

    init(existing: TransitionActivity? = nil, onSave: @escaping (TransitionActivity) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.displayName ?? "")
        _symbolName = State(initialValue: existing?.symbolName ?? TransitionActivity.customSymbolChoices[0])
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Piano, dog walk, Nana's house…", text: $name)
                        .autocorrectionDisabled(false)
                } header: {
                    Text("What is it called?")
                } footer: {
                    Text("Your child sees this word on the tile, so use the word they use.")
                }

                Section("Pick an icon") {
                    symbolGrid
                }

                Section {
                    preview
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(existing == nil ? "Add an activity" : "Edit activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private var symbolGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 10)], spacing: 10) {
            ForEach(TransitionActivity.customSymbolChoices, id: \.self) { symbol in
                Button { symbolName = symbol } label: {
                    Image(systemName: symbol)
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .foregroundStyle(symbol == symbolName ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(symbol == symbolName ? Theme.mint : Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    /// The tile exactly as the child will see it — the only way a parent can tell whether the icon
    /// and the word go together before committing to them.
    private var preview: some View {
        VStack(spacing: 8) {
            IconChip(symbol: symbolName, color: Theme.mint, size: 54)
            Text(trimmedName.isEmpty ? "Your activity" : trimmedName)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)
        }
        .padding(.vertical, 8)
    }

    private func save() {
        guard canSave else { return }
        if let existing {
            onSave(existing.renamed(to: trimmedName, symbolName: symbolName))
        } else {
            onSave(.custom(displayName: trimmedName, symbolName: symbolName))
        }
        dismiss()
    }
}
