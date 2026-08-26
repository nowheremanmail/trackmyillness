//
//  Database.swift
//  TrackMyIllness
//
//  The app-wide SwiftData container holding the catalog (configurable treatments
//  and symptoms) and the reported entries. On-device only — health data never
//  leaves the phone.
//

import Foundation
import SwiftData

enum AppDatabase {
    /// Human-readable status of the store, shown in Settings for diagnostics.
    nonisolated(unsafe) static var status = "initializing…"

    nonisolated static let schema = Schema([
        CatalogItemRecord.self, LogEntryRecord.self, ClosedIllnessRecord.self,
    ])

    nonisolated static let container: ModelContainer = {
        let local = ModelConfiguration(schema: schema)
        do {
            let container = try ModelContainer(for: schema, configurations: local)
            status = "on-device"
            return container
        } catch {
            // The on-disk store failed to open (corrupt, or a schema it can't
            // migrate). Launch anyway in memory so the app isn't bricked; the disk
            // data is untouched and can be reset from Settings.
            status = "storage unavailable, running in memory: \(error.localizedDescription)"
            print("[TrackMyIllness] local container failed: \(error)")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: schema, configurations: memory) {
                return container
            }
            fatalError("Failed to create the model container: \(error)")
        }
    }()

    /// A throwaway in-memory container. Used by previews so they never touch — or
    /// depend on — the real store.
    nonisolated static func previewContainer() -> ModelContainer {
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // Previews can't recover from a failure here, and an in-memory store has
        // nothing to fail on, so this is a genuine programmer error if it throws.
        return try! ModelContainer(for: schema, configurations: memory)
    }

    /// Deletes the on-disk store. The app must be relaunched afterwards to build a
    /// fresh one. Destructive.
    nonisolated static func resetLocalStore() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                           appropriateFor: nil, create: false) else { return }
        for name in ["default.store", "default.store-wal", "default.store-shm", ".default_SUPPORT"] {
            try? fm.removeItem(at: appSupport.appendingPathComponent(name))
        }
    }
}
