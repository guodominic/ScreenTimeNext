//  ContentPickerView.swift
//  ScreenTimeNext
//
//  D-035 — "Pick apps and categories". One honest screen:
//    • Apple's `FamilyActivityPicker` is the ONLY way to choose apps and categories. It is the only
//      thing that produces enforceable tokens (B-005), so it is the only thing we offer.
//    • Websites typed by hand (D-033), which `ManagedSettings` blocks from a plain string and which
//      Apple's picker would never have offered.
//    • The running counts, tappable to see exactly what is covered.
//    • Saved sets (D-030), so a whole selection comes back in one tap.
//
//  There are no category tiles. They looked like they picked something and they did not: only a
//  token from Apple's picker can shield anything. A control that promises what it cannot deliver is
//  worse than no control at all.
//
//  §16: nothing here names a real app or brand.

import SwiftUI
import Observation
import ScreenTimeNextCore

/// The parent's picks and their arrangement, in one place so the step view, Settings, the draft
/// and the counts all agree.
@Observable
final class ContentPickerModel {

    /// D-035 — what Apple's picker produced. The ONLY thing that can shield an app or a category.
    var realSelection: SelectionSnapshot?

    /// D-033 — websites the parent typed. Blocked by name, not by token, so unlike the selection
    /// these do not come from Apple's picker at all.
    var blockedWebsites: [String] = []

    /// D-030 — whole selections the parent named, re-applied in one tap.
    var savedSelections: [SavedSelection] = []

    /// D-027 — where a real selection is written the moment Apple's picker returns one.
    private let selectionStore: (any ScreenTimeSelectionService)?
    /// D-022 — where the parent's own lists are written the moment they change.
    private let autosave: (any ScreenTimeStorageService)?

    init(autosave: (any ScreenTimeStorageService)? = nil,
         selectionStore: (any ScreenTimeSelectionService)? = nil) {
        self.autosave = autosave
        self.selectionStore = selectionStore
    }

    var summary: SelectionSummary { realSelection?.summary ?? .empty }

    /// True once the parent has picked through Apple's picker — i.e. once anything is enforceable.
    var hasRealSelection: Bool { !(realSelection?.summary.isEmpty ?? true) }

    var isEmpty: Bool { !hasRealSelection && blockedWebsites.isEmpty }

    // MARK: Selection

    /// Apple's picker came back. Keep it AND write it, in that order, right now (D-027).
    func applyRealSelection(_ picked: SelectionSnapshot?) {
        realSelection = picked
        if let selectionStore {
            if let picked { try? selectionStore.save(picked) } else { try? selectionStore.clearSelection() }
        }
        NotificationCenter.default.post(name: .configurationDidChange, object: nil)
    }

    /// Back to nothing — the picker's selection AND the typed sites, because "Clear" that leaves
    /// half the list behind is the kind of half-measure a parent finds out about at bedtime.
    func clearAll() {
        blockedWebsites = []
        saveLists()
        applyRealSelection(nil)
    }

    // MARK: Websites (D-033)

    @discardableResult
    func addWebsite(_ raw: String) -> Bool {
        var preferences = ParentPickerPreferences(blockedWebsites: blockedWebsites)
        guard preferences.addWebsite(raw) else { return false }
        blockedWebsites = preferences.blockedWebsites
        saveLists()
        return true
    }

    func removeWebsite(_ domain: String) {
        blockedWebsites.removeAll { $0 == domain }
        saveLists()
    }

    // MARK: Saved sets (D-030)

    var canSaveCurrentSelection: Bool { realSelection != nil }

    func saveCurrentSelection(named name: String) {
        guard let realSelection else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let index = savedSelections.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            savedSelections[index].snapshot = realSelection      // same name means replace, not duplicate
        } else {
            savedSelections.append(SavedSelection(name: trimmed, snapshot: realSelection))
        }
        saveLists()
    }

    func apply(_ saved: SavedSelection) { applyRealSelection(saved.snapshot) }

    func delete(_ saved: SavedSelection) {
        savedSelections.removeAll { $0.id == saved.id }
        saveLists()
    }

    // MARK: Persistence

    /// D-029 — MERGES into the stored record. It also holds the parent's custom activities and
    /// their order, which this screen knows nothing about; writing a fresh one would delete them.
    func preferences(mergedInto existing: ParentPickerPreferences?) -> ParentPickerPreferences {
        var merged = existing ?? .default
        merged.savedSelections = savedSelections
        merged.blockedWebsites = blockedWebsites
        return merged
    }

    private func saveLists() {
        guard let autosave else { return }
        try? autosave.save(preferences(mergedInto: try? autosave.loadPickerPreferences()))
    }

    static func loaded(from storage: any ScreenTimeStorageService,
                       selection: (any ScreenTimeSelectionService)? = nil,
                       autosaving: Bool = false) -> ContentPickerModel {
        let preferences = (try? storage.loadPickerPreferences()) ?? .default
        let model = ContentPickerModel(autosave: autosaving ? storage : nil, selectionStore: selection)
        model.savedSelections = preferences.savedSelections
        model.blockedWebsites = preferences.blockedWebsites
        model.realSelection = try? selection?.loadSelection()
        return model
    }

    /// Commit on the way out of first-run setup, where nothing autosaves (D-022).
    func persist(to storage: any ScreenTimeStorageService) {
        try? storage.save(preferences(mergedInto: try? storage.loadPickerPreferences()))
    }

    func snapshot(basedOn existing: SelectionSnapshot?) -> SelectionSnapshot? { realSelection }
}

struct ContentPickerView: View {
    @Bindable var model: ContentPickerModel
    /// Without Screen Time access nothing here can be enforced, and the screen says so.
    var screenTimeAccessAvailable: Bool = false
    /// Onboarding sets these; Settings leaves them nil and lets the navigation title do the work.
    var headline: String?
    var subheadline: String?

    @State private var showSystemPicker = false
    @State private var showCoveredContent = false
    @State private var showSaveSetSheet = false
    @State private var newWebsite = ""
    @State private var websiteError: String?

    /// A stored selection only MEANS anything while Screen Time access exists. Without it, even a
    /// real snapshot enforces nothing, and a green shield saying otherwise would be a lie.
    private var isEnforceable: Bool { screenTimeAccessAvailable && model.hasRealSelection }

    var body: some View {
        List {
            if headline != nil || subheadline != nil { titleSection }
            countSection
            appSection
            websiteSection
        }
        .listSectionSpacing(12)
        .sheet(isPresented: $showSaveSetSheet) {
            SaveSelectionSetSheet { name in model.saveCurrentSelection(named: name) }
                .presentationDetents([.height(240)])
        }
        .sheet(isPresented: $showCoveredContent) {
            if let snapshot = model.realSelection {
                CoveredContentSheet(snapshot: snapshot)
            }
        }
        .sheet(isPresented: $showSystemPicker) {
            NavigationStack {
                FamilyActivityPickerScreen(existing: model.realSelection) { picked in
                    model.applyRealSelection(picked)
                }
            }
        }
    }

    // MARK: Header

    private var titleSection: some View {
        Section {
            HStack(spacing: 12) {
                Mascot(mood: .thinking, size: 54, tint: Theme.coral, animated: false)
                VStack(alignment: .leading, spacing: 2) {
                    if let headline {
                        Text(headline)
                            .font(.system(.title2, design: .rounded).bold())
                            .minimumScaleFactor(0.8)
                    }
                    if let subheadline {
                        Text(subheadline).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
        }
    }

    /// The running total, plus the saved-set shortcuts.
    private var countSection: some View {
        Section {
            countRow
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 8, trailing: 4))

            toolsRow
        } footer: {
            // D-038 — the honest answer to "so how many apps IS that?", said where the question
            // gets asked rather than left for a parent to wonder about.
            VStack(alignment: .leading, spacing: 4) {
                if model.summary.categoryCount > 0 {
                    Text("Each category covers every app in it. iOS doesn't tell apps which apps those are, or how many — only Apple's picker knows, which is why the picking happens in there.")
                }
                if isEnforceable {
                    Text("Tap the numbers to see exactly what's covered.")
                }
            }
        }
    }

    @ViewBuilder
    private var countRow: some View {
        let pills = HStack(spacing: 10) {
            countPill(model.summary.categoryCount, "categories", "square.stack.3d.up.fill", Theme.sky)
            // D-038 — "apps PICKED", not "apps covered". A ticked category covers every app inside
            // it, and this number does not include them, because iOS never tells us what they are
            // (B-005). Labelling it "apps" made a screen with one whole category ticked read
            // "0 apps", which is the opposite of what is true.
            countPill(model.summary.applicationCount, "apps picked", "app.badge", Theme.lavender)
            countPill(websiteCount, "websites", "globe", Theme.mint)
        }
        if isEnforceable {
            Button { showCoveredContent = true } label: { pills }
                .buttonStyle(.plain)
        } else {
            pills
        }
    }

    /// Apple's picker can carry web domains too, and the parent can type their own (D-033). Both
    /// end up blocked, so both belong in the one number.
    private var websiteCount: Int { model.summary.webDomainCount + model.blockedWebsites.count }

    private func countPill(_ count: Int, _ label: String, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(count > 0 ? color : Color.secondary)
            Text("\(count)")
                .font(.system(.title3, design: .rounded).bold())
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(count > 0 ? color.opacity(0.14) : Color(.secondarySystemBackground)))
    }

    /// Saved sets, and a way back to nothing.
    private var toolsRow: some View {
        HStack(spacing: 10) {
            savedSetsMenu
            if !model.isEmpty {
                Button { withAnimation(.snappy) { model.clearAll() } } label: {
                    Label("Clear", systemImage: "xmark")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .accessibilityLabel("Clear everything")
            }
            Spacer(minLength: 0)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
    }

    /// D-030 — one tap re-applies a whole saved selection.
    private var savedSetsMenu: some View {
        Menu {
            if model.savedSelections.isEmpty {
                Text("No saved sets yet")
            } else {
                ForEach(model.savedSelections) { saved in
                    Button {
                        model.apply(saved)
                    } label: {
                        Text("\(saved.name) — \(saved.subtitle)")
                    }
                }
                Divider()
                Menu("Delete a set") {
                    ForEach(model.savedSelections) { saved in
                        Button(role: .destructive) { model.delete(saved) } label: { Text(saved.name) }
                    }
                }
            }
            if model.canSaveCurrentSelection {
                Divider()
                Button { showSaveSetSheet = true } label: {
                    Label("Save this as a set…", systemImage: "square.and.arrow.down")
                }
            }
        } label: {
            Label(model.savedSelections.isEmpty ? "Saved sets" : "Saved sets (\(model.savedSelections.count))",
                  systemImage: "bookmark.fill")
                .font(.footnote.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(Theme.mint)
    }

    // MARK: Apps and categories — Apple's picker, and nothing pretending to be it

    private var appSection: some View {
        Section {
            Button {
                if screenTimeAccessAvailable { showSystemPicker = true }
            } label: {
                appRowLabel
            }
            .buttonStyle(.plain)
            .disabled(!screenTimeAccessAvailable)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .listRowBackground(Color.clear)
        } header: {
            Text("Apps and categories")
        } footer: {
            Text(screenTimeAccessAvailable
                 ? "iOS keeps the list of installed apps private, so choosing happens inside Apple's own picker. Whole categories are in there too."
                 : "Turn on Screen Time access first — without it nothing can be covered.")
        }
    }

    private var appRowLabel: some View {
        HStack(spacing: 12) {
            IconChip(symbol: isEnforceable ? "checkmark.shield.fill" : "plus.app.fill",
                     color: isEnforceable ? Theme.grass : Theme.lavender, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(appRowTitle)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(screenTimeAccessAvailable
                     ? "Opens Apple's picker — apps, categories and sites"
                     : "Needs Screen Time access")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: screenTimeAccessAvailable ? "chevron.right" : "lock.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.secondarySystemBackground)))
    }

    private var appRowTitle: String {
        if isEnforceable {
            let s = model.summary
            var parts: [String] = []
            if s.categoryCount > 0 { parts.append("\(s.categoryCount) categories") }
            if s.applicationCount > 0 { parts.append("\(s.applicationCount) apps") }
            if s.webDomainCount > 0 { parts.append("\(s.webDomainCount) websites") }
            return parts.isEmpty ? "Change what's covered" : parts.joined(separator: " · ")
        }
        return screenTimeAccessAvailable ? "Choose what's covered" : "Pick apps and categories"
    }

    // MARK: Websites (D-033)

    /// Typed, not picked. `ManagedSettings` blocks a domain from a plain string, so this is the one
    /// part of "what's covered" that does not need Apple's picker — and the one place a parent can
    /// name a site the picker would never have offered them.
    private var websiteSection: some View {
        Section {
            ForEach(model.blockedWebsites, id: \.self) { domain in
                HStack(spacing: 12) {
                    IconChip(symbol: "globe", color: Theme.mint, size: 30)
                    Text(domain).font(.system(.body, design: .rounded))
                    Spacer(minLength: 0)
                }
                .swipeActions {
                    Button(role: .destructive) { model.removeWebsite(domain) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            HStack(spacing: 10) {
                IconChip(symbol: "plus", color: Theme.mint, size: 30)
                TextField("youtube.com", text: $newWebsite)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit(addTypedWebsite)
                Button("Add", action: addTypedWebsite)
                    .buttonStyle(.bordered)
                    .tint(Theme.mint)
                    .disabled(newWebsite.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let websiteError {
                Text(websiteError).font(.caption).foregroundStyle(Theme.ruby)
            }
        } header: {
            Text("Websites you type")
        } footer: {
            Text("Type a site to block it in every browser, including private browsing. Swipe to remove.")
        }
    }

    private func addTypedWebsite() {
        let typed = newWebsite
        guard !typed.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if model.addWebsite(typed) {
            newWebsite = ""
            websiteError = nil
        } else {
            websiteError = ParentPickerPreferences.normalizedDomain(typed) == nil
                ? "That doesn't look like a website address."
                : "That one's already on the list."
        }
    }
}

/// The same picker as its own screen, for Settings. Onboarding embeds `ContentPickerView` inline
/// instead, so the parent never leaves the flow.
struct ContentPickerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: ContentPickerModel
    var screenTimeAccessAvailable: Bool = false
    let onDone: (SelectionSnapshot?) -> Void

    var body: some View {
        ContentPickerView(model: model, screenTimeAccessAvailable: screenTimeAccessAvailable)
            .navigationTitle("Pick apps and categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(model.snapshot(basedOn: nil))
                        dismiss()
                    }
                }
            }
    }
}

/// D-030 — naming a set. Kept to one field and two buttons: this appears mid-task, while a parent
/// is already deciding something else.
private struct SaveSelectionSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("School nights, weekend, holidays…", text: $name)
                } footer: {
                    Text("Saves everything currently picked — apps, categories and websites — so you can bring it all back with one tap.")
                }
            }
            .navigationTitle("Name this set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(name); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContentPickerScreen(model: ContentPickerModel()) { _ in }
    }
}
