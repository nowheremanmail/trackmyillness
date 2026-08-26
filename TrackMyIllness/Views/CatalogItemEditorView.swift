//
//  CatalogItemEditorView.swift
//  TrackMyIllness
//
//  Add or edit one treatment / symptom: its name, icon, colour and defaults.
//

import SwiftUI

struct CatalogItemEditorView: View {
    @State private var item: CatalogItem
    /// nil when creating — there's nothing to delete yet.
    private let deleteAction: ((CatalogItem) -> Void)?
    private let saveAction: (CatalogItem) -> Void
    private let isNew: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    init(item: CatalogItem,
         save: @escaping (CatalogItem) -> Void,
         delete: ((CatalogItem) -> Void)? = nil) {
        _item = State(initialValue: item)
        saveAction = save
        deleteAction = delete
        isNew = delete == nil
    }

    private var trimmedName: String {
        item.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $item.name)
                    LabeledContent("Preview") {
                        HStack(spacing: 8) {
                            Image(systemName: item.symbolName)
                                .foregroundStyle(item.color.color)
                            Text(trimmedName.isEmpty ? String(localized: "Unnamed") : trimmedName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Colour") {
                    ColorGrid(selection: $item.colorName)
                }

                Section("Icon") {
                    SymbolGrid(selection: $item.symbolName, tint: item.color.color, kind: item.kind)
                }

                if item.kind == .treatment {
                    Section {
                        TextField("e.g. 500 mg", text: $item.defaultDose)
                    } header: {
                        Text("Default dose")
                    } footer: {
                        Text("Prefilled when you report this treatment. Leave empty for none.")
                    }
                } else {
                    Section {
                        Toggle("Rate severity 1–5", isOn: $item.tracksSeverity)
                    } footer: {
                        Text("Adds a 1–5 rating to the entry form for this symptom.")
                    }
                }

                Section {
                    Toggle("Hide from the report form", isOn: $item.isArchived)
                } footer: {
                    Text("Keeps past entries intact but stops offering it for new ones.")
                }

                if let deleteAction {
                    Section {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .confirmationDialog("Delete \(trimmedName)?", isPresented: $confirmingDelete,
                                            titleVisibility: .visible) {
                            Button("Delete", role: .destructive) {
                                deleteAction(item)
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Entries already reported keep their name and are not removed.")
                        }
                    }
                }
            }
            .navigationTitle(Text(isNew ? "New" : "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAction(item)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}

/// The fixed palette, as a row of taps.
private struct ColorGrid: View {
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ItemColor.allCases) { color in
                Button {
                    selection = color.rawValue
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selection == color.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(2)
                        .overlay {
                            Circle().strokeBorder(Color.primary.opacity(selection == color.rawValue ? 0.4 : 0),
                                                  lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.rawValue))
            }
        }
        .padding(.vertical, 4)
    }
}

/// A curated set of SF Symbols — the full catalogue is far too much to scroll.
private struct SymbolGrid: View {
    @Binding var selection: String
    let tint: Color
    let kind: EntryKind

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    private static let treatmentSymbols = [
        "pills.fill", "pill.fill", "syringe.fill", "cross.vial.fill", "bandage.fill",
        "drop.fill", "eyedropper.halffull", "inhaler.fill", "cross.case.fill", "stethoscope",
        "sunrise.fill", "sun.max.fill", "moon.stars.fill", "fork.knife", "figure.walk",
        "heart.fill", "lungs.fill", "brain.head.profile", "waterbottle.fill", "leaf.fill",
    ]

    private static let symptomSymbols = [
        "bolt.fill", "flame.fill", "thermometer.high", "zzz", "wind",
        "head.profile.arrow.forward.and.visionpro", "eye.fill", "ear.fill", "nose.fill", "mouth.fill",
        "hand.raised.fill", "figure.fall", "waveform.path.ecg", "heart.slash.fill", "lungs.fill",
        "drop.fill", "exclamationmark.triangle.fill", "moon.zzz.fill", "cloud.rain.fill", "circle.dotted",
    ]

    private var symbols: [String] {
        let base = kind == .treatment ? Self.treatmentSymbols : Self.symptomSymbols
        // Keep a symbol the user already picked (or an older build's default) visible.
        return base.contains(selection) ? base : [selection] + base
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    selection = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(selection == symbol ? Color.white : tint)
                        .frame(width: 40, height: 40)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selection == symbol ? AnyShapeStyle(tint)
                                                          : AnyShapeStyle(tint.opacity(0.12)))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(symbol))
                .accessibilityAddTraits(selection == symbol ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Edit") {
    CatalogItemEditorView(item: PreviewData.sampleItem, save: { _ in }, delete: { _ in })
}

#Preview("New symptom") {
    CatalogItemEditorView(item: CatalogItem(kind: .symptom, symbolName: "bolt.fill",
                                            colorName: ItemColor.orange.rawValue),
                          save: { _ in })
}
