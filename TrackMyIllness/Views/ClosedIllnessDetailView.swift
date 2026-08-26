//
//  ClosedIllnessDetailView.swift
//  TrackMyIllness
//
//  One closed illness: its summary and the whole archived log, read-only, with a
//  PDF of just this illness one tap away.
//

import SwiftUI

struct ClosedIllnessDetailView: View {
    let illness: ClosedIllness
    @Bindable var model: ClosedIllnessViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var days: [LogDay] = []
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var editing = false
    @State private var confirmingDelete = false
    /// Local copy so a rename shows immediately without popping back to the list.
    @State private var current: ClosedIllness

    init(illness: ClosedIllness, model: ClosedIllnessViewModel) {
        self.illness = illness
        self.model = model
        _current = State(initialValue: illness)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Period", value: ClosedIllnessFormat.period(current))
                LabeledContent("Days") { Text("\(current.dayCount())").monospacedDigit() }
                LabeledContent("Entries") { Text("\(current.entryCount)").monospacedDigit() }
                LabeledContent(EntryKind.treatment.pluralTitle) {
                    Text("\(current.treatmentCount)").monospacedDigit()
                }
                LabeledContent(EntryKind.symptom.pluralTitle) {
                    Text("\(current.symptomCount)").monospacedDigit()
                }
                LabeledContent("Closed", value: current.closedAt.formatted(date: .abbreviated, time: .shortened))
            } header: {
                Text("Summary")
            } footer: {
                if !current.note.isEmpty {
                    Text(current.note)
                }
            }

            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        export()
                    } label: {
                        HStack {
                            Label("Export to PDF", systemImage: "doc.richtext")
                            if isExporting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting || days.isEmpty)
                }
            }

            ForEach(days) { day in
                Section {
                    ForEach(day.entries) { entry in
                        EntryRow(entry: entry)
                    }
                } header: {
                    Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide))
                }
            }
        }
        .navigationTitle(Text(current.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        editing = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $editing) {
            ClosedIllnessEditor(name: current.name, note: current.note) { name, note in
                model.rename(current, to: name, note: note)
                current.name = name
                current.note = note
            }
        }
        .confirmationDialog("Delete \(current.name)?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.delete(current)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the archived log for good, including every entry in it. This can't be undone.")
        }
        .onAppear {
            // The archive never changes underneath us, so loading once is enough.
            if days.isEmpty { days = model.days(in: current) }
        }
    }

    private func export() {
        isExporting = true
        defer { isExporting = false }
        exportURL = model.exportPDF(for: current)
    }
}

/// Renaming a closed illness, and editing the note that goes with it.
private struct ClosedIllnessEditor: View {
    @State private var name: String
    @State private var note: String
    let save: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    init(name: String, note: String, save: @escaping (String, String) -> Void) {
        _name = State(initialValue: name)
        _note = State(initialValue: note)
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Note (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }
            .navigationTitle(Text("Rename"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(name.trimmingCharacters(in: .whitespacesAndNewlines),
                             note.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    let model = PreviewData.closedIllnessModel()
    NavigationStack {
        if let illness = model.illnesses.first {
            ClosedIllnessDetailView(illness: illness, model: model)
        }
    }
}
