//
//  TimeShortcut.swift
//  TrackMyIllness
//
//  The "30 min ago / 1 h ago / 2 h ago" buttons on the entry form, so reporting
//  something you took a while back is one tap.
//

import Foundation
import SwiftUI

enum TimeShortcut: String, CaseIterable, Identifiable, Sendable {
    case now
    case thirtyMinutes
    case oneHour
    case twoHours

    var id: String { rawValue }

    /// How far back from the reference point this shortcut is.
    var offset: TimeInterval {
        switch self {
        case .now: 0
        case .thirtyMinutes: -30 * 60
        case .oneHour: -60 * 60
        case .twoHours: -2 * 60 * 60
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .now: "Now"
        case .thirtyMinutes: "30 min ago"
        case .oneHour: "1 h ago"
        case .twoHours: "2 h ago"
        }
    }

    func date(from reference: Date = .now) -> Date {
        reference.addingTimeInterval(offset)
    }
}
