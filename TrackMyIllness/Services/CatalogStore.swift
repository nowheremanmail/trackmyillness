//
//  CatalogStore.swift
//  TrackMyIllness
//
//  Reads and writes the configurable treatments and symptoms.
//

import Foundation
import SwiftData

@MainActor
protocol CatalogStoring {
    /// Items of a kind in display order; archived ones are excluded unless asked for.
    func items(of kind: EntryKind, includeArchived: Bool) -> [CatalogItem]
    func item(id: String) -> CatalogItem?
    /// Inserts a new item or updates the existing one with the same id.
    func save(_ item: CatalogItem)
    func delete(id: String)
    /// Rewrites `sortIndex` so the given order sticks.
    func reorder(_ items: [CatalogItem])
    /// Populates a first-run catalog so the entry form isn't empty. No-op afterwards.
    func seedDefaultsIfEmpty()
}

extension CatalogStoring {
    func items(of kind: EntryKind) -> [CatalogItem] { items(of: kind, includeArchived: false) }
}

@MainActor
final class CatalogStore: CatalogStoring {
    private let context: ModelContext

    init(container: ModelContainer = AppDatabase.container) {
        context = ModelContext(container)
    }

    func items(of kind: EntryKind, includeArchived: Bool = false) -> [CatalogItem] {
        let raw = kind.rawValue
        var descriptor = FetchDescriptor<CatalogItemRecord>(
            predicate: #Predicate { $0.kindRaw == raw },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)])
        descriptor.fetchLimit = 500
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map(\.value).filter { includeArchived || !$0.isArchived }
    }

    func item(id: String) -> CatalogItem? { record(id: id)?.value }

    func save(_ item: CatalogItem) {
        if let existing = record(id: item.id) {
            existing.apply(item)
        } else {
            context.insert(CatalogItemRecord(item))
        }
        try? context.save()
    }

    func delete(id: String) {
        guard let existing = record(id: id) else { return }
        context.delete(existing)
        try? context.save()
    }

    func reorder(_ items: [CatalogItem]) {
        for (index, item) in items.enumerated() {
            record(id: item.id)?.sortIndex = index
        }
        try? context.save()
    }

    func seedDefaultsIfEmpty() {
        var descriptor = FetchDescriptor<CatalogItemRecord>()
        descriptor.fetchLimit = 1
        guard ((try? context.fetch(descriptor)) ?? []).isEmpty else { return }
        for item in CatalogStore.defaults {
            context.insert(CatalogItemRecord(item))
        }
        try? context.save()
    }

    private func record(id: String) -> CatalogItemRecord? {
        var descriptor = FetchDescriptor<CatalogItemRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// A generic starter set — everyone edits these in Settings anyway, so they're
    /// deliberately illness-agnostic.
    static let defaults: [CatalogItem] = [
        CatalogItem(kind: .treatment, name: String(localized: "Morning medication"),
                    symbolName: "sunrise.fill", colorName: ItemColor.orange.rawValue, sortIndex: 0),
        CatalogItem(kind: .treatment, name: String(localized: "Evening medication"),
                    symbolName: "moon.stars.fill", colorName: ItemColor.indigo.rawValue, sortIndex: 1),
        CatalogItem(kind: .treatment, name: String(localized: "Painkiller"),
                    symbolName: "pills.fill", colorName: ItemColor.teal.rawValue,
                    defaultDose: "1", sortIndex: 2),
        CatalogItem(kind: .symptom, name: String(localized: "Pain"),
                    symbolName: "bolt.fill", colorName: ItemColor.red.rawValue, sortIndex: 0),
        CatalogItem(kind: .symptom, name: String(localized: "Fatigue"),
                    symbolName: "zzz", colorName: ItemColor.purple.rawValue, sortIndex: 1),
        CatalogItem(kind: .symptom, name: String(localized: "Nausea"),
                    symbolName: "drop.fill", colorName: ItemColor.green.rawValue, sortIndex: 2),
        CatalogItem(kind: .symptom, name: String(localized: "Fever"),
                    symbolName: "thermometer.high", colorName: ItemColor.pink.rawValue, sortIndex: 3),
    ]
}
