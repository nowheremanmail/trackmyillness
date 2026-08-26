//
//  CloseIllnessViewModelTests.swift
//  TrackMyIllnessTests
//
//  The close sheet: the summary it shows, the name it suggests, and what closing
//  does to the catalog.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("CloseIllnessViewModel")
@MainActor
struct CloseIllnessViewModelTests {
    private let container = Fixture.container()
    private var entries: EntryStore { EntryStore(container: container) }
    private var catalog: CatalogStore { CatalogStore(container: container) }
    private var archive: ClosedIllnessStore { ClosedIllnessStore(container: container) }

    private func model() -> CloseIllnessViewModel {
        CloseIllnessViewModel(entries: entries, archive: archive, catalog: catalog,
                              calendar: Fixture.calendar)
    }

    @Test("An empty log has nothing to close")
    func nothingToClose() {
        let model = model()
        model.refresh()
        #expect(!model.hasSomethingToClose)
        #expect(!model.canClose)
        #expect(model.suggestedName.isEmpty)
        #expect(model.close() == nil)
    }

    @Test("The summary counts each kind and spans the entries")
    func summary() {
        entries.add(Fixture.entry(name: "Painkiller", date: Fixture.daysAgo(4)))
        entries.add(Fixture.entry(kind: .symptom, name: "Pain", date: Fixture.daysAgo(1)))
        entries.add(Fixture.entry(kind: .symptom, name: "Fever", date: Fixture.daysAgo(0)))

        let model = model()
        model.refresh()
        #expect(model.entryCount == 3)
        #expect(model.treatmentCount == 1)
        #expect(model.symptomCount == 2)
        #expect(model.dateRange?.lowerBound == Fixture.daysAgo(4))
        #expect(model.dateRange?.upperBound == Fixture.daysAgo(0))
        #expect(model.dayCount == 5)
    }

    @Test("A name is suggested, and refresh never overwrites one the user typed")
    func suggestedName() {
        entries.add(Fixture.entry(name: "Painkiller"))
        let model = model()
        model.refresh()
        #expect(!model.name.isEmpty)
        #expect(model.name == model.suggestedName)

        model.name = "Winter flu"
        model.refresh()
        #expect(model.name == "Winter flu")
    }

    @Test("A blank name blocks closing")
    func blankNameBlocks() {
        entries.add(Fixture.entry(name: "Painkiller"))
        let model = model()
        model.refresh()
        model.name = "   "
        #expect(!model.canClose)
        #expect(model.close() == nil)
    }

    @Test("Closing keeps the catalog by default")
    func keepsCatalog() {
        catalog.save(Fixture.item(name: "Painkiller"))
        entries.add(Fixture.entry(name: "Painkiller"))

        let model = model()
        model.refresh()
        model.name = "Flu"
        let closed = model.close()

        #expect(closed != nil)
        #expect(catalog.items(of: .treatment).count == 1)
        #expect(model.entryCount == 0)
    }

    @Test("Turning the toggle off clears the catalog with the illness")
    func clearsCatalogWhenAsked() {
        catalog.save(Fixture.item(name: "Painkiller"))
        catalog.save(Fixture.item(kind: .symptom, name: "Pain"))
        entries.add(Fixture.entry(name: "Painkiller"))

        let model = model()
        model.refresh()
        model.name = "Flu"
        model.keepCatalog = false
        let closed = model.close()

        #expect(closed != nil)
        #expect(catalog.items(of: .treatment, includeArchived: true).isEmpty)
        #expect(catalog.items(of: .symptom, includeArchived: true).isEmpty)
        // The archived entries keep their own names regardless.
        #expect(archive.entries(in: closed!.id).map(\.itemName) == ["Painkiller"])
    }
}

@Suite("ClosedIllnessViewModel")
@MainActor
struct ClosedIllnessViewModelTests {
    private let container = Fixture.container()
    private var entries: EntryStore { EntryStore(container: container) }
    private var archive: ClosedIllnessStore { ClosedIllnessStore(container: container) }

    private func model() -> ClosedIllnessViewModel {
        ClosedIllnessViewModel(store: archive, calendar: Fixture.calendar)
    }

    @Test("An empty archive reports itself empty")
    func empty() {
        let model = model()
        model.refresh()
        #expect(model.isEmpty)
        #expect(model.count == 0)
    }

    @Test("Illnesses are listed newest closed first")
    func listing() {
        entries.add(Fixture.entry(name: "one"))
        _ = archive.close(name: "One", note: "")
        entries.add(Fixture.entry(name: "two"))
        _ = archive.close(name: "Two", note: "")

        let model = model()
        model.refresh()
        #expect(model.illnesses.map(\.name) == ["Two", "One"])
        #expect(model.count == 2)
    }

    @Test("An illness's entries come back grouped by day, newest day first")
    func daysAreGrouped() {
        entries.add(Fixture.entry(name: "older", date: Fixture.daysAgo(2)))
        entries.add(Fixture.entry(name: "newer", date: Fixture.daysAgo(0, hour: 9)))
        entries.add(Fixture.entry(name: "newest", date: Fixture.daysAgo(0, hour: 18)))
        let closed = archive.close(name: "Flu", note: "")!

        let model = model()
        model.refresh()
        let days = model.days(in: closed)
        #expect(days.count == 2)
        #expect(days.first?.entries.map(\.itemName) == ["newest", "newer"])
        #expect(days.last?.entries.map(\.itemName) == ["older"])
    }

    @Test("Deleting drops it from the list")
    func delete() {
        entries.add(Fixture.entry(name: "one"))
        let closed = archive.close(name: "One", note: "")!
        let model = model()
        model.refresh()

        model.delete(closed)
        #expect(model.isEmpty)
    }

    @Test("An illness exports to a PDF, and an empty one doesn't")
    func export() throws {
        entries.add(Fixture.entry(name: "Painkiller"))
        let closed = archive.close(name: "Winter flu", note: "")!
        let model = model()
        model.refresh()

        let url = try #require(model.exportPDF(for: closed))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "pdf")
        #expect(try Data(contentsOf: url).count > 0)

        // An illness whose entries have been deleted has nothing to print.
        model.delete(closed)
        #expect(model.exportPDF(for: closed) == nil)
    }
}
