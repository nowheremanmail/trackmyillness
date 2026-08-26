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
    /// Creates the items of a predefined illness that aren't configured yet, and
    /// returns how many were created.
    @discardableResult
    func add(_ illness: IllnessTemplate) -> Int
    /// Removes every configured treatment and symptom. Destructive.
    func deleteAll()
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

    /// Appends whatever the illness offers that isn't configured yet, matching on
    /// name within a kind. Picking two illnesses that share a symptom therefore
    /// creates it once, and picking the same illness twice creates nothing the
    /// second time — the first copy keeps whatever the user has since renamed,
    /// recoloured or hidden it to.
    @discardableResult
    func add(_ illness: IllnessTemplate) -> Int {
        var added = 0
        for kind in EntryKind.allCases {
            // Archived items count as configured: re-creating one would put a
            // duplicate in the entry form the user had deliberately cleared out.
            let existing = items(of: kind, includeArchived: true)
            var taken = Set(existing.map { $0.name.catalogMatchKey })
            var nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1

            for template in illness.items(of: kind) {
                let key = template.name.catalogMatchKey
                guard !key.isEmpty, taken.insert(key).inserted else { continue }
                context.insert(CatalogItemRecord(
                    template.catalogItem(kind: kind, sortIndex: nextIndex)))
                nextIndex += 1
                added += 1
            }
        }
        if added > 0 { try? context.save() }
        return added
    }

    func deleteAll() {
        try? context.delete(model: CatalogItemRecord.self)
        try? context.save()
    }

    private func record(id: String) -> CatalogItemRecord? {
        var descriptor = FetchDescriptor<CatalogItemRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
