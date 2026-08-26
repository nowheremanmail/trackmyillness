//
//  ModelTests.swift
//  TrackMyIllnessTests
//
//  The value types: the date maths behind the history ranges and time shortcuts,
//  the day grouping History and the PDF both rely on, and the record round trips
//  that keep the store honest.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("HistoryRange")
struct HistoryRangeTests {
    private let calendar = Fixture.calendar

    @Test("Each case covers the number of days it advertises")
    func dayCounts() {
        #expect(HistoryRange.week.days == 7)
        #expect(HistoryRange.month.days == 30)
        #expect(HistoryRange.quarter.days == 90)
        #expect(HistoryRange.all.days == nil)
    }

    @Test("The range ends one second before tomorrow, so today is included whole")
    func rangeEndsAtEndOfToday() {
        let now = Fixture.fixedDate
        let range = HistoryRange.week.dateRange(now: now, calendar: calendar)
        let tomorrow = calendar.date(byAdding: .day, value: 1,
                                    to: calendar.startOfDay(for: now))!
        #expect(range.upperBound == tomorrow.addingTimeInterval(-1))
        #expect(range.contains(now))
    }

    @Test("A 7-day range starts 6 days back, so it spans 7 calendar days not 8",
          arguments: [HistoryRange.week, .month, .quarter])
    func rangeSpansExactlyItsDayCount(_ range: HistoryRange) {
        let now = Fixture.fixedDate
        let dates = range.dateRange(now: now, calendar: calendar)
        let expectedStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -(range.days! - 1), to: now)!)
        #expect(dates.lowerBound == expectedStart)
        // Start of the first day through the last second of today: one less than the
        // day count, counted as whole days.
        let spanned = calendar.dateComponents([.day], from: dates.lowerBound,
                                              to: dates.upperBound).day
        #expect(spanned == range.days! - 1)
    }

    @Test("The start of a range is a midnight, so partial first days aren't cut off")
    func rangeStartsAtMidnight() {
        let dates = HistoryRange.month.dateRange(now: Fixture.fixedDate, calendar: calendar)
        #expect(dates.lowerBound == calendar.startOfDay(for: dates.lowerBound))
    }

    @Test("\"All\" still has a lower bound the fetch predicate can use")
    func allHasBoundedRange() {
        let now = Fixture.fixedDate
        let dates = HistoryRange.all.dateRange(now: now, calendar: calendar)
        let years = calendar.dateComponents([.year], from: dates.lowerBound,
                                            to: dates.upperBound).year
        #expect(years == 100)
        #expect(dates.contains(now))
        #expect(dates.lowerBound > .distantPast)
    }
}

@Suite("TimeShortcut")
struct TimeShortcutTests {
    @Test("Offsets go backwards by the amount their label promises")
    func offsets() {
        #expect(TimeShortcut.now.offset == 0)
        #expect(TimeShortcut.thirtyMinutes.offset == -1800)
        #expect(TimeShortcut.oneHour.offset == -3600)
        #expect(TimeShortcut.twoHours.offset == -7200)
    }

    @Test("Applying a shortcut shifts the reference date by its offset")
    func dateFromReference() {
        let reference = Fixture.fixedDate
        for shortcut in TimeShortcut.allCases {
            #expect(shortcut.date(from: reference)
                == reference.addingTimeInterval(shortcut.offset))
        }
    }
}

@Suite("ItemColor")
struct ItemColorTests {
    @Test("A stored name resolves back to the same case", arguments: ItemColor.allCases)
    func namedRoundTrips(_ color: ItemColor) {
        #expect(ItemColor.named(color.rawValue) == color)
    }

    @Test("An unknown stored name falls back to blue instead of crashing",
          arguments: ["", "chartreuse", "Blue", "0"])
    func unknownNameFallsBack(_ name: String) {
        #expect(ItemColor.named(name) == .blue)
    }
}

@Suite("LogDay grouping")
struct LogDayTests {
    private let calendar = Fixture.calendar

    @Test("Days come back newest first, and each day's entries newest first")
    func groupsAndSorts() {
        let entries = [
            Fixture.entry(name: "yesterday early", date: Fixture.daysAgo(1, hour: 8)),
            Fixture.entry(name: "today late", date: Fixture.daysAgo(0, hour: 21)),
            Fixture.entry(name: "yesterday late", date: Fixture.daysAgo(1, hour: 20)),
            Fixture.entry(name: "today early", date: Fixture.daysAgo(0, hour: 9)),
        ]
        let days = LogDay.group(entries, calendar: calendar)
        #expect(days.count == 2)
        #expect(days.map(\.entries.count) == [2, 2])
        #expect(days[0].entries.map(\.itemName) == ["today late", "today early"])
        #expect(days[1].entries.map(\.itemName) == ["yesterday late", "yesterday early"])
        #expect(days[0].date > days[1].date)
    }

    @Test("A day is keyed by its midnight, so entries hours apart still share one day")
    func dayIsKeyedByMidnight() {
        let days = LogDay.group([
            Fixture.entry(date: Fixture.daysAgo(3, hour: 0)),
            Fixture.entry(date: Fixture.daysAgo(3, hour: 23)),
        ], calendar: calendar)
        #expect(days.count == 1)
        #expect(days[0].date == calendar.startOfDay(for: days[0].entries[0].date))
    }

    @Test("No entries means no days")
    func emptyInput() {
        #expect(LogDay.group([], calendar: calendar).isEmpty)
    }
}

@Suite("Record round trips")
struct RecordTests {
    @Test("A catalog item survives the trip through its record unchanged")
    func catalogItemRoundTrips() {
        let item = Fixture.item(kind: .symptom, name: "Pain", defaultDose: "500 mg",
                               tracksSeverity: true, isArchived: true, sortIndex: 4)
        #expect(CatalogItemRecord(item).value == item)
    }

    @Test("apply() overwrites the editable fields but keeps the record's identity")
    func catalogItemApplyKeepsID() {
        let record = CatalogItemRecord(Fixture.item(name: "Old"))
        var updated = Fixture.item(kind: .symptom, name: "New", tracksSeverity: true)
        updated.id = "a-different-id"
        record.apply(updated)
        #expect(record.name == "New")
        #expect(record.kindRaw == EntryKind.symptom.rawValue)
        #expect(record.tracksSeverity)
        // The id is the store's unique key: apply() must not move a record onto
        // another item's identity.
        #expect(record.id != updated.id)
    }

    @Test("A log entry survives the trip through its record unchanged")
    func logEntryRoundTrips() {
        let entry = Fixture.entry(kind: .symptom, name: "Pain", dose: "1",
                                  severity: 4, note: "Worse after walking")
        #expect(LogEntryRecord(entry).value == entry)
    }

    @Test("An unreadable stored kind reads back as a treatment rather than failing")
    func unknownKindFallsBack() {
        let catalog = CatalogItemRecord(kindRaw: "vitamin")
        #expect(catalog.value.kind == .treatment)
        let entry = LogEntryRecord(kindRaw: "vitamin")
        #expect(entry.value.kind == .treatment)
    }

    @Test("Severity is only \"recorded\" from 1 up")
    func hasSeverity() {
        #expect(Fixture.entry(severity: 0).hasSeverity == false)
        #expect(Fixture.entry(severity: 1).hasSeverity)
        #expect(Fixture.entry(severity: 5).hasSeverity)
    }
}
