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
    /// Entries whose date falls in `range`, newest first.
    func entries(in range: ClosedRange<Date>) -> [LogEntry]
    /// The most recent entries, newest first.
    func recent(limit: Int) -> [LogEntry]
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
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.value)
    }

    func recent(limit: Int) -> [LogEntry] {
        var descriptor = FetchDescriptor<LogEntryRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map(\.value)
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

    func deleteAll() {
        try? context.delete(model: LogEntryRecord.self)
        try? context.save()
    }

    private func record(id: String) -> LogEntryRecord? {
        var descriptor = FetchDescriptor<LogEntryRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
