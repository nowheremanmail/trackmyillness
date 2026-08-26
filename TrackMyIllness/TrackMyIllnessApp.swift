//
//  TrackMyIllnessApp.swift
//  TrackMyIllness
//
//  App entry point. The SwiftData container is built lazily by AppDatabase; the
//  starter catalog is seeded here so the Report tab is never empty on first run.
//

import SwiftUI

@main
struct TrackMyIllnessApp: App {
    init() {
        CatalogStore().seedDefaultsIfEmpty()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
