//
//  HistoryViewModel.swift
//  TrackMyIllness
//
//  Backs the History tab: the entries in a period, grouped by day, plus the
//  per-day counts and symptom severity the overview chart draws.
//

import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    /// One bar/point in the overview chart.
    struct DayStat: Identifiable, Hashable, Sendable {
        var date: Date
        var treatments: Int
        var symptoms: Int
        /// Mean severity of that day's symptoms that recorded one, or nil.
        var averageSeverity: Double?

        var id: Date { date }
    }

    var range: HistoryRange = .week {
        didSet {
            guard range != oldValue else { return }
            UserDefaults.standard.set(range.rawValue, forKey: AppSettings.historyRangeKey)
            refresh()
        }
    }

    /// nil shows both kinds.
    var kindFilter: EntryKind? {
        didSet { if kindFilter != oldValue { rebuild() } }
    }

    private(set) var days: [LogDay] = []
    private(set) var stats: [DayStat] = []

    private var allEntries: [LogEntry] = []
    private let store: EntryStoring
    private let calendar: Calendar

    init(store: EntryStoring? = nil, calendar: Calendar = .current) {
        self.store = store ?? EntryStore()
        self.calendar = calendar
        if let raw = UserDefaults.standard.string(forKey: AppSettings.historyRangeKey),
           let stored = HistoryRange(rawValue: raw) {
            range = stored
        }
    }

    var isEmpty: Bool { days.isEmpty }

    var totalTreatments: Int { filtered.filter { $0.kind == .treatment }.count }
    var totalSymptoms: Int { filtered.filter { $0.kind == .symptom }.count }

    /// True when there's enough symptom severity data for the chart's line.
    var hasSeverityData: Bool { stats.contains { $0.averageSeverity != nil } }

    func refresh() {
        allEntries = store.entries(in: range.dateRange(now: .now, calendar: calendar))
        rebuild()
    }

    func delete(_ entry: LogEntry) {
        store.delete(id: entry.id)
        allEntries.removeAll { $0.id == entry.id }
        rebuild()
    }

    private var filtered: [LogEntry] {
        guard let kindFilter else { return allEntries }
        return allEntries.filter { $0.kind == kindFilter }
    }

    private func rebuild() {
        let entries = filtered
        days = LogDay.group(entries, calendar: calendar)
        stats = buildStats(from: entries)
    }

    /// One stat per calendar day in the range — including empty days, so the chart
    /// shows gaps instead of silently compressing them.
    private func buildStats(from entries: [LogEntry]) -> [DayStat] {
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        let dayCount = range.days ?? max(daysSpanned(byDay.keys), 1)
        let today = calendar.startOfDay(for: .now)
        return (0..<dayCount).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayEntries = byDay[date] ?? []
            let severities = dayEntries.filter(\.hasSeverity).map { Double($0.severity) }
            return DayStat(
                date: date,
                treatments: dayEntries.filter { $0.kind == .treatment }.count,
                symptoms: dayEntries.filter { $0.kind == .symptom }.count,
                averageSeverity: severities.isEmpty
                    ? nil : severities.reduce(0, +) / Double(severities.count))
        }
    }

    /// How many days "All" has to cover: from the oldest entry through today.
    private func daysSpanned(_ dates: some Collection<Date>) -> Int {
        guard let oldest = dates.min() else { return 1 }
        let span = calendar.dateComponents([.day], from: oldest, to: calendar.startOfDay(for: .now)).day ?? 0
        // Cap it: a chart with thousands of bars is unreadable and slow to build.
        return min(span + 1, 365)
    }
}
