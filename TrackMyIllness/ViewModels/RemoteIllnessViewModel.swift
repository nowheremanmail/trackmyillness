//
//  RemoteIllnessViewModel.swift
//  TrackMyIllness
//
//  Backs the "More illnesses" screen: fetch the published list once the screen
//  appears, and hold whatever came back.
//

import Foundation
import Observation

@MainActor
@Observable
final class RemoteIllnessViewModel {
    enum Phase: Equatable, Sendable {
        case idle
        case loading
        case loaded([IllnessTemplate])
        /// Already localized and ready to show.
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    private let loader: RemoteIllnessLoading

    init(loader: RemoteIllnessLoading? = nil) {
        self.loader = loader ?? RemoteIllnessLoader()
    }

    var illnesses: [IllnessTemplate] {
        if case .loaded(let illnesses) = phase { return illnesses }
        return []
    }

    var isLoading: Bool { phase == .loading }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    /// Loads the list, skipping the illnesses the app already ships so the same
    /// one can't show up in both places. Re-entrant calls are ignored, so the
    /// screen reappearing mid-flight doesn't start a second request.
    func load() async {
        guard phase != .loading else { return }
        phase = .loading
        do {
            let illnesses = try await loader.load(
                excluding: Set(IllnessTemplate.all.map(\.id)))
            phase = .loaded(illnesses)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Called by "Try again", and on first appearance. Loading only when there's
    /// nothing to show keeps a pop back to this screen from refetching.
    func loadIfNeeded() async {
        guard illnesses.isEmpty else { return }
        await load()
    }
}
