//
//  RootView.swift
//  TrackMyIllness
//
//  Top-level tab bar (Report, History, Settings) wrapped in the Face ID gate.
//

import SwiftUI

struct RootView: View {
    private enum Tab: Hashable { case report, history, settings }

    @State private var selection: Tab = .report
    @State private var lock: AppLockViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(lock: AppLockViewModel? = nil) {
        _lock = State(initialValue: lock ?? AppLockViewModel())
    }

    var body: some View {
        TabView(selection: $selection) {
            LogView(openSettings: { selection = .settings })
                .tabItem { Label("Report", systemImage: "plus.circle.fill") }
                .tag(Tab.report)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            SettingsView(lock: lock)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        // Hide the log from the app switcher's snapshot while locked.
        .redacted(reason: lock.isLocked ? .privacy : [])
        .overlay {
            if lock.isLocked {
                LockView(model: lock)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
        .onChange(of: scenePhase) { _, phase in
            lock.handle(scenePhase: phase)
        }
    }
}

#Preview("Unlocked") {
    RootView()
}

#Preview("Locked") {
    // The lock screen sits over the tabs until Face ID succeeds.
    RootView(lock: AppLockViewModel(
        authenticator: StubBiometricAuthenticator(failureMessage: "Face ID doesn't recognise you."),
        isEnabled: true))
}
