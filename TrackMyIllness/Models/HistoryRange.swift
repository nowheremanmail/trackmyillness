//
//  HistoryRange.swift
//  TrackMyIllness
//
//  The period History and the PDF export look at.
//

import Foundation
import SwiftUI

enum HistoryRange: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case quarter
    case all

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .week: "7 days"
        case .month: "30 days"
        case .quarter: "90 days"
        case .all: "All"
        }
    }

    /// Days back from today, or nil for "everything".
    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .all: nil
        }
    }

    /// The closed date range to query, ending at the end of today.
    func dateRange(now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            .map { $0.addingTimeInterval(-1) } ?? now
        guard let days else {
            // "All" still needs a lower bound for the fetch predicate; 100 years is
            // comfortably before any entry this app could hold.
            return (calendar.date(byAdding: .year, value: -100, to: end) ?? .distantPast)...end
        }
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(days - 1), to: now) ?? now)
        return start...end
    }
}
