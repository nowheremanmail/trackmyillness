//
//  AppLockViewModel.swift
//  TrackMyIllness
//
//  The Face ID gate. Off by default: when the setting is on, the app locks at
//  launch and whenever it goes to the background.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppLockViewModel {
    enum Phase: Sendable { case unlocked, locked, authenticating }

    private(set) var phase: Phase = .unlocked
    /// Empty means "the user cancelled" — no error worth showing.
    private(set) var errorMessage: String = ""

    let authenticator: BiometricAuthenticating

    /// Mirrors the Settings toggle. Kept in step by `settingChanged(to:)`, which
    /// the toggle calls after writing the preference.
    private(set) var isEnabled: Bool

    var style: BiometryStyle { authenticator.style }
    var isLocked: Bool { phase != .unlocked }

    init(authenticator: BiometricAuthenticating? = nil, isEnabled: Bool? = nil) {
        self.authenticator = authenticator ?? BiometricAuthenticator()
        let isEnabled = isEnabled ?? UserDefaults.standard.bool(forKey: AppSettings.biometricLockKey)
        self.isEnabled = isEnabled
        // Start locked when the setting is on, so the content is never briefly
        // visible before the prompt appears.
        phase = isEnabled ? .locked : .unlocked
    }

    /// Prompts for Face ID / Touch ID / passcode.
    func unlock() async {
        guard phase != .authenticating else { return }
        guard isEnabled else { return unlockWithoutPrompt() }
        phase = .authenticating
        errorMessage = ""
        let failure = await authenticator.authenticate(
            reason: String(localized: "Unlock your health log."))
        if let failure {
            errorMessage = failure
            phase = .locked
        } else {
            phase = .unlocked
        }
    }

    /// Called when the setting is switched off — nothing left to protect.
    func unlockWithoutPrompt() {
        errorMessage = ""
        phase = .unlocked
    }

    /// Re-locks when the app leaves the screen. Only `.background` counts:
    /// `.inactive` also fires while the Face ID sheet is up, which would otherwise
    /// re-lock the app underneath its own prompt.
    func handle(scenePhase: ScenePhase) {
        guard isEnabled else {
            if phase != .unlocked { unlockWithoutPrompt() }
            return
        }
        if scenePhase == .background, phase != .authenticating {
            phase = .locked
            errorMessage = ""
        }
    }

    /// Applies a change to the Settings toggle immediately.
    func settingChanged(to enabled: Bool) {
        isEnabled = enabled
        if enabled {
            // Already inside the app, so don't demand a scan right now — the lock
            // takes effect the next time it backgrounds or relaunches.
            phase = .unlocked
        } else {
            unlockWithoutPrompt()
        }
    }
}
