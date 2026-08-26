//
//  IllnessPickerView.swift
//  TrackMyIllness
//
//  Pick an illness and get the treatments and symptoms usually tracked for it,
//  instead of typing a catalog out by hand. Reachable from Settings, and the first
//  thing a new install is pointed at.
//
//  Nothing is added until the user taps Add on the detail screen, and the detail
//  screen shows exactly what's missing — so picking a second illness that overlaps
//  the first is honest about creating only the difference.
//

import SwiftUI

struct IllnessPickerView: View {
    @Bindable var model: CatalogViewModel

    var body: some View {
        List {
            Section {
                ForEach(IllnessTemplate.all) { illness in
                    NavigationLink {
                        IllnessDetailView(illness: illness, model: model)
                    } label: {
                        row(illness)
                    }
                }
            } footer: {
                Text("Everything an illness creates is an ordinary treatment or symptom afterwards — rename it, recolour it or remove it as you like.")
            }
        }
        .navigationTitle(Text("Add from an illness"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.refresh() }
    }

    private func row(_ illness: IllnessTemplate) -> some View {
        let pending = model.pendingCount(in: illness)
        return HStack(spacing: 12) {
            Image(systemName: illness.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(illness.name)
                HStack(spacing: 10) {
                    countLabel(illness.treatments.count, kind: .treatment)
                    countLabel(illness.symptoms.count, kind: .symptom)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            // A tick means there's nothing left to create, so the user doesn't open
            // a screen only to find its button disabled.
            if pending == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel(Text("Already added"))
            }
        }
    }

    private func countLabel(_ count: Int, kind: EntryKind) -> some View {
        Label("\(count)", systemImage: kind.systemImage)
            .foregroundStyle(kind.tint)
            .accessibilityLabel(Text(kind.pluralTitle))
            .accessibilityValue(Text("\(count)"))
    }
}

/// What one illness would create, and the button that creates it.
private struct IllnessDetailView: View {
    let illness: IllnessTemplate
    @Bindable var model: CatalogViewModel

    @Environment(\.dismiss) private var dismiss

    private var pending: Int { model.pendingCount(in: illness) }

    var body: some View {
        List {
            ForEach(EntryKind.allCases) { kind in
                Section {
                    ForEach(illness.items(of: kind), id: \.name) { item in
                        row(item, kind: kind)
                    }
                } header: {
                    Text(kind.pluralTitle)
                }
            }

            Section {
                Button {
                    model.add(illness)
                    dismiss()
                } label: {
                    Label("Add to my catalog", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(pending == 0)
            } footer: {
                if pending == 0 {
                    Text("Everything from this illness is already in your catalog.")
                } else if pending < illness.itemCount {
                    Text("The ones you already have are left untouched.")
                }
            }
        }
        .navigationTitle(Text(illness.name))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ item: IllnessItem, kind: EntryKind) -> some View {
        let color = ItemColor.named(item.colorName).color
        let configured = model.isConfigured(item, of: kind)
        return HStack(spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15), in: Circle())

            Text(item.name)
                .foregroundStyle(configured ? .secondary : .primary)
            Spacer()
            if configured {
                Text("Already added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Empty catalog") {
    NavigationStack {
        IllnessPickerView(model: CatalogViewModel(
            store: CatalogStore(container: AppDatabase.previewContainer())))
    }
}

#Preview("Some already configured") {
    NavigationStack {
        IllnessPickerView(model: CatalogViewModel(store: PreviewData.catalogStore()))
    }
}
