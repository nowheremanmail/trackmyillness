//
//  EntryKind.swift
//  TrackMyIllness
//
//  The two things the app logs: a treatment taken, or a symptom felt.
//

import SwiftUI

enum EntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case treatment
    case symptom

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .treatment: "Treatment"
        case .symptom: "Symptom"
        }
    }

    /// Plural form, used for section headers and settings rows.
    var pluralTitle: LocalizedStringKey {
        switch self {
        case .treatment: "Treatments"
        case .symptom: "Symptoms"
        }
    }

    var systemImage: String {
        switch self {
        case .treatment: "pills.fill"
        case .symptom: "waveform.path.ecg"
        }
    }

    /// Tint for the kind itself (chips inherit their item's colour instead).
    var tint: Color {
        switch self {
        case .treatment: .teal
        case .symptom: .orange
        }
    }

    /// Untranslated label used in the exported PDF, which is plain text.
    var exportTitle: String {
        switch self {
        case .treatment: String(localized: "Treatment")
        case .symptom: String(localized: "Symptom")
        }
    }
}
