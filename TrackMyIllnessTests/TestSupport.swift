//
//  TestSupport.swift
//  TrackMyIllnessTests
//
//  Shared fixtures: a time-zone-pinned calendar, throwaway in-memory stores and
//  small builders, so no test depends on the host's locale or on the real store.
//

import Foundation
import SwiftData
@testable import TrackMyIllness

enum Fixture {
    /// Gregorian and pinned to UTC, so the day maths under test can't drift with
    /// the machine's time zone or a DST transition.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// A fresh, empty in-memory container — one per test, so tests can't see each
    /// other's writes.
    static func container() -> ModelContainer { AppDatabase.previewContainer() }

    /// An exact integer instant, so a Date survives a round trip through the store
    /// without any floating-point wobble. 2023-11-14 22:13:20 UTC.
    static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    static func item(kind: EntryKind = .treatment,
                     name: String = "Painkiller",
                     id: String = UUID().uuidString,
                     defaultDose: String = "",
                     tracksSeverity: Bool = false,
                     isArchived: Bool = false,
                     sortIndex: Int = 0) -> CatalogItem {
        CatalogItem(id: id, kind: kind, name: name, symbolName: "pills.fill",
                    colorName: ItemColor.teal.rawValue, defaultDose: defaultDose,
                    tracksSeverity: tracksSeverity, isArchived: isArchived, sortIndex: sortIndex)
    }

    static func entry(kind: EntryKind = .treatment,
                      name: String = "Painkiller",
                      date: Date = fixedDate,
                      dose: String = "",
                      severity: Int = 0,
                      note: String = "") -> LogEntry {
        LogEntry(kind: kind, itemID: "item-\(name)", itemName: name,
                 symbolName: "pills.fill", colorName: ItemColor.teal.rawValue,
                 date: date, dose: dose, severity: severity, note: note)
    }

    /// An entry reporting a real catalog item, carrying the item id the Report
    /// tab's usage ranking looks up. `entry(name:)` invents an id from the name,
    /// which is fine on its own but never matches a stored item.
    static func entry(reporting item: CatalogItem, date: Date = fixedDate,
                      severity: Int = 0) -> LogEntry {
        LogEntry(kind: item.kind, itemID: item.id, itemName: item.name,
                 symbolName: item.symbolName, colorName: item.colorName,
                 date: date, dose: item.defaultDose, severity: severity)
    }

    /// `days` before today at `hour` UTC — the shape History and export tests need.
    static func daysAgo(_ days: Int, hour: Int = 12) -> Date {
        let calendar = calendar
        let midnight = calendar.date(byAdding: .day, value: -days,
                                     to: calendar.startOfDay(for: .now))!
        return midnight.addingTimeInterval(TimeInterval(hour * 3600))
    }

    /// Clears the preferences the view models persist, so a suite starts from the
    /// app's first-run defaults rather than whatever ran before it.
    static func resetDefaults() {
        for key in [AppSettings.biometricLockKey,
                    AppSettings.lastEntryKindKey,
                    AppSettings.historyRangeKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

/// A biometric stub that hands control back to the test while the prompt is
/// notionally on screen — the window in which `handle(scenePhase:)` must *not*
/// re-lock the app underneath its own Face ID sheet.
@MainActor
final class GatedBiometricAuthenticator: BiometricAuthenticating {
    var style: BiometryStyle = .faceID
    var failureMessage: String?
    var whilePrompting: (() -> Void)?

    func authenticate(reason: String) async -> String? {
        whilePrompting?()
        return failureMessage
    }
}
