//
//  ItemColor.swift
//  TrackMyIllness
//
//  The fixed palette a catalog item can be tagged with. Stored by name so the
//  database keeps a stable, human-readable value.
//

import SwiftUI

enum ItemColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue, teal, green, yellow, orange, red, pink, purple, indigo, brown, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .yellow: .yellow
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        case .indigo: .indigo
        case .brown: .brown
        case .gray: .gray
        }
    }

    /// Falls back to a sensible default when the stored name is unknown.
    static func named(_ name: String) -> ItemColor {
        ItemColor(rawValue: name) ?? .blue
    }
}
