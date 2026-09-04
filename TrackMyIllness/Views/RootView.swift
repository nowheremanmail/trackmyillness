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
    @State private var showingFirstSteps = false
    /// Bumped when the walkthrough closes. The Report tab is behind a full-screen
    /// cover, not off screen, so it never gets a fresh onAppear to reload from —
    /// without this it stays on its empty state after First steps fills the list.
    @State private var catalogRevision = 0
    @AppStorage(AppSettings.hasSeenFirstStepsKey) private var hasSeenFirstSteps = false
    @Environment(\.scenePhase) private var scenePhase

    init(lock: AppLockViewModel? = nil) {
        _lock = State(initialValue: lock ?? AppLockViewModel())
    }

    var body: some View {
        TabView(selection: $selection) {
            LogView(openSettings: { selection = .settings }, refreshToken: catalogRevision)
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
        .fullScreenCover(isPresented: $showingFirstSteps, onDismiss: { catalogRevision += 1 }) {
            FirstStepsView {
                hasSeenFirstSteps = true
                showingFirstSteps = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            lock.handle(scenePhase: phase)
        }
        .onAppear {
            // Never over the lock screen: the walkthrough would be showing the app
            // to whoever picked the phone up.
            if !hasSeenFirstSteps, !lock.isLocked { showingFirstSteps = true }
            #if DEBUG
            if let route = ScreenshotMode.route {
                selection = switch route {
                case .report: .report
                case .history: .history
                case .settings, .close: .settings
                }
            }
            #endif
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
