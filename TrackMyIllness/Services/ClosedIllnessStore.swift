//
//  ClosedIllnessStore.swift
//  TrackMyIllness
//
//  Closing an illness and reading back the ones already closed.
//
//  Closing doesn't copy or delete anything: it stamps every live entry with the
//  new illness's id in a single save. The live queries filter those out from then
//  on, so the Report and History tabs start clean while the entries themselves
//  are untouched and still readable here.
//

import Foundation
import SwiftData

@MainActor
protocol ClosedIllnessStoring {
    /// Every closed illness, most recently closed first.
    func all() -> [ClosedIllness]
    /// The entries archived under an illness, newest first.
    func entries(in illnessID: String) -> [LogEntry]
    /// Archives the live log under a new illness and returns it. Returns nil when
    /// the log is empty — there'd be nothing to look back at.
    @discardableResult
    func close(name: String, note: String) -> ClosedIllness?
    func rename(_ illnessID: String, to name: String, note: String)
    /// Removes the illness *and* the entries archived under it. Destructive.
    func delete(_ illnessID: String)
    /// Removes every closed illness and everything archived under them, for the
    /// factory reset in Settings. Destructive.
    func deleteAll()
}

@MainActor
final class ClosedIllnessStore: ClosedIllnessStoring {
    private let context: ModelContext

    init(container: ModelContainer = AppDatabase.container) {
        context = ModelContext(container)
    }

    func all() -> [ClosedIllness] {
        let descriptor = FetchDescriptor<ClosedIllnessRecord>(
            sortBy: [SortDescriptor(\.closedAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.value)
    }

    func entries(in illnessID: String) -> [LogEntry] {
        guard !illnessID.isEmpty else { return [] }
        let descriptor = FetchDescriptor<LogEntryRecord>(
            predicate: #Predicate { $0.archiveID == illnessID },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.value)
    }

    @discardableResult
    func close(name: String, note: String) -> ClosedIllness? {
        let live = liveRecords()
        guard !live.isEmpty else { return nil }

        let dates = live.map(\.date)
        let illness = ClosedIllness(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            closedAt: .now,
            // The span comes from the entries, not from "now": an illness closed
            // weeks after the last entry didn't run until today.
            startedAt: dates.min() ?? .now,
            endedAt: dates.max() ?? .now,
            treatmentCount: live.count { $0.kindRaw == EntryKind.treatment.rawValue },
            symptomCount: live.count { $0.kindRaw == EntryKind.symptom.rawValue },
            note: note.trimmingCharacters(in: .whitespacesAndNewlines))

        context.insert(ClosedIllnessRecord(illness))
        for record in live { record.archiveID = illness.id }
        // One save: either the illness and every tag land together, or neither
        // does. A half-applied close would strand entries in a missing archive.
        try? context.save()
        return illness
    }

    func rename(_ illnessID: String, to name: String, note: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let record = record(id: illnessID) else { return }
        record.apply(name: trimmed, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        try? context.save()
    }

    func delete(_ illnessID: String) {
        guard !illnessID.isEmpty, let record = record(id: illnessID) else { return }
        try? context.delete(model: LogEntryRecord.self,
                            where: #Predicate { $0.archiveID == illnessID })
        context.delete(record)
        try? context.save()
    }

    func deleteAll() {
        try? context.delete(model: LogEntryRecord.self,
                            where: #Predicate { $0.archiveID != "" })
        try? context.delete(model: ClosedIllnessRecord.self)
        try? context.save()
    }

    private func liveRecords() -> [LogEntryRecord] {
        let descriptor = FetchDescriptor<LogEntryRecord>(predicate: #Predicate { $0.archiveID == "" })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func record(id: String) -> ClosedIllnessRecord? {
        var descriptor = FetchDescriptor<ClosedIllnessRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}
