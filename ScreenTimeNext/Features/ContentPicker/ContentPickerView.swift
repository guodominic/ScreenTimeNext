//  ContentPickerView.swift
//  ScreenTimeNext
//
//  D-018 / D-019 — "Pick apps and categories". Scroll, tap what the budget covers, see the counts,
//  start. Browsers sit first by default (the one row that covers something no app category does,
//  and the easiest to overlook), the parent can drag the rows into whatever order suits them, and
//  "My usual" is theirs to define rather than three categories we picked for them.
//
//  Phase 0 draws these rows itself. Phase 1 replaces the rows inside `categorySection` with Apple's
//  `FamilyActivityPicker` bound to a `FamilyActivitySelection` — it is a SwiftUI view, so it drops
//  in here inline and brings its own Categories / Apps / Websites sections. The header counts and
//  the Start button read from the same `SelectionSummary` either way.
//
//  §16: no row names a real app or brand.

import SwiftUI
import Observation
import ScreenTimeNextCore

/// The parent's picks and their arrangement, in one place so the step view, Settings, the draft
/// and the counts all agree.
@Observable
final class ContentPickerModel {
    var categories: Set<ContentCategory> = []
    /// Individual apps chosen through Apple's picker. Phase 0 can only be given a sample count.
    var applicationCount: Int = 0
    /// The row order, as the parent arranged it. Always complete — see `completeOrder`.
    var order: [ContentCategory]
    /// The parent's own "my usual" set, applied by one tap.
    var favourites: [ContentCategory]
    /// False while `favourites` is still the value we chose rather than one the parent saved.
    var favouritesAreCustom: Bool
    /// Set briefly after "Save as my usual" so the parent gets a "Saved" to look at. Without it the
    /// button simply vanishes (the selection now matches) and nothing says the save happened.
    var justSavedFavourites = false

    /// D-022 — where "my usual" and the row order are written the moment they change.
    ///
    /// nil during first-run setup, deliberately. `loadConfiguration()` returns defaults rather than
    /// throwing when no file exists, so writing here would CREATE a configuration — and
    /// `hasStoredConfiguration()` is what marks the app as set up (D-016). A parent who dragged one
    /// row and quit would come back to a skipped onboarding.
    private let autosave: (any ScreenTimeStorageService)?

    init(categories: Set<ContentCategory> = [],
         applicationCount: Int = 0,
         order: [ContentCategory] = ContentCategory.defaultOrder,
         favourites: [ContentCategory] = ContentCategory.defaultFavourites,
         favouritesAreCustom: Bool = false,
         autosave: (any ScreenTimeStorageService)? = nil) {
        self.categories = categories
        self.applicationCount = applicationCount
        self.order = ContentCategory.completeOrder(order)
        self.favourites = favourites
        self.favouritesAreCustom = favouritesAreCustom
        self.autosave = autosave
    }

    var summary: SelectionSummary {
        ContentCategory.summary(categories: categories, apps: applicationCount)
    }

    var isEmpty: Bool { summary.isEmpty }

    func toggle(_ category: ContentCategory) {
        if categories.contains(category) { categories.remove(category) } else { categories.insert(category) }
        justSavedFavourites = false
    }

    func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        saveArrangement()
    }

    // MARK: My usual

    var hasFavourites: Bool { !favourites.isEmpty }

    /// True when what is ticked right now already IS the saved set — so the button can offer
    /// "save" only when saving would actually change something.
    var matchesFavourites: Bool { categories == Set(favourites) }

    func applyFavourites() {
        categories = Set(favourites)
        justSavedFavourites = false
    }

    /// D-022 — this writes to storage NOW, not when some later screen is saved.
    ///
    /// It used to only change memory: the value reached disk when the parent went on to press
    /// Settings' own Save. "Done" on the picker reads as "saved", so anyone who pressed Done and
    /// left lost what they had just saved — which is exactly what happened.
    func saveCurrentAsFavourites() {
        let picked = order.filter { categories.contains($0) }
        // Nothing ticked (or only individual apps, which have no row) is not a usable "usual" —
        // saving it would leave the button offering an empty set forever.
        guard !picked.isEmpty else { return }
        favourites = picked
        favouritesAreCustom = true
        justSavedFavourites = true
        saveArrangement()
    }

    /// The parent's arrangement — their order and their "usual". Not the ticks: those belong to the
    /// selection the surrounding screen commits (Start, or Settings' Save).
    private func saveArrangement() {
        autosave.map { try? $0.save(preferences) }
    }

    /// D-024 — written to their own record, which "Start over" leaves alone.
    var preferences: ParentPickerPreferences {
        ParentPickerPreferences(categoryOrder: order,
                                favourites: favourites,
                                favouritesAreCustom: favouritesAreCustom)
    }

    func clear() {
        categories.removeAll()
        applicationCount = 0
        justSavedFavourites = false
    }

    // MARK: Persistence
    //
    // D-021 — the ticks, the row order and "my usual" all persist, so the next launch opens on the
    // choice the parent already made. §16 is about Apple's opaque selection TOKENS, which are still
    // never stored here; these are our own catalogue rows.

    /// `autosaving` is for screens that run AFTER setup (Settings). First-run setup passes false,
    /// so nothing is written until the parent presses Start — see `autosave`.
    ///
    /// D-024 — the arrangement comes from `ParentPickerPreferences` (survives "Start over") and the
    /// ticks from the configuration (does not). After a reset there are no ticks, so the picker
    /// opens on the parent's own saved "usual" — which is what makes starting over feel like a
    /// fresh setup rather than losing your work.
    static func loaded(from storage: any ScreenTimeStorageService,
                       autosaving: Bool = false) -> ContentPickerModel {
        let preferences = (try? storage.loadPickerPreferences()) ?? .default
        let ticked = (try? storage.loadConfiguration())?.selectedCategories ?? []
        return ContentPickerModel(categories: ticked.isEmpty ? preferences.initialSelection : Set(ticked),
                                  order: preferences.categoryOrder,
                                  favourites: preferences.favourites,
                                  favouritesAreCustom: preferences.favouritesAreCustom,
                                  autosave: autosaving ? storage : nil)
    }

    /// Commit everything: the arrangement to its own record, the ticks to the configuration.
    func persist(to storage: any ScreenTimeStorageService) {
        try? storage.save(preferences)
        guard var config = try? storage.loadConfiguration() else { return }
        config.selectedCategories = order.filter { categories.contains($0) }   // stored in row order
        try? storage.save(config)
    }

    /// What gets written into the draft / configuration. Counts are ours to describe; the opaque
    /// payload is the selection adapter's business and this screen never touches it (§13/§16 —
    /// scripts/privacy-audit.sh fails the build if it does).
    func snapshot(basedOn existing: SelectionSnapshot?) -> SelectionSnapshot? {
        guard !isEmpty else { return nil }
        return existing?.withSummary(summary) ?? .phase0Placeholder(summary: summary)
    }
}

struct ContentPickerView: View {
    @Bindable var model: ContentPickerModel
    /// Shown as a lock hint on the "specific apps" row until the entitlement is live.
    var screenTimeAccessAvailable: Bool = false
    /// Onboarding sets these; Settings leaves them nil and lets the navigation title do the work.
    var headline: String?
    var subheadline: String?

    @State private var showAppPickerNote = false
    @State private var isReordering = false

    var body: some View {
        List {
            if headline != nil || subheadline != nil { titleSection }
            countSection
            categorySection
            appSection
        }
        .listSectionSpacing(12)
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
        .animation(.snappy(duration: 0.25), value: isReordering)
        .sheet(isPresented: $showAppPickerNote) {
            SpecificAppsNote(onUseSample: { model.applicationCount = 3 })
                .presentationDetents([.medium])
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

    /// The running total, plus the two one-tap shortcuts.
    private var countSection: some View {
        Section {
            HStack(spacing: 10) {
                countPill(model.summary.categoryCount, "categories", "square.stack.3d.up.fill", Theme.sky)
                countPill(model.summary.webDomainCount, "websites", "globe", Theme.mint)
                countPill(model.summary.applicationCount, "apps", "app.badge", Theme.lavender)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 8, trailing: 4))

            usualRow
        }
    }

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

    /// D-019 — "my usual" is the parent's own set, not three categories we chose for them.
    private var usualRow: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.snappy) { model.applyFavourites() } } label: {
                Label(usualLabel, systemImage: "wand.and.stars")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(Theme.coral)
            .disabled(!model.hasFavourites)

            if model.justSavedFavourites {
                // The button disappears the moment it works (the selection now matches), so
                // without this nothing tells the parent the save happened.
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.grass)
                    .transition(.opacity.combined(with: .scale))
            } else if !model.isEmpty && !model.matchesFavourites {
                Button {
                    withAnimation(.snappy) { model.saveCurrentAsFavourites() }
                } label: {
                    Label("Save as my usual", systemImage: "pin.fill")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.sky)
            }

            if !model.isEmpty {
                Button { withAnimation(.snappy) { model.clear() } } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
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

    private var usualLabel: String {
        guard model.hasFavourites else { return "No usual set yet" }
        return "My usual (\(model.favourites.count))"
    }

    // MARK: Categories — one list, in the parent's own order

    private var categorySection: some View {
        Section {
            ForEach(model.order) { category in
                row(for: category)
            }
            .onMove { model.move(from: $0, to: $1) }
        } header: {
            HStack {
                Text("Categories")
                Spacer()
                Button(isReordering ? "Done" : "Reorder") { isReordering.toggle() }
                    .font(.caption.weight(.bold))
                    .textCase(nil)
            }
        } footer: {
            Text(isReordering
                 ? "Drag the handles to put the ones you use most at the top."
                 : "Tap to include. Tap Reorder to arrange them your way.")
        }
    }

    private func row(for category: ContentCategory) -> some View {
        let isOn = model.categories.contains(category)
        let color = Self.color(for: category)
        return Button {
            withAnimation(.snappy(duration: 0.22)) { model.toggle(category) }
        } label: {
            rowLabel(category, color: color, isOn: isOn)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? AccessibilityTraits([.isButton, .isSelected]) : AccessibilityTraits.isButton)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
    }

    private func rowLabel(_ category: ContentCategory, color: Color, isOn: Bool) -> some View {
        HStack(spacing: 12) {
            IconChip(symbol: category.symbolName, color: color, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(category.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if !isReordering {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? color : Color.secondary.opacity(0.45))
                    .scaleEffect(isOn ? 1.1 : 1.0)
            }
        }
        .padding(12)
        .background(rowBackground(color: color, isOn: isOn))
    }

    private func rowBackground(color: Color, isOn: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isOn ? color.opacity(0.16) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isOn ? color.opacity(0.55) : Color.clear, lineWidth: 2)
            )
    }

    // MARK: Specific apps

    private var appSection: some View {
        Section {
            Button { showAppPickerNote = true } label: { appRowLabel }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowBackground(Color.clear)
        } header: {
            Text("Specific apps")
        }
    }

    private var appRowLabel: some View {
        HStack(spacing: 12) {
            IconChip(symbol: "plus.app.fill", color: Theme.lavender, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.applicationCount == 0
                     ? "Pick individual apps"
                     : "\(model.applicationCount) apps picked")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(screenTimeAccessAvailable
                     ? "Opens Apple's app picker"
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

    /// A stable colour per row, so the list reads as a set of friendly tiles rather than a form.
    static func color(for category: ContentCategory) -> Color {
        switch category {
        case .games:         return Theme.coral
        case .entertainment: return Theme.lavender
        case .social:        return Theme.sky
        case .creativity:    return Theme.peach
        case .education:     return Theme.mint
        case .reading:       return Theme.sun
        case .productivity:  return Theme.sky
        case .health:        return Theme.grass
        case .shopping:      return Theme.tangerine
        case .travel:        return Theme.mint
        case .utilities:     return Theme.lavender
        case .browsers:      return Theme.sky
        case .other:         return Theme.peach
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

/// Phase 0 stand-in for Apple's `FamilyActivityPicker`. Honest about why it is not here yet, and
/// still lets the counts and the Start button be exercised.
private struct SpecificAppsNote: View {
    @Environment(\.dismiss) private var dismiss
    let onUseSample: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Mascot(mood: .thinking, size: 92, tint: Theme.lavender)
            Text("Picking apps one by one")
                .font(.system(.title3, design: .rounded).bold())
            Text("iOS keeps the list of installed apps private. Choosing individual apps uses Apple's own picker, which needs Screen Time access — categories work today and cover most of what you'd pick anyway.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { onUseSample(); dismiss() } label: {
                Text("Use 3 sample apps for now")
            }
            .buttonStyle(PillButtonStyle(color: Theme.lavender))
            Button("Not now") { dismiss() }
                .font(.footnote)
        }
        .padding(24)
        .readableWidth(460)
    }
}

#Preview {
    NavigationStack {
        ContentPickerScreen(model: ContentPickerModel(categories: [.games, .browsers])) { _ in }
    }
}
