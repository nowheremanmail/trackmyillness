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
    /// Notes can hold anything the user wrote, so a report meant for someone else
    /// shouldn't carry them without being asked. Remembered between exports.
    var includesNotes: Bool {
        didSet {
            guard includesNotes != oldValue else { return }
            UserDefaults.standard.set(includesNotes, forKey: AppSettings.exportIncludesNotesKey)
            invalidate()
        }
    }

    /// True when at least one entry in range actually has a note, so the toggle
    /// isn't offered for a report where it would change nothing.
    var hasNotes: Bool { entriesInRange().contains { !$0.note.isEmpty } }

    private(set) var isGenerating = false
    private(set) var fileURL: URL?
    private(set) var errorMessage: String?

    private let store: EntryStoring
    private let calendar: Calendar

    init(store: EntryStoring? = nil, calendar: Calendar = .current) {
        self.store = store ?? EntryStore()
        self.calendar = calendar
        // Property observers don't fire in init, so reading the preference here
        // doesn't bounce it straight back into UserDefaults.
        let defaults = UserDefaults.standard
        includesNotes = defaults.object(forKey: AppSettings.exportIncludesNotesKey) as? Bool ?? true
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
                title: String(localized: "Health log"),
                includeNotes: includesNotes)
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
