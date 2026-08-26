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

    func seedDefaultsIfEmpty() {
        store.seedDefaultsIfEmpty()
        refresh()
    }
}
