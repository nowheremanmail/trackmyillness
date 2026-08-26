//
//  RemoteIllnessLoader.swift
//  TrackMyIllness
//
//  Downloads the extra illness list from the project wiki.
//
//  This is the only network request the app makes, and it only happens when the
//  user opens "More illnesses". It sends nothing but the request itself: no health
//  data, no identifiers, no analytics. What comes back is a static, public JSON
//  file — treated as untrusted content by RemoteIllnessCatalog.
//

import Foundation

@MainActor
protocol RemoteIllnessLoading {
    /// The extra illnesses on offer, already validated and ready to show.
    /// - Parameter excludedIDs: ids the app already offers, so nothing appears twice.
    func load(excluding excludedIDs: Set<String>) async throws -> [IllnessTemplate]
}

@MainActor
final class RemoteIllnessLoader: RemoteIllnessLoading {
    /// GitHub serves a wiki's files as plain text under this host, which is why
    /// the list lives in the wiki repository rather than in a release.
    static let catalogURL = URL(
        string: "https://raw.githubusercontent.com/wiki/nowheremanmail/trackmyillness/Illnesses.json")!

    /// Enough for hundreds of illnesses; small enough that a wrong URL serving
    /// something huge can't be read into memory.
    static let maximumBytes = 512 * 1024

    enum Failure: LocalizedError, Equatable {
        case unreachable
        case notPublished
        case unsupportedVersion
        case malformed

        var errorDescription: String? {
            switch self {
            case .unreachable:
                String(localized: "Couldn't reach the list. Check your connection and try again.")
            case .notPublished:
                String(localized: "No extra illnesses are published right now.")
            case .unsupportedVersion:
                String(localized: "This list needs a newer version of the app.")
            case .malformed:
                String(localized: "The published list couldn't be read.")
            }
        }
    }

    /// Injected so tests never touch the network.
    private let fetch: (URL) async throws -> (Data, URLResponse)

    init(fetch: ((URL) async throws -> (Data, URLResponse))? = nil) {
        self.fetch = fetch ?? { url in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 30
            // Nothing about the reader should ride along with the request.
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            return try await URLSession(configuration: configuration).data(for: request)
        }
    }

    func load(excluding excludedIDs: Set<String> = []) async throws -> [IllnessTemplate] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await fetch(Self.catalogURL)
        } catch {
            throw Failure.unreachable
        }

        if let http = response as? HTTPURLResponse {
            // 404 is the ordinary "nothing published yet" case, not a fault.
            guard http.statusCode != 404 else { throw Failure.notPublished }
            guard (200..<300).contains(http.statusCode) else { throw Failure.unreachable }
        }
        guard data.count <= Self.maximumBytes else { throw Failure.malformed }

        let catalog: RemoteIllnessCatalog
        do {
            catalog = try JSONDecoder().decode(RemoteIllnessCatalog.self, from: data)
        } catch {
            throw Failure.malformed
        }
        guard catalog.version <= RemoteIllnessCatalog.supportedVersion else {
            throw Failure.unsupportedVersion
        }

        let templates = catalog.templates(excluding: excludedIDs)
        guard !templates.isEmpty else { throw Failure.notPublished }
        return templates
    }
}

/// Preview/test double: hands back whatever it was given, or fails on demand.
@MainActor
final class StubRemoteIllnessLoader: RemoteIllnessLoading {
    var templates: [IllnessTemplate]
    var failure: Error?
    /// Ids the last call was asked to exclude, so a test can check they're passed on.
    private(set) var lastExcludedIDs: Set<String> = []

    init(templates: [IllnessTemplate] = [], failure: Error? = nil) {
        self.templates = templates
        self.failure = failure
    }

    func load(excluding excludedIDs: Set<String>) async throws -> [IllnessTemplate] {
        lastExcludedIDs = excludedIDs
        if let failure { throw failure }
        return templates
    }
}
