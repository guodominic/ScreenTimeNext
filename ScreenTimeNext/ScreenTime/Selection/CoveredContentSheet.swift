//  CoveredContentSheet.swift
//  ScreenTimeNext
//
//  D-028 — "which things exactly?" Counts alone leave a parent trusting a number they cannot check.
//
//  Rule 1 exception, same as the picker (D-001/D-026): this file lives in `ScreenTime/Selection/`
//  because rendering a token requires the token. §16 is not broken by it — `Label(token)` is
//  Apple's own view, which draws the name and icon INSIDE the system's process. The app never sees
//  the app's identity, cannot copy it into a string, and nothing here is logged or persisted.
//
//  Known platform bug, FB12332927: the token-to-icon mapping runs on the main thread and talks to
//  the FamilyControlAgent process, so rendering many labels at once can freeze the UI for seconds.
//  Everything here is therefore inside a `List`, which builds rows lazily — only what is on screen
//  is ever mapped.

import SwiftUI
import FamilyControls
import ManagedSettings
import ScreenTimeNextCore

struct CoveredContentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let snapshot: SelectionSnapshot

    @State private var selection: FamilyActivitySelection?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let selection {
                    content(for: selection)
                } else if failed {
                    unreadable
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("What's covered")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .task {
            do {
                selection = try FamilyActivitySelectionCoding.selection(from: snapshot)
            } catch {
                failed = true
            }
        }
    }

    @ViewBuilder
    private func content(for selection: FamilyActivitySelection) -> some View {
        if FamilyActivitySelectionCoding.isEmpty(selection) {
            ContentUnavailableView("Nothing is covered yet",
                                   systemImage: "square.dashed",
                                   description: Text("Pick some apps and categories and the timer will cover them."))
        } else {
            List {
                if !selection.categoryTokens.isEmpty {
                    Section {
                        ForEach(Array(selection.categoryTokens), id: \.self) { token in
                            Label(token)
                        }
                    } header: {
                        Text("Categories")
                    } footer: {
                        // B-005 — a category covers apps we are not allowed to enumerate, so this
                        // says what it means rather than pretending to a number we cannot know.
                        Text("A category covers every app on this device that belongs to it. iOS doesn't tell apps which ones those are, so they can't be listed here.")
                    }
                }
                if !selection.applicationTokens.isEmpty {
                    Section("Apps") {
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }
                if !selection.webDomainTokens.isEmpty {
                    Section("Websites") {
                        ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }
            }
        }
    }

    /// §6.4 — "we lost your choice" is a different message from "you chose nothing", and it has a
    /// different fix.
    private var unreadable: some View {
        ContentUnavailableView("Couldn't read this selection",
                               systemImage: "exclamationmark.triangle",
                               description: Text("Open the picker and choose again — it only takes a moment."))
    }
}
