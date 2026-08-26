//
//  PDFExporter.swift
//  TrackMyIllness
//
//  Renders a date range of the log into an A4 PDF: one section per day, one row
//  per entry, so it can be printed or handed to a doctor.
//

import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum PDFExporter {
    /// A4 at 72 dpi, the unit UIGraphicsPDFRenderer draws in.
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 40

    /// Writes the report to a temporary file and returns its URL.
    /// - Note: the caller keeps the URL alive for as long as the share sheet needs it.
    /// - Parameter includeNotes: free-text notes can hold anything the user wrote,
    ///   so whether they reach a report that gets handed to someone else is the
    ///   user's call, not ours.
    static func export(days: [LogDay], range: ClosedRange<Date>, title: String,
                       includeNotes: Bool = true) throws -> URL {
        let data = render(days: days, range: range, title: title, includeNotes: includeNotes)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(for: range), conformingTo: .pdf)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func fileName(for range: ClosedRange<Date>) -> String {
        let from = range.lowerBound.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let to = range.upperBound.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "Symptrace \(from) – \(to)"
    }

    static func render(days: [LogDay], range: ClosedRange<Date>, title: String,
                       includeNotes: Bool = true) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            let writer = PageWriter(context: context, pageSize: pageSize, margin: margin)
            writer.beginPage()
            writer.draw(title, font: .systemFont(ofSize: 24, weight: .bold), spacingAfter: 4)
            writer.draw(rangeSubtitle(range), font: .systemFont(ofSize: 12), color: .secondaryLabel,
                        spacingAfter: 2)
            writer.draw(String(localized: "Generated \(Date.now.formatted(date: .abbreviated, time: .shortened))"),
                        font: .systemFont(ofSize: 10), color: .tertiaryLabel, spacingAfter: 8)
            writer.drawSummary(days: days)
            writer.rule()

            if days.isEmpty {
                writer.draw(String(localized: "No entries in this period."),
                            font: .systemFont(ofSize: 12), color: .secondaryLabel, spacingAfter: 0)
            }
            for day in days {
                writer.drawDayHeader(day.date)
                for entry in day.entries.sorted(by: { $0.date < $1.date }) {
                    writer.drawRow(entry, includeNotes: includeNotes)
                }
                writer.space(6)
            }
            writer.finishFooters()
        }
    }

    private static func rangeSubtitle(_ range: ClosedRange<Date>) -> String {
        let from = range.lowerBound.formatted(date: .long, time: .omitted)
        let to = range.upperBound.formatted(date: .long, time: .omitted)
        return "\(from) – \(to)"
    }
}

/// Lays text out top-to-bottom, starting a new page when the cursor runs off the
/// bottom, and stamps a page number on each page as it's finished.
private final class PageWriter {
    private let context: UIGraphicsPDFRendererContext
    private let pageSize: CGSize
    private let margin: CGFloat
    private var y: CGFloat = 0
    private var pageNumber = 0

    init(context: UIGraphicsPDFRendererContext, pageSize: CGSize, margin: CGFloat) {
        self.context = context
        self.pageSize = pageSize
        self.margin = margin
    }

    private var contentWidth: CGFloat { pageSize.width - margin * 2 }
    private var bottomLimit: CGFloat { pageSize.height - margin - 24 }

    func beginPage() {
        if pageNumber > 0 { drawFooter() }
        context.beginPage()
        pageNumber += 1
        y = margin
    }

    /// Stamps the footer on the last page once everything is drawn.
    func finishFooters() {
        if pageNumber > 0 { drawFooter() }
    }

    private func drawFooter() {
        let text = NSAttributedString(string: "\(pageNumber)", attributes: [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.tertiaryLabel,
        ])
        let size = text.size()
        text.draw(at: CGPoint(x: (pageSize.width - size.width) / 2, y: pageSize.height - margin))
    }

    private func ensureRoom(for height: CGFloat) {
        if y + height > bottomLimit { beginPage() }
    }

    func space(_ amount: CGFloat) { y += amount }

    func rule() {
        ensureRoom(for: 12)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y + 4))
        path.addLine(to: CGPoint(x: pageSize.width - margin, y: y + 4))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        y += 12
    }

    @discardableResult
    func draw(_ string: String, font: UIFont, color: UIColor = .label,
              x: CGFloat? = nil, width: CGFloat? = nil, spacingAfter: CGFloat = 0,
              advance: Bool = true) -> CGFloat {
        let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let maxWidth = width ?? contentWidth
        let bounds = text.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                       options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let height = ceil(bounds.height)
        if advance { ensureRoom(for: height + spacingAfter) }
        text.draw(with: CGRect(x: x ?? margin, y: y, width: maxWidth, height: height),
                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        if advance { y += height + spacingAfter }
        return height
    }

    /// Counts per kind, so the first page answers "how much of what" at a glance.
    func drawSummary(days: [LogDay]) {
        let entries = days.flatMap(\.entries)
        let treatments = entries.filter { $0.kind == .treatment }.count
        let symptoms = entries.filter { $0.kind == .symptom }.count
        let line = String(localized: "Treatments: \(treatments) · Symptoms: \(symptoms) · Days: \(days.count)")
        draw(line, font: .systemFont(ofSize: 11, weight: .medium), color: .secondaryLabel, spacingAfter: 4)
    }

    func drawDayHeader(_ date: Date) {
        ensureRoom(for: 40)
        space(6)
        draw(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()),
             font: .systemFont(ofSize: 13, weight: .semibold), spacingAfter: 4)
    }

    func drawRow(_ entry: LogEntry, includeNotes: Bool) {
        let time = entry.date.formatted(date: .omitted, time: .shortened)
        let detail = Self.detail(for: entry, includeNotes: includeNotes)
        let timeWidth: CGFloat = 56
        let dotWidth: CGFloat = 14
        let nameX = margin + timeWidth + dotWidth
        let nameWidth = contentWidth - timeWidth - dotWidth

        // Measure the tallest column first so the row advances past all of it.
        let nameHeight = draw(entry.itemName, font: .systemFont(ofSize: 11, weight: .medium),
                              x: nameX, width: nameWidth, advance: false)
        ensureRoom(for: nameHeight + 14)

        draw(time, font: .systemFont(ofSize: 11), color: .secondaryLabel,
             x: margin, width: timeWidth, advance: false)
        UIColor(entry.color.color).setFill()
        UIBezierPath(ovalIn: CGRect(x: margin + timeWidth, y: y + 3.5, width: 7, height: 7)).fill()
        draw(entry.itemName, font: .systemFont(ofSize: 11, weight: .medium),
             x: nameX, width: nameWidth, advance: false)
        y += nameHeight

        if !detail.isEmpty {
            draw(detail, font: .systemFont(ofSize: 10), color: .secondaryLabel,
                 x: nameX, width: nameWidth, spacingAfter: 0)
        }
        y += 4
    }

    /// The "kind · dose · severity · note" line under an entry's name.
    private static func detail(for entry: LogEntry, includeNotes: Bool) -> String {
        var parts = [entry.kind.exportTitle]
        if !entry.dose.isEmpty { parts.append(entry.dose) }
        if entry.hasSeverity { parts.append(String(localized: "Severity \(entry.severity)/5")) }
        if includeNotes, !entry.note.isEmpty { parts.append(entry.note) }
        return parts.joined(separator: " · ")
    }
}
