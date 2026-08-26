//
//  AppSettings.swift
//  TrackMyIllness
//
//  The @AppStorage keys, in one place so views and view models can't drift apart.
//

import Foundation

enum AppSettings {
    /// Face ID / Touch ID lock. Off by default — the user opts in from Settings.
    nonisolated static let biometricLockKey = "biometric_lock_enabled"
    /// Which kind the entry form opens on, remembered between visits.
    nonisolated static let lastEntryKindKey = "last_entry_kind"
    /// The history range the user last picked (a `HistoryRange` raw value).
    nonisolated static let historyRangeKey = "history_range"
}
