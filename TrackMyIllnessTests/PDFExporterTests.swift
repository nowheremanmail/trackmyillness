//
//  PDFExporterTests.swift
//  TrackMyIllnessTests
//
//  The rendered report: a real PDF, and a file name a doctor can read.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("PDFExporter")
@MainActor
struct PDFExporterTests {
    private let calendar = Fixture.calendar
    private static let pdfMagic = Array("%PDF".utf8)

    private var range: ClosedRange<Date> {
        calendar.startOfDay(for: Fixture.daysAgo(2))...Fixture.daysAgo(0, hour: 23)
    }

    private func sampleDays() -> [LogDay] {
        LogDay.group([
            Fixture.entry(kind: .treatment, name: "Painkiller",
                          date: Fixture.daysAgo(2, hour: 8), dose: "500 mg"),
            Fixture.entry(kind: .symptom, name: "Pain", date: Fixture.daysAgo(2, hour: 14),
                          severity: 4, note: "Worse after walking"),
            Fixture.entry(kind: .treatment, name: "Evening medication",
                          date: Fixture.daysAgo(0, hour: 21)),
        ], calendar: calendar)
    }

    @Test("Rendering produces PDF data")
    func rendersPDFData() {
        let data = PDFExporter.render(days: sampleDays(), range: range, title: "Health log")
        #expect(data.count > 0)
        #expect(data.starts(with: Self.pdfMagic))
    }

    @Test("An empty period still renders a page, so the export never fails silently")
    func rendersEmptyReport() {
        let data = PDFExporter.render(days: [], range: range, title: "Health log")
        #expect(data.starts(with: Self.pdfMagic))
        #expect(data.count > 0)
    }

    @Test("A long log paginates rather than overflowing one page")
    func paginatesLongReports() {
        let long = LogDay.group((0..<120).map { index in
            Fixture.entry(kind: .symptom, name: "Pain",
                          date: Fixture.daysAgo(index % 60, hour: index % 24),
                          severity: 1 + index % 5, note: "A note long enough to wrap onto "
                            + "a second line in the rendered row, exercising the layout.")
        }, calendar: calendar)
        let short = PDFExporter.render(days: sampleDays(), range: range, title: "Health log")
        let data = PDFExporter.render(days: long, range: range, title: "Health log")
        #expect(data.starts(with: Self.pdfMagic))
        #expect(data.count > short.count)
    }

    @Test("Exporting writes a .pdf file that can be read back")
    func exportWritesAFile() throws {
        let url = try PDFExporter.export(days: sampleDays(), range: range, title: "Health log")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: url).starts(with: Self.pdfMagic))
    }

    @Test("Exporting twice overwrites rather than failing on the existing file")
    func exportIsRepeatable() throws {
        let first = try PDFExporter.export(days: sampleDays(), range: range, title: "Health log")
        let second = try PDFExporter.export(days: sampleDays(), range: range, title: "Health log")
        defer { try? FileManager.default.removeItem(at: second) }
        #expect(first == second)
        #expect(try Data(contentsOf: second).starts(with: Self.pdfMagic))
    }

    @Test("Leaving notes out changes the report, and keeps everything else")
    func notesCanBeLeftOut() {
        let days = LogDay.group([
            Fixture.entry(kind: .symptom, name: "Pain", date: Fixture.daysAgo(1),
                          severity: 4, note: "A private note that a doctor need not read"),
        ], calendar: calendar)
        // Pinned: the header carries the generation time, so a minute rolling over
        // between the two renders would change the byte counts on its own.
        let with = PDFExporter.render(days: days, range: range, title: "Health log",
                                      includeNotes: true, generatedAt: Fixture.fixedDate)
        let without = PDFExporter.render(days: days, range: range, title: "Health log",
                                         includeNotes: false, generatedAt: Fixture.fixedDate)
        #expect(with.starts(with: Self.pdfMagic))
        #expect(without.starts(with: Self.pdfMagic))
        // The note is the only difference, so the shorter one is the one without it.
        #expect(without.count < with.count)
    }

    @Test("With no notes to leave out, the switch changes nothing")
    func notesFlagIsANoOpWithoutNotes() {
        let days = sampleDays().map { day in
            LogDay(date: day.date, entries: day.entries.map {
                var entry = $0
                entry.note = ""
                return entry
            })
        }
        let with = PDFExporter.render(days: days, range: range, title: "Health log",
                                      includeNotes: true, generatedAt: Fixture.fixedDate)
        let without = PDFExporter.render(days: days, range: range, title: "Health log",
                                         includeNotes: false, generatedAt: Fixture.fixedDate)
        #expect(with.count == without.count)
    }

    @Test("Notes are included unless asked otherwise")
    func notesDefaultToIncluded() {
        let days = LogDay.group([
            Fixture.entry(kind: .symptom, date: Fixture.daysAgo(1), note: "Worse after walking"),
        ], calendar: calendar)
        let byDefault = PDFExporter.render(days: days, range: range, title: "Health log",
                                           generatedAt: Fixture.fixedDate)
        let explicit = PDFExporter.render(days: days, range: range, title: "Health log",
                                          includeNotes: true, generatedAt: Fixture.fixedDate)
        #expect(byDefault.count == explicit.count)
    }

    @Test("The file name is the app plus the period, in sortable ISO dates")
    func fileNameIsReadableAndSortable() {
        let from = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14 UTC
        let to = Date(timeIntervalSince1970: 1_702_000_000)     // 2023-12-08 UTC
        let name = PDFExporter.fileName(for: from...to)
        #expect(name == "Symptrace 2023-11-14 – 2023-12-08")
        // No path separators or colons, so it survives being written to disk.
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
    }
}
