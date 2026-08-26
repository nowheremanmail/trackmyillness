//
//  HistoryViewModelTests.swift
//  TrackMyIllnessTests
//
//  The History tab: the entries in a period, and the per-day stats the overview
//  chart draws.
//
//  Serialized because the chosen range is remembered in UserDefaults, which is
//  process-wide state these tests both read and write.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("HistoryViewModel", .serialized)
@MainActor
struct HistoryViewModelTests {
    private let store: EntryStore
    private let calendar = Fixture.calendar

    init() {
        Fixture.resetDefaults()
        store = EntryStore(container: Fixture.container())
    }

    private func makeModel() -> HistoryViewModel {
        let model = HistoryViewModel(store: store, calendar: calendar)
        model.refresh()
        return model
    }

    /// A treatment today, and symptoms of severity 2 and 4 two days ago.
    private func seedTwoDays() {
        store.add(Fixture.entry(kind: .treatment, name: "Painkiller",
                                date: Fixture.daysAgo(0, hour: 9), dose: "500 mg"))
        store.add(Fixture.entry(kind: .symptom, name: "Pain",
                                date: Fixture.daysAgo(2, hour: 10), severity: 2))
        store.add(Fixture.entry(kind: .symptom, name: "Pain",
                                date: Fixture.daysAgo(2, hour: 18), severity: 4))
    }

    @Test("An empty log reports itself as empty")
    func emptyLog() {
        let model = makeModel()
        #expect(model.isEmpty)
        #expect(model.days.isEmpty)
        #expect(model.totalTreatments == 0)
        #expect(model.totalSymptoms == 0)
        #expect(model.hasSeverityData == false)
    }

    @Test("Entries are grouped into days, newest first, and counted by kind")
    func groupsAndCounts() {
        seedTwoDays()
        let model = makeModel()
        #expect(model.isEmpty == false)
        #expect(model.days.count == 2)
        #expect(model.days[0].date > model.days[1].date)
        #expect(model.days[1].entries.count == 2)
        #expect(model.totalTreatments == 1)
        #expect(model.totalSymptoms == 2)
    }

    @Test("Entries older than the range are left out")
    func rangeLimitsWhatIsLoaded() {
        store.add(Fixture.entry(name: "this week", date: Fixture.daysAgo(3)))
        store.add(Fixture.entry(name: "last month", date: Fixture.daysAgo(45)))
        let model = makeModel()
        #expect(model.range == .week)
        #expect(model.days.flatMap(\.entries).map(\.itemName) == ["this week"])

        model.range = .quarter
        #expect(model.days.flatMap(\.entries).count == 2)
    }

    @Test("The chosen range is remembered for the next visit")
    func remembersRange() {
        let model = makeModel()
        model.range = .month
        #expect(UserDefaults.standard.string(forKey: AppSettings.historyRangeKey)
            == HistoryRange.month.rawValue)
        #expect(makeModel().range == .month)
    }

    @Test("The chart gets one point per day in the range, empty days included")
    func statsCoverEveryDayInRange() {
        seedTwoDays()
        let model = makeModel()
        // Gaps have to be visible, so days with nothing logged still get a point.
        #expect(model.stats.count == 7)
        #expect(model.stats.map(\.date) == model.stats.map(\.date).sorted())
        #expect(model.stats.last?.date == calendar.startOfDay(for: .now))
        #expect(model.stats.filter { $0.treatments + $0.symptoms == 0 }.count == 5)
    }

    @Test("Each day's point carries its counts and mean symptom severity")
    func statsPerDay() throws {
        seedTwoDays()
        let model = makeModel()
        let today = try #require(model.stats.last)
        #expect(today.treatments == 1)
        #expect(today.symptoms == 0)
        // No symptom rated today, so the severity line has nothing to plot here.
        #expect(today.averageSeverity == nil)

        let twoDaysAgo = try #require(
            model.stats.first { $0.date == calendar.startOfDay(for: Fixture.daysAgo(2)) })
        #expect(twoDaysAgo.symptoms == 2)
        #expect(twoDaysAgo.treatments == 0)
        #expect(twoDaysAgo.averageSeverity == 3)   // (2 + 4) / 2
        #expect(model.hasSeverityData)
    }

    @Test("Symptoms logged without a severity don't drag the average down")
    func unratedSymptomsAreExcludedFromTheAverage() throws {
        store.add(Fixture.entry(kind: .symptom, date: Fixture.daysAgo(1, hour: 9), severity: 4))
        store.add(Fixture.entry(kind: .symptom, date: Fixture.daysAgo(1, hour: 15), severity: 0))
        let model = makeModel()
        let day = try #require(
            model.stats.first { $0.date == calendar.startOfDay(for: Fixture.daysAgo(1)) })
        #expect(day.symptoms == 2)
        #expect(day.averageSeverity == 4)
    }

    @Test("Filtering by kind narrows the days, the totals and the chart")
    func kindFilter() {
        seedTwoDays()
        let model = makeModel()

        model.kindFilter = .symptom
        #expect(model.days.count == 1)
        #expect(model.totalTreatments == 0)
        #expect(model.totalSymptoms == 2)
        #expect(model.stats.map(\.treatments).allSatisfy { $0 == 0 })

        model.kindFilter = .treatment
        #expect(model.days.count == 1)
        #expect(model.totalTreatments == 1)
        #expect(model.hasSeverityData == false)

        model.kindFilter = nil
        #expect(model.days.count == 2)
    }

    @Test("Deleting an entry drops it from the days and the chart without a refetch")
    func delete() throws {
        seedTwoDays()
        let model = makeModel()
        let entry = try #require(model.days.first?.entries.first)
        model.delete(entry)
        #expect(model.days.flatMap(\.entries).count == 2)
        #expect(model.totalTreatments == 0)
        #expect(model.stats.last?.treatments == 0)
        // And it's gone from the store, not just the view.
        #expect(store.entries(in: .distantPast ... .distantFuture).count == 2)
    }

    @Test("\"All\" spans from the oldest entry to today rather than a fixed window")
    func allRangeSpansTheData() {
        store.add(Fixture.entry(date: Fixture.daysAgo(10)))
        store.add(Fixture.entry(date: Fixture.daysAgo(0)))
        let model = makeModel()
        model.range = .all
        #expect(model.days.count == 2)
        #expect(model.stats.count == 11)
        #expect(model.stats.last?.date == calendar.startOfDay(for: .now))
    }

    @Test("\"All\" on an empty log still produces a single point, not an empty chart")
    func allRangeWithNoEntries() {
        let model = makeModel()
        model.range = .all
        #expect(model.stats.count == 1)
        #expect(model.isEmpty)
    }
}
