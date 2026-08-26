//
//  ExportViewModelTests.swift
//  TrackMyIllnessTests
//
//  The PDF export: what would go in the report, and the file that comes out.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("ExportViewModel")
@MainActor
struct ExportViewModelTests {
    private let store: EntryStore
    private let model: ExportViewModel
    private let calendar = Fixture.calendar

    init() {
        store = EntryStore(container: Fixture.container())
        model = ExportViewModel(store: store, calendar: Fixture.calendar)
    }

    /// The PDF is written to a temp file the share sheet owns; tests clean up after
    /// themselves so a run doesn't leave a pile of reports behind.
    private func removeGeneratedFile() {
        if let url = model.fileURL { try? FileManager.default.removeItem(at: url) }
    }

    private func seed() {
        store.add(Fixture.entry(kind: .treatment, name: "Painkiller",
                                date: Fixture.daysAgo(1), dose: "500 mg"))
        store.add(Fixture.entry(kind: .symptom, name: "Pain",
                                date: Fixture.daysAgo(1), severity: 3))
        store.add(Fixture.entry(kind: .treatment, name: "Painkiller",
                                date: Fixture.daysAgo(45)))
    }

    @Test("The export opens on 30 days with nothing generated yet")
    func initialState() {
        #expect(model.range == .month)
        #expect(model.kindFilter == nil)
        #expect(model.fileURL == nil)
        #expect(model.errorMessage == nil)
        #expect(model.isGenerating == false)
        #expect(model.entryCount == 0)
    }

    @Test("The count previews how many entries the chosen range would include")
    func entryCountFollowsRange() {
        seed()
        #expect(model.entryCount == 2)
        model.range = .quarter
        #expect(model.entryCount == 3)
        model.range = .week
        #expect(model.entryCount == 2)
    }

    @Test("Filtering by kind narrows the count")
    func entryCountFollowsKindFilter() {
        seed()
        model.kindFilter = .symptom
        #expect(model.entryCount == 1)
        model.kindFilter = .treatment
        #expect(model.entryCount == 1)
        model.kindFilter = nil
        #expect(model.entryCount == 2)
    }

    @Test("Changing the range throws away the stale PDF")
    func changingRangeInvalidates() {
        seed()
        model.generate()
        #expect(model.fileURL != nil)
        removeGeneratedFile()
        model.range = .quarter
        #expect(model.fileURL == nil)
        #expect(model.errorMessage == nil)
    }

    @Test("Changing the kind filter throws away the stale PDF")
    func changingKindFilterInvalidates() {
        seed()
        model.generate()
        #expect(model.fileURL != nil)
        removeGeneratedFile()
        model.kindFilter = .symptom
        #expect(model.fileURL == nil)
    }

    @Test("Re-selecting the same range keeps the PDF that's already been made")
    func settingTheSameRangeKeepsTheFile() {
        seed()
        model.generate()
        let url = model.fileURL
        model.range = .month
        #expect(model.fileURL == url)
        removeGeneratedFile()
    }

    @Test("Generating writes a real PDF to disk")
    func generateWritesAPDF() throws {
        seed()
        model.generate()
        defer { removeGeneratedFile() }

        let url = try #require(model.fileURL)
        #expect(model.errorMessage == nil)
        #expect(model.isGenerating == false)
        #expect(url.pathExtension == "pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        #expect(data.count > 0)
        #expect(data.starts(with: Array("%PDF".utf8)))
    }

    @Test("A period with no entries still produces a report rather than an error")
    func generateWithNoEntries() throws {
        model.generate()
        defer { removeGeneratedFile() }
        #expect(model.errorMessage == nil)
        let url = try #require(model.fileURL)
        #expect(try Data(contentsOf: url).starts(with: Array("%PDF".utf8)))
    }

    @Test("The file name spans the requested period")
    func fileNameCoversTheRange() throws {
        seed()
        model.generate()
        defer { removeGeneratedFile() }
        let url = try #require(model.fileURL)
        let expected = HistoryRange.month.dateRange(now: .now, calendar: calendar)
        #expect(url.lastPathComponent == PDFExporter.fileName(for: expected) + ".pdf")
    }

    @Test("\"All\" names the file from the oldest entry, not from a century ago")
    func allNarrowsTheFileNameToRealData() throws {
        seed()
        model.range = .all
        model.generate()
        defer { removeGeneratedFile() }

        let url = try #require(model.fileURL)
        let requested = HistoryRange.all.dateRange(now: .now, calendar: calendar)
        let oldest = calendar.startOfDay(for: Fixture.daysAgo(45))
        #expect(url.lastPathComponent
            == PDFExporter.fileName(for: oldest...requested.upperBound) + ".pdf")
        // The 100-year lower bound the fetch uses must never reach the page header.
        let ancientYear = calendar.component(.year, from: requested.lowerBound)
        #expect(!url.lastPathComponent.contains("\(ancientYear)"))
    }
}
