//
//  EntryRow.swift
//  TrackMyIllness
//
//  One logged entry, as shown in the Report tab's "today" list and in History.
//

import SwiftUI

struct EntryRow: View {
    let entry: LogEntry
    /// Shows the day as well as the time (History's "All" list wants it, today's
    /// list doesn't).
    var showsDate: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(entry.color.color)
                .frame(width: 34, height: 34)
                .background(entry.color.color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.itemName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                if showsDate {
                    Text(entry.date, format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// "Treatment · 500 mg · Severity 4/5 · note"
    private var detail: String {
        var parts: [String] = []
        if !entry.dose.isEmpty { parts.append(entry.dose) }
        if entry.hasSeverity { parts.append(String(localized: "Severity \(entry.severity)/5")) }
        if !entry.note.isEmpty { parts.append(entry.note) }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        EntryRow(entry: PreviewData.sampleEntry)
        EntryRow(entry: LogEntry(kind: .treatment, itemName: "Painkiller",
                                 symbolName: "pills.fill", colorName: ItemColor.teal.rawValue,
                                 date: .now, dose: "500 mg"), showsDate: true)
    }
}
