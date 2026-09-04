//
//  RemoteIllnessListView.swift
//  TrackMyIllness
//
//  The extra illnesses published on the project wiki, so the list can grow
//  between releases.
//
//  Once downloaded they're ordinary templates, so they reuse IllnessDetailView
//  and the same "only creates what's missing" behaviour as the built-in list.
//

import SwiftUI

struct RemoteIllnessListView: View {
    @Bindable var model: CatalogViewModel
    /// Passed down to the detail screens — see `IllnessDetailView.onAdd`.
    var onAdd: ((Int) -> Void)?

    @State private var remote: RemoteIllnessViewModel

    init(model: CatalogViewModel, onAdd: ((Int) -> Void)? = nil,
         remote: RemoteIllnessViewModel? = nil) {
        self.model = model
        self.onAdd = onAdd
        _remote = State(initialValue: remote ?? RemoteIllnessViewModel())
    }

    var body: some View {
        List {
            if remote.isLoading {
                loadingRow
            } else if let message = remote.errorMessage {
                failure(message)
            } else if !remote.illnesses.isEmpty {
                Section {
                    ForEach(remote.illnesses) { illness in
                        NavigationLink {
                            IllnessDetailView(illness: illness, model: model, onAdd: onAdd)
                        } label: {
                            row(illness)
                        }
                    }
                } footer: {
                    Text("Downloaded from the project wiki. Everything it creates is an ordinary treatment or symptom afterwards.")
                }
            }
        }
        .navigationTitle(Text("More illnesses"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await remote.loadIfNeeded() }
        .refreshable { await remote.load() }
    }

    private var loadingRow: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Downloading the list…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("More illnesses", systemImage: "arrow.down.circle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") {
                Task { await remote.load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .listRowBackground(Color.clear)
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

private extension IllnessTemplate {
    /// Sample rows for the previews below, so they don't hit the network.
    static let previewRemote = [
        IllnessTemplate(id: "hypothyroidism", name: "Hypothyroidism",
                        symbolName: "cross.vial.fill",
                        treatments: [IllnessItem(name: "Thyroid medication",
                                                symbolName: "pill.fill",
                                                colorName: ItemColor.teal.rawValue,
                                                tracksSeverity: false)],
                        symptoms: [IllnessItem(name: "Fatigue", symbolName: "zzz",
                                              colorName: ItemColor.purple.rawValue,
                                              tracksSeverity: true)]),
    ]
}

#Preview("Loaded") {
    NavigationStack {
        RemoteIllnessListView(
            model: CatalogViewModel(store: PreviewData.catalogStore()),
            remote: RemoteIllnessViewModel(
                loader: StubRemoteIllnessLoader(templates: IllnessTemplate.previewRemote)))
    }
}

#Preview("Nothing published") {
    NavigationStack {
        RemoteIllnessListView(
            model: CatalogViewModel(store: PreviewData.catalogStore()),
            remote: RemoteIllnessViewModel(
                loader: StubRemoteIllnessLoader(
                    failure: RemoteIllnessLoader.Failure.notPublished)))
    }
}
