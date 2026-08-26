//
//  ClosedIllness.swift
//  TrackMyIllness
//
//  A finished illness: the log as it stood when you closed it, kept read-only so
//  the live log can start clean without throwing anything away.
//
//  The entries themselves aren't copied anywhere — they stay in the entry table
//  tagged with this record's id (see `LogEntry.archiveID`), so an archived entry
//  keeps every field it ever had and nothing can drift out of sync.
//

import Foundation
import SwiftData

struct ClosedIllness: Identifiable, Hashable, Sendable {
    var id: String = UUID().uuidString
    var name: String = ""
    /// When the user closed it.
    var closedAt: Date = Date.now
    /// The first and last entry it holds. Both equal `closedAt` when it holds none.
    var startedAt: Date = Date.now
    var endedAt: Date = Date.now
    var treatmentCount: Int = 0
    var symptomCount: Int = 0
    var note: String = ""

    var entryCount: Int { treatmentCount + symptomCount }
    var isEmpty: Bool { entryCount == 0 }

    /// The span the detail screen and the PDF header describe.
    var dateRange: ClosedRange<Date> { min(startedAt, endedAt)...max(startedAt, endedAt) }

    /// How many days it ran, counting both ends — "1 day" for a single-day illness.
    func dayCount(calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: startedAt)
        let to = calendar.startOfDay(for: endedAt)
        return (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1
    }
}

@Model
final class ClosedIllnessRecord {
    @Attribute(.unique) var id: String = UUID().uuidString
    var name: String = ""
    var closedAt: Date = Date.now
    var startedAt: Date = Date.now
    var endedAt: Date = Date.now
    var treatmentCount: Int = 0
    var symptomCount: Int = 0
    var note: String = ""

    init(id: String = UUID().uuidString,
         name: String = "",
         closedAt: Date = .now,
         startedAt: Date = .now,
         endedAt: Date = .now,
         treatmentCount: Int = 0,
         symptomCount: Int = 0,
         note: String = "") {
        self.id = id
        self.name = name
        self.closedAt = closedAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.treatmentCount = treatmentCount
        self.symptomCount = symptomCount
        self.note = note
    }

    convenience init(_ illness: ClosedIllness) {
        self.init(id: illness.id, name: illness.name, closedAt: illness.closedAt,
                  startedAt: illness.startedAt, endedAt: illness.endedAt,
                  treatmentCount: illness.treatmentCount, symptomCount: illness.symptomCount,
                  note: illness.note)
    }

    /// Only the fields the detail screen can edit; the counts and dates are facts
    /// about the archive and aren't the user's to rewrite.
    func apply(name: String, note: String) {
        self.name = name
        self.note = note
    }

    var value: ClosedIllness {
        ClosedIllness(id: id, name: name, closedAt: closedAt, startedAt: startedAt,
                      endedAt: endedAt, treatmentCount: treatmentCount,
                      symptomCount: symptomCount, note: note)
    }
}
