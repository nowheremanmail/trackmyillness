//
//  LockView.swift
//  TrackMyIllness
//
//  The Face ID / Touch ID gate shown over the app while it's locked.
//

import SwiftUI

struct LockView: View {
    @Bindable var model: AppLockViewModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: model.style.systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, isActive: model.phase == .authenticating)

                VStack(spacing: 6) {
                    Text("Locked")
                        .font(.title2.weight(.semibold))
                    Text("Unlock with \(model.style.displayName) to see your log.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !model.errorMessage.isEmpty {
                    Text(model.errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await model.unlock() }
                } label: {
                    Label("Unlock", systemImage: model.style.systemImage)
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.phase == .authenticating)
            }
            .padding(32)
        }
        // Prompt as soon as the gate appears, so the usual case is zero taps.
        .task { await model.unlock() }
    }
}

#Preview {
    LockView(model: AppLockViewModel(authenticator: StubBiometricAuthenticator(), isEnabled: true))
}

#Preview("Failed") {
    LockView(model: AppLockViewModel(
        authenticator: StubBiometricAuthenticator(failureMessage: "Face ID doesn't recognise you."),
        isEnabled: true))
}
