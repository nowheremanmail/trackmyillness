//
//  ClosedIllnessStoreTests.swift
//  TrackMyIllnessTests
//
//  Closing an illness: what moves into the archive, what stays behind, and what
//  the live log looks like afterwards.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("ClosedIllnessStore")
@MainActor
struct ClosedIllnessStoreTests {
    private let container = Fixture.container()
    private var archive: ClosedIllnessStore { ClosedIllnessStore(container: container) }
    private var entries: EntryStore { EntryStore(container: container) }
    private var everything: ClosedRange<Date> { .distantPast ... .distantFuture }

    @Test("A new archive is empty")
    func startsEmpty() {
        #expect(archive.all().isEmpty)
        #expect(archive.entries(in: "anything").isEmpty)
    }

    @Test("Closing an empty log archives nothing")
    func closingNothing() {
        #expect(archive.close(name: "Flu", note: "") == nil)
        #expect(archive.all().isEmpty)
    }

    @Test("Closing moves every live entry into the archive")
    func closeMovesEntries() {
        let store = entries
        store.add(Fixture.entry(name: "Painkiller"))
        store.add(Fixture.entry(kind: .symptom, name: "Pain", severity: 3))

        let closed = archive.close(name: "Winter flu", note: "Bad one")
        #expect(closed?.name == "Winter flu")
        #expect(closed?.note == "Bad one")
        #expect(closed?.treatmentCount == 1)
        #expect(closed?.symptomCount == 1)
        #expect(closed?.entryCount == 2)

        // Gone from the live log, present in the archive, still whole.
        #expect(store.entries(in: everything).isEmpty)
        let archived = archive.entries(in: closed!.id)
        #expect(archived.count == 2)
        #expect(archived.allSatisfy { !$0.isLive })
        #expect(Set(archived.map(\.itemName)) == ["Painkiller", "Pain"])
        #expect(archived.first { $0.kind == .symptom }?.severity == 3)
    }

    @Test("The archived span comes from the entries, not from the closing date")
    func spanFollowsEntries() {
        let store = entries
        store.add(Fixture.entry(name: "first", date: Fixture.daysAgo(9)))
        store.add(Fixture.entry(name: "last", date: Fixture.daysAgo(2)))

        let closed = archive.close(name: "Flu", note: "")
        #expect(closed?.startedAt == Fixture.daysAgo(9))
        #expect(closed?.endedAt == Fixture.daysAgo(2))
        #expect(closed?.dayCount(calendar: Fixture.calendar) == 8)
        // Closed "now", which is well after the last entry.
        #expect(closed!.closedAt > closed!.endedAt)
    }

    @Test("A second close only takes what was logged since the first")
    func successiveCloses() {
        let store = entries
        store.add(Fixture.entry(name: "round one"))
        let first = archive.close(name: "One", note: "")!

        store.add(Fixture.entry(name: "round two"))
        let second = archive.close(name: "Two", note: "")!

        #expect(archive.entries(in: first.id).map(\.itemName) == ["round one"])
        #expect(archive.entries(in: second.id).map(\.itemName) == ["round two"])
        #expect(archive.all().map(\.name) == ["Two", "One"])   // newest closed first
    }

    @Test("Archived entries come back newest first")
    func newestFirst() {
        let store = entries
        store.add(Fixture.entry(name: "older", date: Fixture.daysAgo(3)))
        store.add(Fixture.entry(name: "newest", date: Fixture.daysAgo(0)))
        store.add(Fixture.entry(name: "middle", date: Fixture.daysAgo(1)))
        let closed = archive.close(name: "Flu", note: "")!
        #expect(archive.entries(in: closed.id).map(\.itemName) == ["newest", "middle", "older"])
    }

    @Test("Clearing the live log leaves the archive alone")
    func deleteAllSparesTheArchive() {
        let store = entries
        store.add(Fixture.entry(name: "archived"))
        let closed = archive.close(name: "Flu", note: "")!
        store.add(Fixture.entry(name: "live"))

        store.deleteAll()

        #expect(store.entries(in: everything).isEmpty)
        #expect(archive.entries(in: closed.id).map(\.itemName) == ["archived"])
    }

    @Test("Archived entries stay out of the live queries and the usage ranking")
    func archivedAreInvisibleToTheLiveLog() {
        let store = entries
        let item = Fixture.item(name: "Painkiller")
        store.add(Fixture.entry(reporting: item))
        _ = archive.close(name: "Flu", note: "")

        #expect(store.entries(in: everything).isEmpty)
        #expect(store.recent(limit: 10).isEmpty)
        #expect(store.usageCounts().isEmpty)
    }

    @Test("Renaming keeps the counts and dates, and ignores a blank name")
    func rename() {
        let store = entries
        store.add(Fixture.entry(name: "Painkiller"))
        let closed = archive.close(name: "Flu", note: "")!

        archive.rename(closed.id, to: "  Winter flu  ", note: "  went on for ages  ")
        let renamed = archive.all().first
        #expect(renamed?.name == "Winter flu")
        #expect(renamed?.note == "went on for ages")
        #expect(renamed?.treatmentCount == closed.treatmentCount)
        #expect(renamed?.startedAt == closed.startedAt)

        archive.rename(closed.id, to: "   ", note: "")
        #expect(archive.all().first?.name == "Winter flu")
    }

    @Test("Deleting an illness takes its entries with it and spares the others")
    func deleteTakesItsEntries() {
        let store = entries
        store.add(Fixture.entry(name: "one"))
        let first = archive.close(name: "One", note: "")!
        store.add(Fixture.entry(name: "two"))
        let second = archive.close(name: "Two", note: "")!

        archive.delete(first.id)

        #expect(archive.all().map(\.name) == ["Two"])
        #expect(archive.entries(in: first.id).isEmpty)
        #expect(archive.entries(in: second.id).map(\.itemName) == ["two"])
    }

    @Test("Wiping the archive leaves the live log alone")
    func deleteAllSparesTheLiveLog() {
        let store = entries
        store.add(Fixture.entry(name: "archived"))
        _ = archive.close(name: "Flu", note: "")
        store.add(Fixture.entry(name: "live"))

        archive.deleteAll()

        #expect(archive.all().isEmpty)
        #expect(store.entries(in: everything).map(\.itemName) == ["live"])
    }
}
