//
//  AppLockViewModelTests.swift
//  TrackMyIllnessTests
//
//  The Face ID gate, driven by a stub authenticator so no test ever prompts.
//

import Foundation
import SwiftUI
import Testing
@testable import TrackMyIllness

@Suite("AppLockViewModel")
@MainActor
struct AppLockViewModelTests {
    private func makeModel(enabled: Bool,
                           style: BiometryStyle = .faceID,
                           failure: String? = nil) -> AppLockViewModel {
        AppLockViewModel(
            authenticator: StubBiometricAuthenticator(style: style, failureMessage: failure),
            isEnabled: enabled)
    }

    @Test("With the lock off the app is open from the start")
    func unlockedWhenDisabled() {
        let model = makeModel(enabled: false)
        #expect(model.isLocked == false)
        #expect(model.phase == .unlocked)
        #expect(model.isEnabled == false)
    }

    @Test("With the lock on the app starts locked, so content is never briefly visible")
    func lockedAtLaunchWhenEnabled() {
        let model = makeModel(enabled: true)
        #expect(model.isLocked)
        #expect(model.phase == .locked)
        #expect(model.errorMessage.isEmpty)
    }

    @Test("The lock screen reports what the device actually offers")
    func styleComesFromTheDevice() {
        #expect(makeModel(enabled: true, style: .touchID).style == .touchID)
        #expect(makeModel(enabled: true, style: .passcode).style == .passcode)
        #expect(makeModel(enabled: true, style: .none).style == .none)
        #expect(makeModel(enabled: true, style: .none).authenticator.isAvailable == false)
        #expect(makeModel(enabled: true, style: .faceID).authenticator.isAvailable)
    }

    @Test("A successful scan opens the app")
    func unlockSucceeds() async {
        let model = makeModel(enabled: true)
        await model.unlock()
        #expect(model.phase == .unlocked)
        #expect(model.isLocked == false)
        #expect(model.errorMessage.isEmpty)
    }

    @Test("A failed scan stays locked and says why")
    func unlockFails() async {
        let model = makeModel(enabled: true, failure: "No match.")
        await model.unlock()
        #expect(model.phase == .locked)
        #expect(model.errorMessage == "No match.")
    }

    @Test("A cancelled prompt stays locked without an error to shout about")
    func unlockCancelled() async {
        let model = makeModel(enabled: true, failure: "")
        await model.unlock()
        #expect(model.phase == .locked)
        #expect(model.errorMessage.isEmpty)
    }

    @Test("A retry after a failure clears the old message")
    func retryClearsTheError() async {
        let stub = StubBiometricAuthenticator(failureMessage: "No match.")
        let model = AppLockViewModel(authenticator: stub, isEnabled: true)
        await model.unlock()
        #expect(model.errorMessage == "No match.")
        stub.failureMessage = nil
        await model.unlock()
        #expect(model.phase == .unlocked)
        #expect(model.errorMessage.isEmpty)
    }

    @Test("With the lock off there's nothing to prompt for")
    func unlockWithoutPromptWhenDisabled() async {
        let model = makeModel(enabled: false, failure: "should never be shown")
        await model.unlock()
        #expect(model.phase == .unlocked)
        #expect(model.errorMessage.isEmpty)
    }

    @Test("Backgrounding the app re-locks it")
    func backgroundRelocks() async {
        let model = makeModel(enabled: true)
        await model.unlock()
        #expect(model.isLocked == false)
        model.handle(scenePhase: .background)
        #expect(model.phase == .locked)
    }

    @Test("Going merely inactive doesn't re-lock under the Face ID sheet",
          arguments: [ScenePhase.inactive, .active])
    func onlyBackgroundRelocks(_ phase: ScenePhase) async {
        let model = makeModel(enabled: true)
        await model.unlock()
        model.handle(scenePhase: phase)
        #expect(model.phase == .unlocked)
    }

    @Test("Backgrounding while the prompt is up doesn't cancel the attempt")
    func backgroundDuringAuthenticationIsIgnored() async {
        let stub = GatedBiometricAuthenticator()
        let model = AppLockViewModel(authenticator: stub, isEnabled: true)
        var phaseWhilePrompting: AppLockViewModel.Phase?
        stub.whilePrompting = {
            // The Face ID sheet is what backgrounded the app; re-locking here would
            // drop the lock screen under the OS's own prompt.
            model.handle(scenePhase: .background)
            phaseWhilePrompting = model.phase
        }
        await model.unlock()
        #expect(phaseWhilePrompting == .authenticating)
        #expect(model.phase == .unlocked)
    }

    @Test("With the lock off, backgrounding leaves the app open")
    func backgroundDoesNothingWhenDisabled() {
        let model = makeModel(enabled: false)
        model.handle(scenePhase: .background)
        #expect(model.phase == .unlocked)
    }

    @Test("Turning the lock on doesn't demand a scan while you're already inside")
    func enablingDoesNotPromptImmediately() {
        let model = makeModel(enabled: false)
        model.settingChanged(to: true)
        #expect(model.isEnabled)
        #expect(model.phase == .unlocked)
        // It takes effect the next time the app backgrounds.
        model.handle(scenePhase: .background)
        #expect(model.phase == .locked)
    }

    @Test("Turning the lock off opens the app immediately, error and all")
    func disablingUnlocks() async {
        let model = makeModel(enabled: true, failure: "No match.")
        await model.unlock()
        #expect(model.phase == .locked)
        model.settingChanged(to: false)
        #expect(model.isEnabled == false)
        #expect(model.phase == .unlocked)
        #expect(model.errorMessage.isEmpty)
    }

    @Test("A stale lock is cleared once the setting is off, even from the background hook")
    func disabledSettingClearsAStaleLock() {
        let model = makeModel(enabled: true)
        #expect(model.phase == .locked)
        model.settingChanged(to: false)
        model.handle(scenePhase: .background)
        #expect(model.phase == .unlocked)
    }
}
