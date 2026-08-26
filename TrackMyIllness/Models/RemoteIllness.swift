//
//  RemoteIllness.swift
//  TrackMyIllness
//
//  The extra illnesses published on the project wiki, so the list can grow
//  without shipping a new build.
//
//  The JSON is content, not code, and it comes from the network — so everything
//  here treats it as untrusted: names are trimmed and length-capped, unknown SF
//  Symbols and colour names fall back instead of drawing nothing, the counts are
//  bounded, and anything that doesn't resolve to a usable name is dropped rather
//  than created half-formed.
//
//  Multi-language: these names can't go through Localizable.xcstrings, because
//  they aren't in the build. The publisher supplies each name in as many
//  languages as they like and the app picks the closest to the reader — see
//  LocalizedText.
//

import Foundation
import UIKit

/// The document published at `RemoteIllnessLoader.catalogURL`.
struct RemoteIllnessCatalog: Decodable, Hashable, Sendable {
    /// Bumped by the publisher if the shape ever changes incompatibly; the app
    /// refuses versions it doesn't understand rather than guessing.
    var version: Int
    var illnesses: [RemoteIllness]

    static let supportedVersion = 1
}

struct RemoteIllness: Decodable, Hashable, Sendable {
    var id: String
    var name: LocalizedText
    var symbol: String?
    var treatments: [RemoteIllnessItem]
    var symptoms: [RemoteIllnessItem]
}

struct RemoteIllnessItem: Decodable, Hashable, Sendable {
    var name: LocalizedText
    var symbol: String?
    var color: String?
}

/// One string in every language the publisher provided, keyed by language code
/// ("en", "es", "pt-BR"). Decoded from a plain JSON object.
struct LocalizedText: Decodable, Hashable, Sendable {
    var byLanguage: [String: String]

    init(_ byLanguage: [String: String]) {
        self.byLanguage = byLanguage
    }

    init(from decoder: Decoder) throws {
        byLanguage = try decoder.singleValueContainer().decode([String: String].self)
    }

    /// The best match for the reader, trying each preferred language in turn:
    /// first the exact tag ("pt-BR"), then its base language ("pt"). Falls back to
    /// English, then to any language present, so a name the publisher only wrote
    /// once still shows up instead of vanishing.
    func resolved(preferring languages: [String] = LocalizedText.readerLanguages) -> String? {
        let candidates = languages.flatMap { tag -> [String] in
            let base = tag.split(separator: "-").first.map(String.init)
            return base.map { [tag, $0] } ?? [tag]
        } + ["en"]

        for tag in candidates {
            if let value = byLanguage.first(where: { $0.key.caseInsensitiveCompare(tag) == .orderedSame })?.value,
               !value.trimmed.isEmpty {
                return value.trimmed
            }
        }
        // Sorted so the fallback is at least deterministic between launches.
        return byLanguage.sorted { $0.key < $1.key }
            .map(\.value).first { !$0.trimmed.isEmpty }?.trimmed
    }

    /// What the reader actually reads, most preferred first: the languages they
    /// set on the device, then the one the app is running in.
    static var readerLanguages: [String] {
        Locale.preferredLanguages + Bundle.main.preferredLocalizations
    }
}

// MARK: - Turning it into something the app can use

extension RemoteIllnessCatalog {
    /// Bounds, so a malformed or hostile document can't produce an unusable
    /// screen or a catalog nobody can scroll through.
    enum Limits {
        static let illnesses = 60
        static let itemsPerKind = 40
        static let nameLength = 60
    }

    /// The illnesses this document describes, as the same templates the built-in
    /// list uses — which is what lets the existing picker, the name matching and
    /// the store handle them with no special cases.
    ///
    /// - Parameter excludedIDs: ids already offered elsewhere (the built-ins), so
    ///   the same illness can't appear twice in the app.
    func templates(excluding excludedIDs: Set<String> = []) -> [IllnessTemplate] {
        var seen = excludedIDs
        var result: [IllnessTemplate] = []

        for illness in illnesses {
            guard result.count < Limits.illnesses else { break }
            let id = illness.id.trimmed
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            guard let name = illness.name.resolved()?.capped else { continue }

            let treatments = illness.treatments.compactMap { $0.item(for: .treatment) }
            let symptoms = illness.symptoms.compactMap { $0.item(for: .symptom) }
            // Half an illness is worse than none: it would leave one tab empty
            // after the user picked it.
            guard !treatments.isEmpty, !symptoms.isEmpty else { continue }

            result.append(IllnessTemplate(
                id: id,
                name: name,
                symbolName: illness.symbol?.validSymbol ?? "cross.case.fill",
                treatments: Array(treatments.prefix(Limits.itemsPerKind)),
                symptoms: Array(symptoms.prefix(Limits.itemsPerKind))))
        }
        return result
    }
}

extension RemoteIllnessItem {
    /// nil when there's no usable name — the one field there's no sane default for.
    func item(for kind: EntryKind) -> IllnessItem? {
        guard let name = name.resolved()?.capped else { return nil }
        return IllnessItem(
            name: name,
            symbolName: symbol?.validSymbol ?? kind.systemImage,
            colorName: (color.flatMap { ItemColor(rawValue: $0.trimmed.lowercased()) } ?? .blue).rawValue,
            tracksSeverity: kind == .symptom)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// nil rather than "" so callers can drop the item in one `guard`.
    var capped: String? {
        let trimmed = self.trimmed
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(RemoteIllnessCatalog.Limits.nameLength))
    }

    /// A symbol name only counts if this device can actually draw it; otherwise
    /// the row would be a blank gap.
    var validSymbol: String? {
        let trimmed = self.trimmed
        guard !trimmed.isEmpty, UIImage(systemName: trimmed) != nil else { return nil }
        return trimmed
    }
}
