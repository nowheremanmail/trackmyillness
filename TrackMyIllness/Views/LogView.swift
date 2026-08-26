//
//  LogView.swift
//  TrackMyIllness
//
//  The Report tab: what happened, when, save. Everything above the fold is a tap
//  target — the date and time already default to now, so the common case is
//  "pick a chip, press Save".
//

import SwiftUI

struct LogView: View {
    /// Lets the empty state send the user to Settings to configure items.
    var openSettings: () -> Void = {}

    @State private var model: LogEntryViewModel
    @FocusState private var noteFocused: Bool

    init(openSettings: @escaping () -> Void = {}, model: LogEntryViewModel? = nil) {
        self.openSettings = openSettings
        _model = State(initialValue: model ?? LogEntryViewModel())
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    kindPicker
                    itemPicker
                    if model.canSave {
                        whenSection
                        detailsSection
                    }
                    saveButton
                    todaySection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Report"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if noteFocused {
                        Button("Done") { noteFocused = false }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let saved = model.lastSavedEntry {
                    SavedBanner(entry: saved,
                                undo: { model.undoLastSave() },
                                dismiss: { model.dismissConfirmation() })
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: model.lastSavedEntry)
            .animation(.snappy, value: model.selectedItemID)
        }
        .onAppear { model.refresh() }
    }

    // MARK: Sections

    private var kindPicker: some View {
        Picker("What are you reporting?", selection: $model.kind) {
            ForEach(EntryKind.allCases) { kind in
                Label(kind.title, systemImage: kind.systemImage).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var itemPicker: some View {
        if model.items.isEmpty {
            ContentUnavailableView {
                Label(model.kind.pluralTitle, systemImage: model.kind.systemImage)
            } description: {
                Text("You haven't configured any yet. Settings can add the usual ones for an illness in one go.")
            } actions: {
                Button("Open Settings", action: openSettings)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(model.items) { item in
                    CatalogChip(item: item, isSelected: model.selectedItemID == item.id) {
                        model.select(item)
                    }
                }
            }
        }
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("When")

            HStack(spacing: 8) {
                ForEach(TimeShortcut.allCases) { shortcut in
                    Button {
                        model.apply(shortcut)
                    } label: {
                        Text(shortcut.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.activeShortcut == shortcut ? Color.accentColor : Color.secondary)
                }
            }

            VStack(spacing: 0) {
                DatePicker("Date", selection: $model.timestamp, displayedComponents: .date)
                    .padding(.vertical, 6)
                Divider()
                DatePicker("Time", selection: $model.timestamp, displayedComponents: .hourAndMinute)
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Details")

            if model.showsSeverity {
                SeverityPicker(severity: $model.severity)
                    .padding(.bottom, 2)
            }

            VStack(spacing: 0) {
                if model.showsDose {
                    LabeledContent("Dose") {
                        TextField("e.g. 500 mg", text: $model.dose)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.vertical, 10)
                    Divider()
                }
                TextField("Note (optional)", text: $model.note, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($noteFocused)
                    .padding(.vertical, 10)
            }
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var saveButton: some View {
        Button {
            noteFocused = false
            model.save()
        } label: {
            Label("Save", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canSave)
    }

    @ViewBuilder
    private var todaySection: some View {
        if !model.today.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Today")
                ForEach(model.today) { entry in
                    EntryRow(entry: entry)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .contextMenu {
                            Button(role: .destructive) {
                                model.delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.top, 8)
        }
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

/// The "Saved" confirmation with an undo, so a wrong tap costs one more tap.
private struct SavedBanner: View {
    let entry: LogEntry
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("Saved \(entry.itemName)")
                    .font(.subheadline.weight(.medium))
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Undo", action: undo)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary)
        }
        // Auto-dismisses so it doesn't sit on top of the next entry.
        .task(id: entry.id) {
            try? await Task.sleep(for: .seconds(4))
            dismiss()
        }
    }
}

#Preview {
    LogView(model: LogEntryViewModel(catalog: PreviewData.catalogStore(),
                                     entries: PreviewData.entryStore()))
}

#Preview("Nothing configured") {
    LogView(model: LogEntryViewModel(catalog: CatalogStore(container: AppDatabase.previewContainer()),
                                     entries: EntryStore(container: AppDatabase.previewContainer())))
}
