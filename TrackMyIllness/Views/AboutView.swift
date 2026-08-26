//
//  AboutView.swift
//  TrackMyIllness
//
//  App info: icon, version, support/privacy links, and a developer footer.
//

import SwiftUI

struct AboutView: View {
    /// Whether the screen is on show; gates the AI shake so it only runs while visible.
    @State private var active = false

    private let supportURL = URL(string: "mailto:info@nowhereman.eu")!
    // TODO: point this at the real privacy policy page.
    private let privacyURL = URL(string: "https://nowhereman.eu/trackmyillness/privacy")!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            // App identity.
            VStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20))
                Text("TrackMyIllness")
                    .font(.title2.weight(.semibold))
                Text("Version \(version) (\(build))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Your log stays on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            Spacer()
            // Links.
            VStack(spacing: 4) {
                Link(destination: supportURL) {
                    linkRow("Support", systemImage: "envelope")
                }
                Divider().padding(.leading, 48)
                Link(destination: privacyURL) {
                    linkRow("Privacy Policy", systemImage: "lock.shield")
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.top, 40)

            // Footer, vertically centered in the space beneath the links.
            Spacer()
            VStack(spacing: 4) {
                Text("Design by")
                    .foregroundStyle(.secondary)
                Text("No Whereman")
                    .font(.callout.weight(.semibold))
                Text("Built by")
                    .foregroundStyle(.secondary)
                // phaseAnimator self-drives on insertion (reliable on iPad, unlike an
                // onAppear-toggled repeatForever). Gated by `active` so it only runs
                // while the screen is visible.
                Group {
                    if active {
                        Text("AI")
                            .font(.callout.weight(.semibold))
                            .fixedSize()
                            .phaseAnimator([-2.0, 2.0]) { view, x in
                                view.offset(x: x)
                            } animation: { _ in .easeInOut(duration: 0.09) }
                    } else {
                        Text("AI")
                            .font(.callout.weight(.semibold))
                            .fixedSize()
                    }
                }
            }
            .font(.footnote)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle(Text("About"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { active = true }
        .onDisappear { active = false }
    }

    private func linkRow(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
