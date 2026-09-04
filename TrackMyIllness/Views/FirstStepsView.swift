//
//  FirstStepsView.swift
//  TrackMyIllness
//
//  What a new install sees first. The app deliberately creates nothing on its
//  own, so without this the Report tab would open empty with no explanation.
//
//  It carries its own navigation stack and catalog view model, so "Choose an
//  illness" can push the real picker right here — the first thing the app asks
//  for is also the first thing it helps with, rather than sending the reader off
//  to find Settings.
//

import SwiftUI

struct FirstStepsView: View {
    /// Called when the reader is done with this screen, whether they picked
    /// something or skipped.
    var finish: () -> Void = {}

    @State private var catalog: CatalogViewModel
    /// Value-based, so adding an illness can empty it and land the reader back
    /// here. `dismiss()` inside the pushed screens only pops one level, which is
    /// what used to strand them on the illness list.
    @State private var path: [Route] = []
    /// How many items the last add created, so returning here shows that it worked
    /// rather than looking like nothing happened.
    @State private var addedCount: Int?

    private enum Route: Hashable { case picker }

    init(finish: @escaping () -> Void = {}, catalog: CatalogViewModel? = nil) {
        self.finish = finish
        _catalog = State(initialValue: catalog ?? CatalogViewModel())
    }

    private struct Step: Identifiable {
        let id = UUID()
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    private let steps = [
        Step(symbol: "list.bullet.clipboard",
             title: "Choose what to track",
             detail: "Pick an illness and the treatments and symptoms usually tracked for it are created for you. You can edit or remove any of them."),
        Step(symbol: "plus.circle.fill",
             title: "Report in two taps",
             detail: "Tap what happened and save. The date starts at today and the time at now, with shortcuts for a while ago."),
        Step(symbol: "clock.arrow.circlepath",
             title: "Look back",
             detail: "Your entries are grouped by day, with a chart of how the days compare. Any period exports as a PDF for an appointment."),
        Step(symbol: "lock.shield",
             title: "It stays on your device",
             detail: "No account, no tracking, nothing uploaded. You can lock the app with Face ID from Settings."),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    // Above the steps, not below them: under the fold it needed a
                    // scroll to be seen, which is no confirmation at all.
                    if let addedCount, addedCount > 0 {
                        confirmation(addedCount)
                    }
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(steps) { step in
                            row(step)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .navigationDestination(for: Route.self) { _ in
                IllnessPickerView(model: catalog) { added in
                    addedCount = added
                    // Back to the root of this stack, however deep the reader got.
                    path.removeAll()
                }
            }
            .safeAreaInset(edge: .bottom) { actions }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now", action: finish)
                        .font(.subheadline)
                }
            }
        }
        .animation(.snappy, value: addedCount)
        .onAppear { catalog.refresh() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(.appIconArt)
                .resizable()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 76 * 0.224, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                .accessibilityHidden(true)
            Text("Symptrace")
                .font(.title.weight(.semibold))
            Text("A private log of what you took and how you felt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func row(_ step: Step) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: step.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.headline)
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func confirmation(_ count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ready to report")
                    .font(.subheadline.weight(.semibold))
                // A bare count rather than a plural sentence: it reads correctly
                // for one or many in every language the app ships.
                Text("Added to your list: \(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var actions: some View {
        VStack(spacing: 8) {
            NavigationLink(value: Route.picker) {
                Text(catalog.isEmpty ? "Choose an illness" : "Add another illness")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Once something is configured there's nothing left to set up, so the
            // way out stops being a skip and becomes a finish.
            Button(catalog.isEmpty ? "I'll add my own" : "Done", action: finish)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .background(.regularMaterial)
    }
}

#Preview("First run") {
    FirstStepsView(catalog: CatalogViewModel(
        store: CatalogStore(container: AppDatabase.previewContainer())))
}

#Preview("Something already configured") {
    FirstStepsView(catalog: CatalogViewModel(store: PreviewData.catalogStore()))
}
