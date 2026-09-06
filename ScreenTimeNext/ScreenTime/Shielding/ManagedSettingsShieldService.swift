//  ManagedSettingsShieldService.swift
//  ScreenTimeNext
//
//  Task 011 — the real `ScreenTimeShieldService`. PRD §14, §15.
//
//  Rule 6, and the reason this file is short and careful: `ManagedSettingsStore` is a SHARED
//  system surface. Apple's own Screen Time writes to it, and so does every other parental-control
//  app on the device. `clearAllSettings()` on the default store would erase theirs along with ours
//  — a family could lose the Screen Time rules they set up over months because our timer ended.
//  So:
//    · we own exactly one NAMED store (`screentimenext`), and never touch the default one;
//    · we never call `clearAllSettings()` anywhere — removal sets our own four keys to nil;
//    · we shield exactly what the parent's selection names, never `.all(except:)`, so a phone
//      call, Messages, or the camera is never covered by us (§15).
//
//  Callable from the app AND from an extension with no app process, so nothing here touches UI or
//  assumes a run loop.
//
//  API verified against Apple's documentation (2026-09-06), per Rule 8:
//      ManagedSettingsStore(named: ManagedSettingsStore.Name)
//      store.shield.applications          : Set<ApplicationToken>?
//      store.shield.webDomains            : Set<WebDomainToken>?
//      store.shield.applicationCategories : ShieldSettings.ActivityCategoryPolicy<Application>?
//      store.shield.webDomainCategories   : ShieldSettings.ActivityCategoryPolicy<WebDomain>?
//      ActivityCategoryPolicy: .none · .all(except:) · .specific(_:except:)
//      store.webContent.blockedByFilter   : WebContentSettings.FilterPolicy?  (D-033)

import FamilyControls
import Foundation
import ManagedSettings
import ScreenTimeNextCore

extension ManagedSettingsStore.Name {
    /// Ours, and only ours. Everything this app shields lives under this name so that removing it
    /// cannot reach anyone else's settings.
    static let screenTimeNext = Self("screentimenext")
}

final class ManagedSettingsShieldService: ScreenTimeShieldService, @unchecked Sendable {

    private let store = ManagedSettingsStore(named: .screenTimeNext)
    private let storage: (any ScreenTimeStorageService)?
    private let preferences: () -> ParentPickerPreferences

    /// `storage` is optional so the extension can construct this with nothing but the App Group.
    init(storage: (any ScreenTimeStorageService)? = nil) {
        self.storage = storage
        let capturedStorage = storage
        preferences = { (try? capturedStorage?.loadPickerPreferences()) ?? .default }
    }

    // MARK: ScreenTimeShieldService

    func applyShield(for selection: SelectionSnapshot) throws {
        let picked = try FamilyActivitySelectionCoding.selection(from: selection)
        guard !FamilyActivitySelectionCoding.isEmpty(picked) else {
            // Nothing to cover. Saying so beats writing an empty shield that looks armed.
            throw ScreenTimeShieldError.noSelection
        }

        // Idempotent by construction: these are assignments, not appends. Applying twice writes
        // the same four values twice, which is the same as writing them once.
        store.shield.applications = picked.applicationTokens.isEmpty ? nil : picked.applicationTokens
        store.shield.applicationCategories = picked.categoryTokens.isEmpty
            ? nil
            : .specific(picked.categoryTokens, except: Set())
        store.shield.webDomains = picked.webDomainTokens.isEmpty ? nil : picked.webDomainTokens
        store.shield.webDomainCategories = picked.categoryTokens.isEmpty
            ? nil
            : .specific(picked.categoryTokens, except: Set())

        applyTypedWebsites()
        write(.shielded)
    }

    func removeShield() throws {
        // Rule 6 — our four keys, by name. NEVER `store.clearAllSettings()`: that would also erase
        // whatever Apple's Screen Time and any other parental-control app wrote to this device.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        store.webContent.blockedByFilter = nil
        write(.unshielded)
    }

    var currentProtectionState: ProtectionState {
        (try? storage?.loadProtectionState()) ?? .unshielded
    }

    // MARK: Typed websites (D-033)

    /// A separate mechanism to the selection: `WebDomain(domain:)` takes a plain string, so these
    /// need no token and no picker. Applied alongside the shield because a parent who typed a site
    /// meant it to be blocked while the budget is spent, not merely covered when tapped.
    private func applyTypedWebsites() {
        let typed = preferences().blockedWebsites
        guard !typed.isEmpty else {
            store.webContent.blockedByFilter = nil
            return
        }
        store.webContent.blockedByFilter = .specific(Set(typed.map { WebDomain(domain: $0) }))
    }

    private func write(_ state: ProtectionState) {
        try? storage?.save(state)
    }
}
