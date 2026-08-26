//
//  CatalogListView.swift
//  TrackMyIllness
//
//  The editable list of treatments (or symptoms) reachable from Settings.
//

import SwiftUI

struct CatalogListView: View {
    let kind: EntryKind
    @Bindable var model: CatalogViewModel

    @State private var editing: CatalogItem?
    @State private var isCreating = false

    private var items: [CatalogItem] { model.items(of: kind) }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView {
                    Label(kind.pluralTitle, systemImage: kind.systemImage)
                } description: {
                    Text("Add the ones you want to report.")
                }
            }
            ForEach(items) { item in
                Button {
                    editing = item
                } label: {
                    row(item)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button {
                        model.setArchived(!item.isArchived, for: item)
                    } label: {
                        Label(item.isArchived ? "Restore" : "Hide",
                              systemImage: item.isArchived ? "eye" : "eye.slash")
                    }
                    .tint(.indigo)
                }
            }
            .onDelete { model.delete(at: $0, in: kind) }
            .onMove { model.move(from: $0, to: $1, in: kind) }
        }
        .navigationTitle(Text(kind.pluralTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        .sheet(item: $editing) { item in
            CatalogItemEditorView(item: item) { model.save($0) } delete: { model.delete($0) }
        }
        .sheet(isPresented: $isCreating) {
            CatalogItemEditorView(item: model.newItem(of: kind)) { model.save($0) }
        }
        .onAppear { model.refresh() }
    }

    private func row(_ item: CatalogItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(item.color.color)
                .frame(width: 32, height: 32)
                .background(item.color.color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .foregroundStyle(item.isArchived ? .secondary : .primary)
                if !subtitle(item).isEmpty {
                    Text(subtitle(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if item.isArchived {
                Image(systemName: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func subtitle(_ item: CatalogItem) -> String {
        var parts: [String] = []
        if item.isArchived { parts.append(String(localized: "Hidden")) }
        if !item.defaultDose.isEmpty { parts.append(item.defaultDose) }
        if item.kind == .symptom, item.tracksSeverity { parts.append(String(localized: "Rates severity")) }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        CatalogListView(kind: .treatment, model: CatalogViewModel(store: PreviewData.catalogStore()))
    }
}

#Preview("Symptoms") {
    NavigationStack {
        CatalogListView(kind: .symptom, model: CatalogViewModel(store: PreviewData.catalogStore()))
    }
}
