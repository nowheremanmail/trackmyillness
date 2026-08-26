//
//  SettingsView.swift
//  TrackMyIllness
//
//  Configure the treatments and symptoms you can report, the Face ID lock, and
//  the way out to About.
//

import SwiftUI

struct SettingsView: View {
    let lock: AppLockViewModel

    @AppStorage(AppSettings.biometricLockKey) private var biometricLock = false
    @State private var catalog: CatalogViewModel
    @State private var showingExport = false
    @State private var confirmingDeleteAll = false
    @State private var confirmingReset = false
    /// Shown straight after a reset, so "start over" lands on the template list
    /// rather than on an empty screen.
    @State private var showingIllnessPicker = false
    @State private var showingFirstSteps = false

    private let entries: EntryStoring

    init(lock: AppLockViewModel? = nil,
         catalog: CatalogViewModel? = nil,
         entries: EntryStoring? = nil) {
        self.lock = lock ?? AppLockViewModel()
        self.entries = entries ?? EntryStore()
        _catalog = State(initialValue: catalog ?? CatalogViewModel())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(EntryKind.allCases) { kind in
                        NavigationLink {
                            CatalogListView(kind: kind, model: catalog)
                        } label: {
                            LabeledContent {
                                Text("\(catalog.items(of: kind).count)")
                            } label: {
                                Label(kind.pluralTitle, systemImage: kind.systemImage)
                            }
                        }
                    }

                    NavigationLink {
                        IllnessPickerView(model: catalog)
                    } label: {
                        Label("Add from an illness", systemImage: "list.bullet.clipboard")
                    }
                } header: {
                    Text("What you can report")
                } footer: {
                    if catalog.isEmpty {
                        Text("Nothing configured yet. Pick an illness to get the usual treatments and symptoms in one go.")
                    }
                }

                Section {
                    Toggle(isOn: $biometricLock) {
                        Label("Require \(lock.style.displayName)", systemImage: lock.style.systemImage)
                    }
                    .disabled(!lock.authenticator.isAvailable)
                    .onChange(of: biometricLock) { _, enabled in
                        lock.settingChanged(to: enabled)
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    if lock.authenticator.isAvailable {
                        Text("The app locks when it goes to the background and asks to unlock the next time you open it.")
                    } else {
                        Text("Set a passcode on this device to use the lock.")
                    }
                }

                Section("Export") {
                    Button {
                        showingExport = true
                    } label: {
                        Label("Export to PDF", systemImage: "doc.richtext")
                    }
                }

                Section {
                    Button {
                        showingFirstSteps = true
                    } label: {
                        Label("First steps", systemImage: "sparkles")
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmingDeleteAll = true
                    } label: {
                        Label("Delete all entries", systemImage: "trash")
                    }
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Label("Reset the app", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Your data stays on this device. Storage: \(AppDatabase.status)")
                }
            }
            .navigationTitle(Text("Settings"))
            .sheet(isPresented: $showingExport) {
                ExportView()
            }
            .confirmationDialog("Delete every entry?", isPresented: $confirmingDeleteAll,
                                titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { entries.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your configured treatments and symptoms are kept. This can't be undone.")
            }
            .confirmationDialog("Start over?", isPresented: $confirmingReset,
                                titleVisibility: .visible) {
                Button("Delete everything and start over", role: .destructive) { reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes every entry and every treatment and symptom you've configured, then lets you pick an illness again. Your privacy settings are kept. This can't be undone.")
            }
            .fullScreenCover(isPresented: $showingFirstSteps) {
                FirstStepsView(finish: { showingFirstSteps = false }, catalog: catalog)
            }
            .sheet(isPresented: $showingIllnessPicker) {
                NavigationStack {
                    IllnessPickerView(model: catalog)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") { showingIllnessPicker = false }
                            }
                        }
                }
            }
        }
        .onAppear { catalog.refresh() }
    }

    /// Back to a fresh install: no entries, no catalog, and the template list open.
    /// The Face ID preference is deliberately left alone — silently unlocking the
    /// app would be the opposite of what that setting is for.
    private func reset() {
        entries.deleteAll()
        catalog.reset()
        showingIllnessPicker = true
    }
}

#Preview {
    SettingsView(lock: AppLockViewModel(authenticator: StubBiometricAuthenticator()),
                 catalog: CatalogViewModel(store: PreviewData.catalogStore()),
                 entries: PreviewData.entryStore())
}
