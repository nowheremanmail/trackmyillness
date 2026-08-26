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
    /// Whether the PDF export includes the free-text notes. On by default: the
    /// report is more useful with them, and the user can turn them off per export.
    nonisolated static let exportIncludesNotesKey = "export_includes_notes"
    /// Whether the first-run walkthrough has been shown. Set once it's dismissed,
    /// however it was dismissed — nobody wants to be walked through twice.
    nonisolated static let hasSeenFirstStepsKey = "has_seen_first_steps"
}
