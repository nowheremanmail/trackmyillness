//
//  CloseIllnessView.swift
//  TrackMyIllness
//
//  Closes the current illness: names it, shows exactly what is about to be
//  archived, and files it away so the live log can start clean.
//

import SwiftUI

struct CloseIllnessView: View {
    /// Handed the illness that was just closed, so the caller can refresh and,
    /// if it wants, open it.
    var onClose: (ClosedIllness) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var model: CloseIllnessViewModel
    @State private var confirming = false

    init(onClose: @escaping (ClosedIllness) -> Void = { _ in },
         model: CloseIllnessViewModel? = nil) {
        self.onClose = onClose
        _model = State(initialValue: model ?? CloseIllnessViewModel())
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.hasSomethingToClose {
                    form
                } else {
                    ContentUnavailableView {
                        Label("Nothing to close", systemImage: "checkmark.circle")
                    } description: {
                        Text("There are no entries in the current log yet.")
                    }
                }
            }
            .navigationTitle(Text("Close illness"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { model.refresh() }
    }

    private var form: some View {
        Form {
            Section {
                TextField("Name", text: $model.name)
                TextField("Note (optional)", text: $model.note, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text("Name this illness")
            } footer: {
                Text("You'll find it under Closed illnesses in Settings.")
            }

            Section("What gets archived") {
                summaryRow("Entries", value: "\(model.entryCount)")
                summaryRow(EntryKind.treatment.pluralTitle, value: "\(model.treatmentCount)")
                summaryRow(EntryKind.symptom.pluralTitle, value: "\(model.symptomCount)")
                if let range = model.dateRange {
                    summaryRow("Period", value: period(range))
                    summaryRow("Days", value: "\(model.dayCount)")
                }
            }

            Section {
                Toggle(isOn: $model.keepCatalog) {
                    Label("Keep what I can report", systemImage: "list.bullet")
                }
            } footer: {
                Text(model.keepCatalog
                     ? "Your treatments and symptoms stay configured, ready for whatever you track next."
                     : "Your treatments and symptoms are deleted too, leaving the app as it was on day one. Entries already archived keep their names.")
            }

            Section {
                Button {
                    confirming = true
                } label: {
                    Label("Close this illness", systemImage: "archivebox")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!model.canClose)
            } footer: {
                Text("The log is archived, not deleted — you can read it and export it at any time. The Report and History tabs start empty.")
            }
        }
        .confirmationDialog("Close and archive?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Close it") { close() }
            Button("Cancel", role: .cancel) {}
        } message: {
            // Plain counts rather than inflected plurals: the catalog would need a
            // per-language plural rule for a sentence that reads fine either way.
            Text(model.keepCatalog
                 ? "Entries moving to Closed illnesses: \(model.entryCount). This can't be undone."
                 : "Entries moving to Closed illnesses: \(model.entryCount). Your configured treatments and symptoms are deleted too. This can't be undone.")
        }
    }

    private func close() {
        guard let closed = model.close() else { return }
        onClose(closed)
        dismiss()
    }

    private func summaryRow(_ title: LocalizedStringKey, value: String) -> some View {
        LabeledContent(title) {
            Text(value).monospacedDigit()
        }
    }

    private func period(_ range: ClosedRange<Date>) -> String {
        let from = range.lowerBound.formatted(date: .abbreviated, time: .omitted)
        let to = range.upperBound.formatted(date: .abbreviated, time: .omitted)
        return from == to ? from : "\(from) – \(to)"
    }
}

#Preview {
    CloseIllnessView(model: CloseIllnessViewModel(entries: PreviewData.entryStore(),
                                                  archive: PreviewData.closedIllnessStore(),
                                                  catalog: PreviewData.catalogStore()))
}

#Preview("Nothing logged") {
    CloseIllnessView(model: CloseIllnessViewModel(
        entries: EntryStore(container: AppDatabase.previewContainer()),
        archive: ClosedIllnessStore(container: AppDatabase.previewContainer()),
        catalog: CatalogStore(container: AppDatabase.previewContainer())))
}
