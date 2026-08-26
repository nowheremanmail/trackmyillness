//
//  CloseIllnessViewModel.swift
//  TrackMyIllness
//
//  Backs the "close this illness" sheet: shows what is about to be archived, and
//  archives it.
//

import Foundation
import Observation

@MainActor
@Observable
final class CloseIllnessViewModel {
    var name: String = ""
    var note: String = ""
    /// Whether the configured treatments and symptoms survive the close. On by
    /// default: the catalog is usually still what you'd track next, and clearing
    /// it is the more destructive of the two.
    var keepCatalog: Bool = true

    private(set) var live: [LogEntry] = []

    private let entries: EntryStoring
    private let archive: ClosedIllnessStoring
    private let catalog: CatalogStoring
    private let calendar: Calendar

    init(entries: EntryStoring? = nil,
         archive: ClosedIllnessStoring? = nil,
         catalog: CatalogStoring? = nil,
         calendar: Calendar = .current) {
        self.entries = entries ?? EntryStore()
        self.archive = archive ?? ClosedIllnessStore()
        self.catalog = catalog ?? CatalogStore()
        self.calendar = calendar
    }

    /// Reads the live log and proposes a name for it. Called when the sheet opens.
    func refresh() {
        live = entries.entries(in: .distantPast ... .distantFuture)
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = suggestedName
        }
    }

    var entryCount: Int { live.count }
    var treatmentCount: Int { live.count { $0.kind == .treatment } }
    var symptomCount: Int { live.count { $0.kind == .symptom } }
    var hasSomethingToClose: Bool { !live.isEmpty }

    var canClose: Bool {
        hasSomethingToClose && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The span of the live entries, or nil when there are none.
    var dateRange: ClosedRange<Date>? {
        guard let first = live.map(\.date).min(), let last = live.map(\.date).max() else { return nil }
        return first...last
    }

    var dayCount: Int {
        guard let dateRange else { return 0 }
        let from = calendar.startOfDay(for: dateRange.lowerBound)
        let to = calendar.startOfDay(for: dateRange.upperBound)
        return (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
    }

    /// The dates the log covers, as a name you'd recognise later. Locale-formatted
    /// rather than a fixed phrase — it's a label made of data, not UI copy.
    var suggestedName: String {
        guard let dateRange else { return "" }
        let from = dateRange.lowerBound.formatted(.dateTime.day().month(.abbreviated).year())
        guard !calendar.isDate(dateRange.lowerBound, inSameDayAs: dateRange.upperBound) else { return from }
        let to = dateRange.upperBound.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(from) – \(to)"
    }

    /// Archives the live log. Returns the closed illness, or nil if there was
    /// nothing to archive.
    @discardableResult
    func close() -> ClosedIllness? {
        guard canClose, let closed = archive.close(name: name, note: note) else { return nil }
        if !keepCatalog { catalog.deleteAll() }
        live = []
        return closed
    }
}
