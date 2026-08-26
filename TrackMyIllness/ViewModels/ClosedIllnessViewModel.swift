//
//  ClosedIllnessViewModel.swift
//  TrackMyIllness
//
//  Backs the read-only screens for illnesses that have already been closed: the
//  list in Settings and one illness's archived log.
//

import Foundation
import Observation

@MainActor
@Observable
final class ClosedIllnessViewModel {
    private(set) var illnesses: [ClosedIllness] = []

    private let store: ClosedIllnessStoring
    private let calendar: Calendar

    init(store: ClosedIllnessStoring? = nil, calendar: Calendar = .current) {
        self.store = store ?? ClosedIllnessStore()
        self.calendar = calendar
    }

    var isEmpty: Bool { illnesses.isEmpty }
    var count: Int { illnesses.count }

    func refresh() {
        illnesses = store.all()
    }

    /// An illness's archived entries grouped by day, newest day first.
    func days(in illness: ClosedIllness) -> [LogDay] {
        LogDay.group(store.entries(in: illness.id), calendar: calendar)
    }

    func rename(_ illness: ClosedIllness, to name: String, note: String) {
        store.rename(illness.id, to: name, note: note)
        refresh()
    }

    func delete(_ illness: ClosedIllness) {
        store.delete(illness.id)
        refresh()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets where illnesses.indices.contains(index) {
            store.delete(illnesses[index].id)
        }
        refresh()
    }

    /// Wipes the archive, as part of the app-wide reset in Settings.
    func reset() {
        store.deleteAll()
        refresh()
    }

    /// Renders one closed illness as a PDF, titled with its name. Returns nil when
    /// it holds nothing to print or the file can't be written.
    func exportPDF(for illness: ClosedIllness, includeNotes: Bool = true) -> URL? {
        let days = days(in: illness)
        guard !days.isEmpty else { return nil }
        let title = illness.name.isEmpty ? String(localized: "Health log") : illness.name
        return try? PDFExporter.export(days: days, range: illness.dateRange,
                                       title: title, includeNotes: includeNotes)
    }
}
