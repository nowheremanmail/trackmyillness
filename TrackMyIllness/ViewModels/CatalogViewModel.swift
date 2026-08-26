//
//  CatalogViewModel.swift
//  TrackMyIllness
//
//  Backs the Settings screens that configure which treatments and symptoms can be
//  reported.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class CatalogViewModel {
    private(set) var treatments: [CatalogItem] = []
    private(set) var symptoms: [CatalogItem] = []

    private let store: CatalogStoring

    init(store: CatalogStoring? = nil) {
        self.store = store ?? CatalogStore()
    }

    func refresh() {
        treatments = store.items(of: .treatment, includeArchived: true)
        symptoms = store.items(of: .symptom, includeArchived: true)
    }

    func items(of kind: EntryKind) -> [CatalogItem] {
        kind == .treatment ? treatments : symptoms
    }

    /// True when there's nothing to report yet — a fresh install, since the app no
    /// longer creates a starter catalog.
    var isEmpty: Bool { treatments.isEmpty && symptoms.isEmpty }

    /// A blank item ready for the editor, pre-slotted at the end of its list.
    func newItem(of kind: EntryKind) -> CatalogItem {
        CatalogItem(kind: kind,
                    symbolName: kind.systemImage,
                    colorName: (kind == .treatment ? ItemColor.teal : ItemColor.orange).rawValue,
                    tracksSeverity: kind == .symptom,
                    sortIndex: items(of: kind).count)
    }

    func save(_ item: CatalogItem) {
        var item = item
        item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.defaultDose = item.defaultDose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.name.isEmpty else { return }
        store.save(item)
        refresh()
    }

    func delete(_ item: CatalogItem) {
        store.delete(id: item.id)
        refresh()
    }

    func delete(at offsets: IndexSet, in kind: EntryKind) {
        let list = items(of: kind)
        for index in offsets where list.indices.contains(index) {
            store.delete(id: list[index].id)
        }
        refresh()
    }

    func move(from offsets: IndexSet, to destination: Int, in kind: EntryKind) {
        var list = items(of: kind)
        list.move(fromOffsets: offsets, toOffset: destination)
        store.reorder(list)
        refresh()
    }

    /// Hides an item from the entry form without losing the history that used it.
    func setArchived(_ archived: Bool, for item: CatalogItem) {
        var updated = item
        updated.isArchived = archived
        store.save(updated)
        refresh()
    }

    // MARK: Predefined illnesses

    /// Creates whatever the illness offers that isn't configured yet. Returns how
    /// many items were created, so the picker can confirm what happened.
    @discardableResult
    func add(_ illness: IllnessTemplate) -> Int {
        let added = store.add(illness)
        if added > 0 { refresh() }
        return added
    }

    /// Whether the catalog already has an item by this name, so the picker can show
    /// what a pick would really create rather than promising the whole list.
    func isConfigured(_ item: IllnessItem, of kind: EntryKind) -> Bool {
        let key = item.name.catalogMatchKey
        return items(of: kind).contains { $0.name.catalogMatchKey == key }
    }

    /// Throws the whole catalog away, so the user can start from a template again.
    /// Entries are the entry store's business — Settings clears both.
    func reset() {
        store.deleteAll()
        refresh()
    }

    /// How many of the illness's items are still missing. Zero means there's
    /// nothing left for "Add" to do.
    func pendingCount(in illness: IllnessTemplate) -> Int {
        EntryKind.allCases.reduce(0) { total, kind in
            total + illness.items(of: kind).filter { !isConfigured($0, of: kind) }.count
        }
    }
}
