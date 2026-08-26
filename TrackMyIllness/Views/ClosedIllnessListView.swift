//
//  ClosedIllnessListView.swift
//  TrackMyIllness
//
//  The illnesses you've closed, reachable from Settings. Read-only history: tap
//  one to read its log or export it.
//

import SwiftUI

struct ClosedIllnessListView: View {
    @Bindable var model: ClosedIllnessViewModel

    var body: some View {
        List {
            if model.isEmpty {
                ContentUnavailableView {
                    Label("No closed illnesses", systemImage: "archivebox")
                } description: {
                    Text("When you close an illness, its log is archived here.")
                }
            }
            ForEach(model.illnesses) { illness in
                NavigationLink {
                    ClosedIllnessDetailView(illness: illness, model: model)
                } label: {
                    row(illness)
                }
            }
            .onDelete { model.delete(at: $0) }
        }
        .navigationTitle(Text("Closed illnesses"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !model.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        .onAppear { model.refresh() }
    }

    private func row(_ illness: ClosedIllness) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(illness.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(ClosedIllnessFormat.period(illness))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Treatments: \(illness.treatmentCount) · Symptoms: \(illness.symptomCount)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Shared between the list, the detail header and the Settings row, so one
/// illness never reads as two different date spans.
enum ClosedIllnessFormat {
    static func period(_ illness: ClosedIllness) -> String {
        let from = illness.startedAt.formatted(date: .abbreviated, time: .omitted)
        let to = illness.endedAt.formatted(date: .abbreviated, time: .omitted)
        return from == to ? from : "\(from) – \(to)"
    }
}

#Preview {
    NavigationStack {
        ClosedIllnessListView(model: PreviewData.closedIllnessModel())
    }
}

#Preview("Empty") {
    NavigationStack {
        ClosedIllnessListView(model: ClosedIllnessViewModel(
            store: ClosedIllnessStore(container: AppDatabase.previewContainer())))
    }
}
