//
//  HistoryChartView.swift
//  TrackMyIllness
//
//  The overview at the top of History: how much was logged per day, and how bad
//  the symptoms were. Two small charts rather than one with two axes — a shared
//  axis for "counts" and "severity 1–5" would be misleading.
//

import Charts
import SwiftUI

struct HistoryChartView: View {
    let stats: [HistoryViewModel.DayStat]
    let showsSeverity: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Entries per day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Day", stat.date, unit: .day),
                        y: .value("Entries", stat.treatments))
                        .foregroundStyle(by: .value("Kind", EntryKind.treatment.exportTitle))
                    BarMark(
                        x: .value("Day", stat.date, unit: .day),
                        y: .value("Entries", stat.symptoms))
                        .foregroundStyle(by: .value("Kind", EntryKind.symptom.exportTitle))
                }
                .chartForegroundStyleScale([
                    EntryKind.treatment.exportTitle: EntryKind.treatment.tint,
                    EntryKind.symptom.exportTitle: EntryKind.symptom.tint,
                ])
                .chartLegend(position: .top, alignment: .leading, spacing: 4)
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 130)
            }

            if showsSeverity {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Average symptom severity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Chart(stats) { stat in
                        if let severity = stat.averageSeverity {
                            LineMark(
                                x: .value("Day", stat.date, unit: .day),
                                y: .value("Severity", severity))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.orange)
                            PointMark(
                                x: .value("Day", stat.date, unit: .day),
                                y: .value("Severity", severity))
                                .foregroundStyle(Color.orange)
                                .symbolSize(18)
                        }
                    }
                    .chartYScale(domain: 0...5)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 1, 2, 3, 4, 5])
                    }
                    .frame(height: 110)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let calendar = Calendar.current
    let stats = (0..<14).reversed().compactMap { offset -> HistoryViewModel.DayStat? in
        guard let date = calendar.date(byAdding: .day, value: -offset,
                                       to: calendar.startOfDay(for: .now)) else { return nil }
        return HistoryViewModel.DayStat(date: date, treatments: 2, symptoms: offset % 3,
                                        averageSeverity: offset % 3 == 0 ? nil : Double(2 + offset % 4))
    }
    List {
        HistoryChartView(stats: stats, showsSeverity: true)
    }
}
