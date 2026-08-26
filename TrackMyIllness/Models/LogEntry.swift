//
//  LogEntry.swift
//  TrackMyIllness
//
//  One reported event — a treatment taken or a symptom felt at a point in time —
//  plus its SwiftData record.
//
//  The item's name/symbol/colour are copied into the entry rather than referenced,
//  so history stays readable after a catalog item is renamed or deleted.
//

import Foundation
import SwiftData

struct LogEntry: Identifiable, Hashable, Sendable {
    var id: String = UUID().uuidString
    var kind: EntryKind = EntryKind.treatment
    var itemID: String = ""
    var itemName: String = ""
    var symbolName: String = "pills.fill"
    var colorName: String = ItemColor.blue.rawValue
    var date: Date = Date.now
    /// Treatments only; empty when not recorded.
    var dose: String = ""
    /// Symptoms only: 1–5, or 0 when not recorded.
    var severity: Int = 0
    var note: String = ""

    var color: ItemColor { ItemColor.named(colorName) }
    var hasSeverity: Bool { severity > 0 }
}

@Model
final class LogEntryRecord {
    @Attribute(.unique) var id: String = UUID().uuidString
    var kindRaw: String = EntryKind.treatment.rawValue
    var itemID: String = ""
    var itemName: String = ""
    var symbolName: String = "pills.fill"
    var colorName: String = ItemColor.blue.rawValue
    var date: Date = Date.now
    var dose: String = ""
    var severity: Int = 0
    var note: String = ""

    init(id: String = UUID().uuidString,
         kindRaw: String = EntryKind.treatment.rawValue,
         itemID: String = "",
         itemName: String = "",
         symbolName: String = "pills.fill",
         colorName: String = ItemColor.blue.rawValue,
         date: Date = .now,
         dose: String = "",
         severity: Int = 0,
         note: String = "") {
        self.id = id
        self.kindRaw = kindRaw
        self.itemID = itemID
        self.itemName = itemName
        self.symbolName = symbolName
        self.colorName = colorName
        self.date = date
        self.dose = dose
        self.severity = severity
        self.note = note
    }

    convenience init(_ entry: LogEntry) {
        self.init(id: entry.id, kindRaw: entry.kind.rawValue, itemID: entry.itemID,
                  itemName: entry.itemName, symbolName: entry.symbolName,
                  colorName: entry.colorName, date: entry.date, dose: entry.dose,
                  severity: entry.severity, note: entry.note)
    }

    func apply(_ entry: LogEntry) {
        kindRaw = entry.kind.rawValue
        itemID = entry.itemID
        itemName = entry.itemName
        symbolName = entry.symbolName
        colorName = entry.colorName
        date = entry.date
        dose = entry.dose
        severity = entry.severity
        note = entry.note
    }

    var value: LogEntry {
        LogEntry(id: id, kind: EntryKind(rawValue: kindRaw) ?? .treatment, itemID: itemID,
                 itemName: itemName, symbolName: symbolName, colorName: colorName,
                 date: date, dose: dose, severity: severity, note: note)
    }
}

/// A day's worth of entries, newest day first — the shape History and the PDF use.
struct LogDay: Identifiable, Hashable, Sendable {
    var date: Date
    var entries: [LogEntry]

    var id: Date { date }

    /// Splits entries (any order) into days, newest first, each day newest first.
    static func group(_ entries: [LogEntry], calendar: Calendar = .current) -> [LogDay] {
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return byDay
            .map { LogDay(date: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }
}
