//
//  EntryStore.swift
//  TrackMyIllness
//
//  Reads and writes the reported entries (treatments taken, symptoms felt).
//

import Foundation
import SwiftData

@MainActor
protocol EntryStoring {
    /// Every method here works on the *live* log only: entries belonging to a
    /// closed illness are archived, and reached through `ClosedIllnessStoring`.
    ///
    /// Entries whose date falls in `range`, newest first.
    func entries(in range: ClosedRange<Date>) -> [LogEntry]
    /// The most recent entries, newest first.
    func recent(limit: Int) -> [LogEntry]
    /// How many times each catalog item has been reported, keyed by item id.
    /// Items never reported are absent rather than zero.
    func usageCounts() -> [String: Int]
    func add(_ entry: LogEntry)
    func update(_ entry: LogEntry)
    func delete(id: String)
    /// Removes every entry. Destructive.
    func deleteAll()
}

@MainActor
final class EntryStore: EntryStoring {
    private let context: ModelContext

    init(container: ModelContainer = AppDatabase.container) {
        context = ModelContext(container)
    }

    func entries(in range: ClosedRange<Date>) -> [LogEntry] {
        let start = range.lowerBound, end = range.upperBound
        let descriptor = FetchDescriptor<LogEntryRecord>(
            predicate: #Predicate { $0.date >= start && $0.date <= end && $0.archiveID == "" },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.value)
    }

    func recent(limit: Int) -> [LogEntry] {
        var descriptor = FetchDescriptor<LogEntryRecord>(
            predicate: #Predicate { $0.archiveID == "" },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map(\.value)
    }

    /// Counts every entry ever logged: the Report tab puts the items you reach for
    /// most at the top, and "most" only settles down over the whole history.
    func usageCounts() -> [String: Int] {
        let descriptor = FetchDescriptor<LogEntryRecord>(predicate: #Predicate { $0.archiveID == "" })
        let records = (try? context.fetch(descriptor)) ?? []
        return records.reduce(into: [:]) { counts, record in
            counts[record.itemID, default: 0] += 1
        }
    }

    func add(_ entry: LogEntry) {
        context.insert(LogEntryRecord(entry))
        try? context.save()
    }

    func update(_ entry: LogEntry) {
        guard let existing = record(id: entry.id) else { return add(entry) }
        existing.apply(entry)
        try? context.save()
    }

    func delete(id: String) {
        guard let existing = record(id: id) else { return }
        context.delete(existing)
        try? context.save()
    }

    /// Clears the live log. A closed illness keeps its archived entries — losing
    /// them here would quietly destroy the thing "close" was meant to preserve.
    func deleteAll() {
        try? context.delete(model: LogEntryRecord.self, where: #Predicate { $0.archiveID == "" })
        try? context.save()
    }

    private func record(id: String) -> LogEntryRecord? {
        var descriptor = FetchDescriptor<LogEntryRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
