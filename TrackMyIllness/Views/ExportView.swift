//
//  ExportView.swift
//  TrackMyIllness
//
//  Pick a period, build the PDF, share it. Presented as a sheet from History and
//  from Settings.
//

import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ExportViewModel

    init(initialRange: HistoryRange = .month, model: ExportViewModel? = nil) {
        let model = model ?? ExportViewModel()
        model.range = initialRange
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Period", selection: $model.range) {
                        ForEach(HistoryRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    Picker("Include", selection: $model.kindFilter) {
                        Text("Everything").tag(EntryKind?.none)
                        ForEach(EntryKind.allCases) { kind in
                            Text(kind.pluralTitle).tag(EntryKind?.some(kind))
                        }
                    }
                    if model.hasNotes {
                        Toggle("Include notes", isOn: $model.includesNotes)
                    }
                } footer: {
                    if model.hasNotes, !model.includesNotes {
                        Text("Entries to include: \(model.entryCount). Your notes are left out of the report.")
                    } else {
                        Text("Entries to include: \(model.entryCount)")
                    }
                }

                Section {
                    if let url = model.fileURL {
                        ShareLink(item: url) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        Label(url.lastPathComponent, systemImage: "doc.richtext")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Button {
                            model.generate()
                        } label: {
                            HStack {
                                Label("Create PDF", systemImage: "doc.badge.plus")
                                if model.isGenerating {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(model.isGenerating || model.entryCount == 0)
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Text("Export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ExportView(model: ExportViewModel(store: PreviewData.entryStore()))
}
