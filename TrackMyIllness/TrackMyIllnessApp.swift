//
//  TrackMyIllnessApp.swift
//  TrackMyIllness
//
//  App entry point. The SwiftData container is built lazily by AppDatabase.
//
//  Nothing is created on first run: the catalog starts empty and the user fills it
//  from Settings, either by picking a predefined illness or by adding items one at
//  a time. See IllnessTemplate.
//

import SwiftUI

@main
struct TrackMyIllnessApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
