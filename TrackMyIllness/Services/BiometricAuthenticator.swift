//
//  BiometricAuthenticator.swift
//  TrackMyIllness
//
//  Face ID / Touch ID unlock. Behind a protocol so the lock screen can be driven
//  by a stub in previews (where LocalAuthentication always fails).
//

import Foundation
import LocalAuthentication

enum BiometryStyle: Sendable {
    case faceID
    case touchID
    /// The device has no biometrics — the passcode sheet is used instead.
    case passcode
    /// Nothing is set up: no biometrics and no passcode, so the app can't lock.
    case none

    var displayName: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .passcode: String(localized: "Passcode")
        case .none: String(localized: "Not available")
        }
    }

    var systemImage: String {
        switch self {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .passcode, .none: "lock.fill"
        }
    }
}

@MainActor
protocol BiometricAuthenticating {
    /// What the device offers. `.none` means the lock can't be turned on.
    var style: BiometryStyle { get }
    /// Prompts the user. Returns nil on success, or a message to show on failure.
    func authenticate(reason: String) async -> String?
}

extension BiometricAuthenticating {
    var isAvailable: Bool { style != .none }
}

@MainActor
final class BiometricAuthenticator: BiometricAuthenticating {
    var style: BiometryStyle {
        let context = LAContext()
        var error: NSError?
        // Device-owner authentication (biometrics *or* passcode) — so a failed or
        // unavailable Face ID scan never locks the user out of their own data.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return .none }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .passcode
        }
    }

    func authenticate(reason: String) async -> String? {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return ok ? nil : String(localized: "Authentication failed.")
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel
                    || error.code == .systemCancel {
            // The user dismissed the prompt: stay locked, but don't shout about it.
            return ""
        } catch {
            return error.localizedDescription
        }
    }
}

/// Preview/test double: reports a Face ID device and succeeds or fails on demand.
@MainActor
final class StubBiometricAuthenticator: BiometricAuthenticating {
    var style: BiometryStyle
    var failureMessage: String?

    init(style: BiometryStyle = .faceID, failureMessage: String? = nil) {
        self.style = style
        self.failureMessage = failureMessage
    }

    func authenticate(reason: String) async -> String? { failureMessage }
}
