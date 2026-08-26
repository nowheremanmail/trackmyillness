//
//  HistoryView.swift
//  TrackMyIllness
//
//  The History tab: an overview chart, then every entry grouped by day, with the
//  PDF export one tap away.
//

import SwiftUI

struct HistoryView: View {
    @State private var model: HistoryViewModel
    @State private var showingExport = false

    init(model: HistoryViewModel? = nil) {
        _model = State(initialValue: model ?? HistoryViewModel())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $model.range) {
                        ForEach(HistoryRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                if model.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("Nothing logged yet", systemImage: "clock.badge.questionmark")
                        } description: {
                            Text("Entries you report will show up here.")
                        }
                    }
                } else {
                    Section {
                        HistoryChartView(stats: model.stats, showsSeverity: model.hasSeverityData)
                    } header: {
                        Text("Treatments: \(model.totalTreatments) · Symptoms: \(model.totalSymptoms)")
                    }

                    ForEach(model.days) { day in
                        Section {
                            ForEach(day.entries) { entry in
                                EntryRow(entry: entry)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            model.delete(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("History"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Show", selection: $model.kindFilter) {
                        Text("All").tag(EntryKind?.none)
                        ForEach(EntryKind.allCases) { kind in
                            Text(kind.pluralTitle).tag(EntryKind?.some(kind))
                        }
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingExport = true
                    } label: {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingExport) {
                ExportView(initialRange: model.range)
            }
        }
        .onAppear { model.refresh() }
    }
}

#Preview {
    HistoryView(model: HistoryViewModel(store: PreviewData.entryStore()))
}

#Preview("Empty") {
    HistoryView(model: HistoryViewModel(store: EntryStore(container: AppDatabase.previewContainer())))
}
