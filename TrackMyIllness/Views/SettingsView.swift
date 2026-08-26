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
                Section("What you can report") {
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
        }
        .onAppear { catalog.refresh() }
    }
}

#Preview {
    SettingsView(lock: AppLockViewModel(authenticator: StubBiometricAuthenticator()),
                 catalog: CatalogViewModel(store: PreviewData.catalogStore()),
                 entries: PreviewData.entryStore())
}
