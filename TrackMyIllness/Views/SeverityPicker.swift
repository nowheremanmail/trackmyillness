//
//  SeverityPicker.swift
//  TrackMyIllness
//
//  How bad a symptom is, 1–5, as five tap targets rather than a slider — a slider
//  is fiddly one-handed and this only has five stops.
//

import SwiftUI

struct SeverityPicker: View {
    @Binding var severity: Int

    private static let levels = 1...5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Self.levels, id: \.self) { level in
                    Button {
                        // Tapping the current level clears it, so "not recorded" is
                        // reachable without a separate control.
                        severity = (severity == level) ? 0 : level
                    } label: {
                        Text("\(level)")
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(severity == level ? .white : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(severity == level
                                          ? AnyShapeStyle(Self.color(level))
                                          : AnyShapeStyle(Self.color(level).opacity(0.15)))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Severity \(level) of 5"))
                    .accessibilityAddTraits(severity == level ? [.isSelected] : [])
                }
            }
            Text(Self.caption(severity))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Green through red as it gets worse.
    private static func color(_ level: Int) -> Color {
        switch level {
        case 1: .green
        case 2: .mint
        case 3: .yellow
        case 4: .orange
        default: .red
        }
    }

    private static func caption(_ level: Int) -> LocalizedStringKey {
        switch level {
        case 1: "Barely noticeable"
        case 2: "Mild"
        case 3: "Moderate"
        case 4: "Bad"
        case 5: "Unbearable"
        default: "Not recorded — tap a number to rate it"
        }
    }
}

#Preview {
    @Previewable @State var severity = 3
    SeverityPicker(severity: $severity).padding()
}
