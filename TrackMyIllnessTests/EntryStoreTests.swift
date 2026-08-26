//
//  EntryStoreTests.swift
//  TrackMyIllnessTests
//
//  The entry store against a throwaway in-memory container.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("EntryStore")
@MainActor
struct EntryStoreTests {
    private let store = EntryStore(container: Fixture.container())
    private let calendar = Fixture.calendar

    /// A range wide enough to catch anything the fixtures create.
    private var everything: ClosedRange<Date> { .distantPast ... .distantFuture }

    @Test("A new store is empty")
    func startsEmpty() {
        #expect(store.entries(in: everything).isEmpty)
        #expect(store.recent(limit: 10).isEmpty)
    }

    @Test("An added entry comes back with every field intact")
    func addPreservesFields() {
        let entry = Fixture.entry(kind: .symptom, name: "Pain", severity: 4, note: "Sharp")
        store.add(entry)
        let stored = store.entries(in: everything)
        #expect(stored.count == 1)
        #expect(stored.first == entry)
    }

    @Test("Entries come back newest first")
    func newestFirst() {
        store.add(Fixture.entry(name: "older", date: Fixture.daysAgo(3)))
        store.add(Fixture.entry(name: "newest", date: Fixture.daysAgo(0)))
        store.add(Fixture.entry(name: "middle", date: Fixture.daysAgo(1)))
        #expect(store.entries(in: everything).map(\.itemName)
            == ["newest", "middle", "older"])
    }

    @Test("Only entries inside the range are returned, bounds included")
    func rangeIsInclusive() {
        let start = Fixture.daysAgo(2, hour: 0)
        let end = Fixture.daysAgo(1, hour: 0)
        store.add(Fixture.entry(name: "before", date: start.addingTimeInterval(-1)))
        store.add(Fixture.entry(name: "on start", date: start))
        store.add(Fixture.entry(name: "inside", date: start.addingTimeInterval(3600)))
        store.add(Fixture.entry(name: "on end", date: end))
        store.add(Fixture.entry(name: "after", date: end.addingTimeInterval(1)))
        #expect(Set(store.entries(in: start...end).map(\.itemName))
            == ["on start", "inside", "on end"])
    }

    @Test("recent() returns the newest entries up to the limit")
    func recentRespectsLimit() {
        for day in 0..<5 {
            store.add(Fixture.entry(name: "day \(day)", date: Fixture.daysAgo(day)))
        }
        #expect(store.recent(limit: 2).map(\.itemName) == ["day 0", "day 1"])
        #expect(store.recent(limit: 99).count == 5)
    }

    @Test("Updating an entry rewrites it in place")
    func updateInPlace() {
        var entry = Fixture.entry(kind: .symptom, name: "Pain", severity: 2)
        store.add(entry)
        entry.severity = 5
        entry.note = "Much worse"
        store.update(entry)
        let stored = store.entries(in: everything)
        #expect(stored.count == 1)
        #expect(stored.first?.severity == 5)
        #expect(stored.first?.note == "Much worse")
    }

    @Test("Updating an entry the store has never seen adds it, so an edit can't vanish")
    func updateFallsBackToAdd() {
        store.update(Fixture.entry(name: "Painkiller"))
        #expect(store.entries(in: everything).map(\.itemName) == ["Painkiller"])
    }

    @Test("Deleting removes only that entry; an unknown id changes nothing")
    func delete() {
        let keep = Fixture.entry(name: "keep", date: Fixture.daysAgo(1))
        let drop = Fixture.entry(name: "drop", date: Fixture.daysAgo(0))
        store.add(keep)
        store.add(drop)
        store.delete(id: "not-a-real-id")
        #expect(store.entries(in: everything).count == 2)
        store.delete(id: drop.id)
        #expect(store.entries(in: everything).map(\.itemName) == ["keep"])
    }

    @Test("deleteAll empties the log")
    func deleteAll() {
        for day in 0..<3 { store.add(Fixture.entry(date: Fixture.daysAgo(day))) }
        store.deleteAll()
        #expect(store.entries(in: everything).isEmpty)
        #expect(store.recent(limit: 10).isEmpty)
    }

    @Test("Usage counts tally the entries per item, and omit items never used")
    func usageCounts() {
        store.add(Fixture.entry(name: "Painkiller"))
        store.add(Fixture.entry(name: "Painkiller", date: Fixture.daysAgo(1)))
        store.add(Fixture.entry(name: "Painkiller", date: Fixture.daysAgo(2)))
        store.add(Fixture.entry(kind: .symptom, name: "Pain", date: Fixture.daysAgo(1)))
        let counts = store.usageCounts()
        #expect(counts["item-Painkiller"] == 3)
        #expect(counts["item-Pain"] == 1)
        // Never reported means absent, not zero — the caller defaults it.
        #expect(counts["item-Fatigue"] == nil)
        #expect(counts.count == 2)
    }

    @Test("An empty log has no usage counts")
    func usageCountsWhenEmpty() {
        #expect(store.usageCounts().isEmpty)
    }

    @Test("Deleting an entry takes it back out of the usage counts")
    func usageCountsFollowDeletions() {
        let entry = Fixture.entry(name: "Painkiller")
        store.add(entry)
        store.add(Fixture.entry(name: "Painkiller", date: Fixture.daysAgo(1)))
        store.delete(id: entry.id)
        #expect(store.usageCounts()["item-Painkiller"] == 1)
        store.deleteAll()
        #expect(store.usageCounts().isEmpty)
    }

    @Test("Usage is counted over the whole history, not just a recent window")
    func usageCountsSpanAllTime() {
        store.add(Fixture.entry(name: "Painkiller", date: Fixture.daysAgo(400)))
        #expect(store.usageCounts()["item-Painkiller"] == 1)
    }

    @Test("A history range reads back the entries that fall inside it")
    func readsThroughAHistoryRange() {
        store.add(Fixture.entry(name: "this week", date: Fixture.daysAgo(2)))
        store.add(Fixture.entry(name: "last month", date: Fixture.daysAgo(40)))
        let week = HistoryRange.week.dateRange(now: .now, calendar: calendar)
        #expect(store.entries(in: week).map(\.itemName) == ["this week"])
        let quarter = HistoryRange.quarter.dateRange(now: .now, calendar: calendar)
        #expect(store.entries(in: quarter).count == 2)
    }
}
