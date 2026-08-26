//
//  LogEntryViewModel.swift
//  TrackMyIllness
//
//  Backs the Report tab: pick treatment or symptom, pick the item, adjust when it
//  happened, save. Optimised for as few taps as possible.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class LogEntryViewModel {
    // MARK: Form state

    var kind: EntryKind = .treatment {
        didSet {
            guard kind != oldValue else { return }
            UserDefaults.standard.set(kind.rawValue, forKey: AppSettings.lastEntryKindKey)
            selectedItemID = nil
            dose = ""
            severity = 0
            reloadItems()
        }
    }

    /// When the event happened. Both the date and the time pickers bind to this.
    var timestamp: Date = .now {
        didSet {
            // A manual edit means no shortcut is "current" any more.
            if !applyingShortcut { activeShortcut = nil }
        }
    }

    var selectedItemID: String?
    var dose: String = ""
    /// 1–5 for symptoms, 0 when not recorded.
    var severity: Int = 0
    var note: String = ""

    /// The highlighted quick-time button, if the time came from one.
    private(set) var activeShortcut: TimeShortcut? = .now
    private var applyingShortcut = false

    // MARK: Data

    private(set) var items: [CatalogItem] = []
    /// Everything logged today, newest first — the confirmation that a tap landed.
    private(set) var today: [LogEntry] = []
    /// Set after a save so the view can show a brief confirmation and offer undo.
    private(set) var lastSavedEntry: LogEntry?

    private let catalog: CatalogStoring
    private let entries: EntryStoring
    private let calendar: Calendar

    init(catalog: CatalogStoring? = nil,
         entries: EntryStoring? = nil,
         calendar: Calendar = .current) {
        self.catalog = catalog ?? CatalogStore()
        self.entries = entries ?? EntryStore()
        self.calendar = calendar
        if let raw = UserDefaults.standard.string(forKey: AppSettings.lastEntryKindKey),
           let stored = EntryKind(rawValue: raw) {
            // Safe inside init: property observers don't fire here, so this doesn't
            // bounce the value straight back into UserDefaults.
            kind = stored
        }
    }

    // MARK: Loading

    /// Called when the tab appears: the catalog may have changed in Settings.
    func refresh() {
        reloadItems()
        reloadToday()
    }

    private func reloadItems() {
        items = catalog.items(of: kind)
        // A selection that no longer exists (archived/deleted in Settings) must go.
        if let id = selectedItemID, !items.contains(where: { $0.id == id }) {
            selectedItemID = nil
        }
    }

    private func reloadToday() {
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? .now
        today = entries.entries(in: start...end)
    }

    // MARK: Editing

    var selectedItem: CatalogItem? {
        items.first { $0.id == selectedItemID }
    }

    var canSave: Bool { selectedItem != nil }

    /// Whether the form should ask for a severity (symptoms that opt in).
    var showsSeverity: Bool {
        kind == .symptom && (selectedItem?.tracksSeverity ?? false)
    }

    var showsDose: Bool { kind == .treatment }

    func select(_ item: CatalogItem) {
        // Tapping the selected chip again deselects, so a mis-tap is one tap to fix.
        if selectedItemID == item.id {
            selectedItemID = nil
            dose = ""
            return
        }
        selectedItemID = item.id
        dose = item.defaultDose
        if item.kind == .symptom, item.tracksSeverity, severity == 0 { severity = 3 }
    }

    func apply(_ shortcut: TimeShortcut) {
        applyingShortcut = true
        timestamp = shortcut.date()
        applyingShortcut = false
        activeShortcut = shortcut
    }

    /// Resets the date to today at the current time (the "Today" button).
    func resetToNow() { apply(.now) }

    // MARK: Saving

    @discardableResult
    func save() -> Bool {
        guard let item = selectedItem else { return false }
        let entry = LogEntry(
            kind: kind,
            itemID: item.id,
            itemName: item.name,
            symbolName: item.symbolName,
            colorName: item.colorName,
            date: timestamp,
            dose: showsDose ? dose.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            severity: showsSeverity ? severity : 0,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        entries.add(entry)
        lastSavedEntry = entry
        clearForm()
        reloadToday()
        return true
    }

    /// Removes the entry that was just saved (the "Undo" in the confirmation).
    func undoLastSave() {
        guard let entry = lastSavedEntry else { return }
        entries.delete(id: entry.id)
        lastSavedEntry = nil
        reloadToday()
    }

    func dismissConfirmation() { lastSavedEntry = nil }

    func delete(_ entry: LogEntry) {
        entries.delete(id: entry.id)
        if lastSavedEntry?.id == entry.id { lastSavedEntry = nil }
        reloadToday()
    }

    private func clearForm() {
        selectedItemID = nil
        dose = ""
        severity = 0
        note = ""
        apply(.now)
    }
}
