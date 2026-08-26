//
//  ExportViewModel.swift
//  TrackMyIllness
//
//  Builds the PDF report for a chosen period and hands back a file URL to share.
//

import Foundation
import Observation

@MainActor
@Observable
final class ExportViewModel {
    var range: HistoryRange = .month {
        didSet { if range != oldValue { invalidate() } }
    }
    var kindFilter: EntryKind? {
        didSet { if kindFilter != oldValue { invalidate() } }
    }

    private(set) var isGenerating = false
    private(set) var fileURL: URL?
    private(set) var errorMessage: String?

    private let store: EntryStoring
    private let calendar: Calendar

    init(store: EntryStoring? = nil, calendar: Calendar = .current) {
        self.store = store ?? EntryStore()
        self.calendar = calendar
    }

    /// How many entries the report would contain, shown before generating.
    var entryCount: Int { entriesInRange().count }

    func generate() {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        let dateRange = range.dateRange(now: .now, calendar: calendar)
        let days = LogDay.group(entriesInRange(), calendar: calendar)
        do {
            fileURL = try PDFExporter.export(
                days: days,
                range: effectiveRange(dateRange, days: days),
                title: String(localized: "Health log"))
        } catch {
            errorMessage = error.localizedDescription
            fileURL = nil
        }
    }

    func invalidate() {
        fileURL = nil
        errorMessage = nil
    }

    private func entriesInRange() -> [LogEntry] {
        let entries = store.entries(in: range.dateRange(now: .now, calendar: calendar))
        guard let kindFilter else { return entries }
        return entries.filter { $0.kind == kindFilter }
    }

    /// "All" spans 100 years on paper, which reads as nonsense — narrow the header
    /// to the days that actually have entries.
    private func effectiveRange(_ requested: ClosedRange<Date>, days: [LogDay]) -> ClosedRange<Date> {
        guard range == .all, let oldest = days.last?.date else { return requested }
        return oldest...requested.upperBound
    }
}
