//
//  PreviewSupport.swift
//  TrackMyIllness
//
//  Sample data for SwiftUI previews. Everything here lives in one throwaway
//  in-memory container, so previews never read or write the real store.
//
//  Not wrapped in #if DEBUG: `#Preview` bodies are compiled in Release builds too,
//  so guarding this would break the release build of every view that previews it.
//

import Foundation
import SwiftData

@MainActor
enum PreviewData {
    /// Built once per preview process and shared by every preview store.
    static let container: ModelContainer = {
        let container = AppDatabase.previewContainer()
        let context = ModelContext(container)
        for item in CatalogStore.defaults {
            context.insert(CatalogItemRecord(item))
        }
        for entry in sampleEntries(catalog: CatalogStore.defaults) {
            context.insert(LogEntryRecord(entry))
        }
        try? context.save()
        return container
    }()

    static func catalogStore() -> CatalogStore { CatalogStore(container: container) }
    static func entryStore() -> EntryStore { EntryStore(container: container) }

    static var sampleItem: CatalogItem {
        CatalogItem(kind: .treatment, name: "Painkiller", symbolName: "pills.fill",
                    colorName: ItemColor.teal.rawValue, defaultDose: "500 mg", sortIndex: 0)
    }

    static var sampleEntry: LogEntry {
        LogEntry(kind: .symptom, itemID: "s1", itemName: "Pain", symbolName: "bolt.fill",
                 colorName: ItemColor.red.rawValue, date: .now.addingTimeInterval(-3600),
                 severity: 4, note: "Worse after walking")
    }

    /// Two weeks of plausible entries so history, charts and the PDF have shape.
    static func sampleEntries(catalog: [CatalogItem]) -> [LogEntry] {
        let treatments = catalog.filter { $0.kind == .treatment }
        let symptoms = catalog.filter { $0.kind == .symptom }
        guard !treatments.isEmpty, !symptoms.isEmpty else { return [] }
        let calendar = Calendar.current
        var entries: [LogEntry] = []
        for day in 0..<14 {
            guard let midnight = calendar.date(byAdding: .day, value: -day,
                                               to: calendar.startOfDay(for: .now)) else { continue }
            // Morning + evening treatment, and a symptom or two, varied by day.
            for (index, hour) in [8, 21].enumerated() {
                let item = treatments[index % treatments.count]
                entries.append(LogEntry(
                    kind: .treatment, itemID: item.id, itemName: item.name,
                    symbolName: item.symbolName, colorName: item.colorName,
                    date: midnight.addingTimeInterval(TimeInterval(hour * 3600)),
                    dose: item.defaultDose))
            }
            for slot in 0...(day % 2) {
                let item = symptoms[(day + slot) % symptoms.count]
                entries.append(LogEntry(
                    kind: .symptom, itemID: item.id, itemName: item.name,
                    symbolName: item.symbolName, colorName: item.colorName,
                    date: midnight.addingTimeInterval(TimeInterval((13 + slot * 4) * 3600)),
                    severity: 2 + (day + slot) % 4))
            }
        }
        return entries
    }
}
