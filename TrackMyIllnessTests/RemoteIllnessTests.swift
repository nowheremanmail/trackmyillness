//
//  RemoteIllnessTests.swift
//  TrackMyIllnessTests
//
//  The downloaded illness list. This content arrives over the network from a file
//  anyone could edit, so most of these are about what happens when it's wrong:
//  missing translations, unknown symbols, bad colours, absurd counts, half-formed
//  illnesses. None of it should be able to produce a broken screen.
//

import Foundation
import UIKit
import Testing
@testable import TrackMyIllness

@Suite("LocalizedText")
@MainActor
struct LocalizedTextTests {
    private let text = LocalizedText(["en": "Hypothyroidism", "es": "Hipotiroidismo",
                                      "pt-BR": "Hipotireoidismo"])

    @Test("An exact language tag wins")
    func exactTag() {
        #expect(text.resolved(preferring: ["pt-BR"]) == "Hipotireoidismo")
        #expect(text.resolved(preferring: ["es"]) == "Hipotiroidismo")
    }

    @Test("A regional tag falls back to its base language")
    func regionFallsBackToBase() {
        // The publisher wrote "es", the reader asked for "es-MX".
        #expect(text.resolved(preferring: ["es-MX"]) == "Hipotiroidismo")
    }

    @Test("Language matching ignores case, so \"ES\" and \"es\" are the same language")
    func caseInsensitive() {
        #expect(text.resolved(preferring: ["ES"]) == "Hipotiroidismo")
    }

    @Test("Preferences are tried in order")
    func ordered() {
        #expect(text.resolved(preferring: ["fr", "es", "en"]) == "Hipotiroidismo")
        #expect(text.resolved(preferring: ["fr", "en", "es"]) == "Hypothyroidism")
    }

    @Test("An unknown language falls back to English")
    func fallsBackToEnglish() {
        #expect(text.resolved(preferring: ["ja", "ko"]) == "Hypothyroidism")
    }

    @Test("With no English either, any language beats showing nothing")
    func fallsBackToAnything() {
        let onlySpanish = LocalizedText(["es": "Hipotiroidismo"])
        #expect(onlySpanish.resolved(preferring: ["ja"]) == "Hipotiroidismo")
    }

    @Test("The last-resort fallback is deterministic, not whatever the dictionary offers")
    func fallbackIsStable() {
        let text = LocalizedText(["fr": "Zebre", "de": "Aal", "it": "Mela"])
        let picks = (0..<20).map { _ in text.resolved(preferring: ["ja"]) }
        #expect(Set(picks).count == 1)
        #expect(picks.first == "Aal")   // "de" sorts first
    }

    @Test("Blank and whitespace-only values are skipped, not shown as an empty row")
    func blanksAreSkipped() {
        let text = LocalizedText(["es": "   ", "en": "Hypothyroidism"])
        #expect(text.resolved(preferring: ["es"]) == "Hypothyroidism")
    }

    @Test("Nothing usable at all resolves to nil")
    func nothingUsable() {
        #expect(LocalizedText([:]).resolved(preferring: ["en"]) == nil)
        #expect(LocalizedText(["en": "  \n "]).resolved(preferring: ["en"]) == nil)
    }

    @Test("Resolved names are trimmed")
    func trimsWhitespace() {
        #expect(LocalizedText(["en": "  Fatigue \n"]).resolved(preferring: ["en"]) == "Fatigue")
    }

    @Test("Decodes from a plain JSON object")
    func decodes() throws {
        let json = Data(#"{"en":"Fatigue","es":"Cansancio"}"#.utf8)
        let decoded = try JSONDecoder().decode(LocalizedText.self, from: json)
        #expect(decoded.byLanguage == ["en": "Fatigue", "es": "Cansancio"])
    }
}

@Suite("RemoteIllnessCatalog")
@MainActor
struct RemoteIllnessCatalogTests {
    private func catalog(_ json: String) throws -> RemoteIllnessCatalog {
        try JSONDecoder().decode(RemoteIllnessCatalog.self, from: Data(json.utf8))
    }

    private let valid = """
    {"version":1,"illnesses":[{
      "id":"hypothyroidism","symbol":"cross.vial.fill",
      "name":{"en":"Hypothyroidism","es":"Hipotiroidismo"},
      "treatments":[{"name":{"en":"Thyroid medication"},"symbol":"pill.fill","color":"teal"}],
      "symptoms":[{"name":{"en":"Fatigue"},"symbol":"zzz","color":"purple"}]
    }]}
    """

    @Test("A well-formed document becomes a usable template")
    func decodesAndConverts() throws {
        let templates = try catalog(valid).templates()
        #expect(templates.count == 1)
        let illness = try #require(templates.first)
        #expect(illness.id == "hypothyroidism")
        #expect(illness.symbolName == "cross.vial.fill")
        #expect(illness.treatments.map(\.name) == ["Thyroid medication"])
        #expect(illness.symptoms.map(\.name) == ["Fatigue"])
        #expect(illness.treatments.allSatisfy { !$0.tracksSeverity })
        #expect(illness.symptoms.allSatisfy { $0.tracksSeverity })
        #expect(illness.treatments.first?.colorName == ItemColor.teal.rawValue)
    }

    @Test("A downloaded template creates catalog items like any built-in one")
    func behavesLikeABuiltInTemplate() throws {
        let illness = try #require(try catalog(valid).templates().first)
        let store = CatalogStore(container: Fixture.container())
        #expect(store.add(illness) == illness.itemCount)
        #expect(store.items(of: .symptom).first?.tracksSeverity == true)
        #expect(store.items(of: .treatment).first?.defaultDose.isEmpty == true)
        // And picking it twice still creates nothing the second time.
        #expect(store.add(illness) == 0)
    }

    @Test("Ids the app already offers are skipped, so nothing is listed twice")
    func excludesKnownIDs() throws {
        let templates = try catalog(valid).templates(excluding: ["hypothyroidism"])
        #expect(templates.isEmpty)
    }

    @Test("A built-in id republished remotely can't shadow the built-in")
    func cannotCollideWithBuiltIns() throws {
        let json = valid.replacingOccurrences(of: "hypothyroidism", with: "migraine")
        let templates = try catalog(json).templates(
            excluding: Set(IllnessTemplate.all.map(\.id)))
        #expect(templates.isEmpty)
    }

    @Test("The same id twice in one document is only taken once")
    func deduplicatesIDs() throws {
        let json = """
        {"version":1,"illnesses":[
          {"id":"x","name":{"en":"First"},
           "treatments":[{"name":{"en":"T"}}],"symptoms":[{"name":{"en":"S"}}]},
          {"id":"x","name":{"en":"Second"},
           "treatments":[{"name":{"en":"T"}}],"symptoms":[{"name":{"en":"S"}}]}
        ]}
        """
        // The first one wins, so the list can't shift under a reader on reload.
        #expect(try catalog(json).templates().map(\.name) == ["First"])
    }

    @Test("An unknown SF Symbol falls back instead of drawing a blank gap")
    func unknownSymbolFallsBack() throws {
        let json = valid
            .replacingOccurrences(of: "\"symbol\":\"pill.fill\"", with: "\"symbol\":\"not.a.symbol\"")
            .replacingOccurrences(of: "\"symbol\":\"cross.vial.fill\"", with: "\"symbol\":\"nope\"")
        let illness = try #require(try catalog(json).templates().first)
        #expect(illness.symbolName == "cross.case.fill")
        #expect(illness.treatments.first?.symbolName == EntryKind.treatment.systemImage)
        // Whatever it fell back to has to be drawable, or the fallback is pointless.
        #expect(UIImage(systemName: illness.symbolName) != nil)
    }

    @Test("A missing symbol uses the default for its kind")
    func missingSymbolUsesKindDefault() throws {
        let json = """
        {"version":1,"illnesses":[{"id":"x","name":{"en":"X"},
          "treatments":[{"name":{"en":"T"}}],"symptoms":[{"name":{"en":"S"}}]}]}
        """
        let illness = try #require(try catalog(json).templates().first)
        #expect(illness.treatments.first?.symbolName == EntryKind.treatment.systemImage)
        #expect(illness.symptoms.first?.symbolName == EntryKind.symptom.systemImage)
    }

    @Test("An unknown colour name falls back to a real one",
          arguments: ["chartreuse", "", "#ff0000", "Blue "])
    func unknownColourFallsBack(_ colour: String) throws {
        let json = valid.replacingOccurrences(of: "\"color\":\"teal\"",
                                              with: "\"color\":\"\(colour)\"")
        let illness = try #require(try catalog(json).templates().first)
        let name = try #require(illness.treatments.first?.colorName)
        #expect(ItemColor(rawValue: name) != nil)
    }

    @Test("A colour name in the wrong case still resolves")
    func colourIsCaseInsensitive() throws {
        let json = valid.replacingOccurrences(of: "\"color\":\"teal\"",
                                              with: "\"color\":\" TEAL \"")
        let illness = try #require(try catalog(json).templates().first)
        #expect(illness.treatments.first?.colorName == ItemColor.teal.rawValue)
    }

    @Test("An illness with no treatments or no symptoms is dropped, not half-created")
    func halfAnIllnessIsDropped() throws {
        let noSymptoms = """
        {"version":1,"illnesses":[{"id":"x","name":{"en":"X"},
          "treatments":[{"name":{"en":"T"}}],"symptoms":[]}]}
        """
        let noTreatments = """
        {"version":1,"illnesses":[{"id":"x","name":{"en":"X"},
          "treatments":[],"symptoms":[{"name":{"en":"S"}}]}]}
        """
        #expect(try catalog(noSymptoms).templates().isEmpty)
        #expect(try catalog(noTreatments).templates().isEmpty)
    }

    @Test("An illness with no readable name is dropped")
    func namelessIllnessIsDropped() throws {
        let json = """
        {"version":1,"illnesses":[{"id":"x","name":{},
          "treatments":[{"name":{"en":"T"}}],"symptoms":[{"name":{"en":"S"}}]}]}
        """
        #expect(try catalog(json).templates().isEmpty)
    }

    @Test("An illness with a blank id is dropped")
    func blankIDIsDropped() throws {
        let json = """
        {"version":1,"illnesses":[{"id":"  ","name":{"en":"X"},
          "treatments":[{"name":{"en":"T"}}],"symptoms":[{"name":{"en":"S"}}]}]}
        """
        #expect(try catalog(json).templates().isEmpty)
    }

    @Test("A nameless item is dropped while the rest of the illness survives")
    func namelessItemIsDropped() throws {
        let json = """
        {"version":1,"illnesses":[{"id":"x","name":{"en":"X"},
          "treatments":[{"name":{"en":"Keep"}},{"name":{"en":"  "}}],
          "symptoms":[{"name":{"en":"S"}}]}]}
        """
        let illness = try #require(try catalog(json).templates().first)
        #expect(illness.treatments.map(\.name) == ["Keep"])
    }

    @Test("An absurdly long name is capped rather than breaking the row")
    func longNameIsCapped() throws {
        let long = String(repeating: "a", count: 500)
        let json = valid.replacingOccurrences(of: "Thyroid medication", with: long)
        let illness = try #require(try catalog(json).templates().first)
        let name = try #require(illness.treatments.first?.name)
        #expect(name.count == RemoteIllnessCatalog.Limits.nameLength)
    }

    @Test("A document with thousands of illnesses is bounded")
    func illnessCountIsBounded() throws {
        let one = { (i: Int) in
            """
            {"id":"i\(i)","name":{"en":"I\(i)"},
             "treatments":[{"name":{"en":"T"}}],"symptoms":[{"name":{"en":"S"}}]}
            """
        }
        let json = "{\"version\":1,\"illnesses\":["
            + (0..<500).map(one).joined(separator: ",") + "]}"
        #expect(try catalog(json).templates().count == RemoteIllnessCatalog.Limits.illnesses)
    }

    @Test("An illness with hundreds of items is bounded per kind")
    func itemCountIsBounded() throws {
        let items = (0..<200).map { "{\"name\":{\"en\":\"n\($0)\"}}" }.joined(separator: ",")
        let json = """
        {"version":1,"illnesses":[{"id":"x","name":{"en":"X"},
          "treatments":[\(items)],"symptoms":[\(items)]}]}
        """
        let illness = try #require(try catalog(json).templates().first)
        #expect(illness.treatments.count == RemoteIllnessCatalog.Limits.itemsPerKind)
        #expect(illness.symptoms.count == RemoteIllnessCatalog.Limits.itemsPerKind)
    }

    @Test("Names come back in the reader's language")
    func namesFollowTheReader() throws {
        let illness = try #require(try catalog(valid).illnesses.first)
        #expect(illness.name.resolved(preferring: ["es"]) == "Hipotiroidismo")
        #expect(illness.name.resolved(preferring: ["en"]) == "Hypothyroidism")
    }
}

@Suite("RemoteIllnessLoader")
@MainActor
struct RemoteIllnessLoaderTests {
    private let valid = Data("""
    {"version":1,"illnesses":[{"id":"x","name":{"en":"X"},
      "treatments":[{"name":{"en":"T"}}],"symptoms":[{"name":{"en":"S"}}]}]}
    """.utf8)

    private func response(_ status: Int) -> URLResponse {
        HTTPURLResponse(url: RemoteIllnessLoader.catalogURL, statusCode: status,
                        httpVersion: nil, headerFields: nil)!
    }

    private func loader(_ result: @escaping (URL) async throws -> (Data, URLResponse))
        -> RemoteIllnessLoader {
        RemoteIllnessLoader(fetch: result)
    }

    @Test("A good response yields templates")
    func loadsSuccessfully() async throws {
        let loader = loader { [valid, response] _ in (valid, response(200)) }
        let templates = try await loader.load(excluding: [])
        #expect(templates.map(\.name) == ["X"])
    }

    @Test("It asks for the file published on the wiki")
    func requestsTheWikiURL() async throws {
        var requested: URL?
        let loader = loader { [valid, response] url in
            requested = url
            return (valid, response(200))
        }
        _ = try await loader.load(excluding: [])
        #expect(requested == RemoteIllnessLoader.catalogURL)
        #expect(requested?.host() == "raw.githubusercontent.com")
        #expect(requested?.scheme == "https")
    }

    @Test("Excluded ids are honoured, and an empty result reads as nothing published")
    func excludesAndReportsEmpty() async {
        let loader = loader { [valid, response] _ in (valid, response(200)) }
        await #expect(throws: RemoteIllnessLoader.Failure.notPublished) {
            try await loader.load(excluding: ["x"])
        }
    }

    @Test("A missing file is \"nothing published\", not a failure to shout about")
    func missingFile() async {
        let loader = loader { [response] _ in (Data(), response(404)) }
        await #expect(throws: RemoteIllnessLoader.Failure.notPublished) {
            try await loader.load(excluding: [])
        }
    }

    @Test("A server error is reported as unreachable", arguments: [500, 403, 301])
    func serverError(_ status: Int) async {
        let loader = loader { [valid, response] _ in (valid, response(status)) }
        await #expect(throws: RemoteIllnessLoader.Failure.unreachable) {
            try await loader.load(excluding: [])
        }
    }

    @Test("A transport error is reported as unreachable")
    func transportError() async {
        let loader = loader { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: RemoteIllnessLoader.Failure.unreachable) {
            try await loader.load(excluding: [])
        }
    }

    @Test("Junk that isn't JSON is reported as malformed")
    func notJSON() async {
        let loader = loader { [response] _ in (Data("<html>nope</html>".utf8), response(200)) }
        await #expect(throws: RemoteIllnessLoader.Failure.malformed) {
            try await loader.load(excluding: [])
        }
    }

    @Test("A future format is refused rather than half-read")
    func futureVersion() async {
        let json = Data("{\"version\":99,\"illnesses\":[]}".utf8)
        let loader = loader { [response] _ in (json, response(200)) }
        await #expect(throws: RemoteIllnessLoader.Failure.unsupportedVersion) {
            try await loader.load(excluding: [])
        }
    }

    @Test("An oversized payload is refused instead of being read into memory")
    func oversizedPayload() async {
        let huge = Data(repeating: 0x20, count: RemoteIllnessLoader.maximumBytes + 1)
        let loader = loader { [response] _ in (huge, response(200)) }
        await #expect(throws: RemoteIllnessLoader.Failure.malformed) {
            try await loader.load(excluding: [])
        }
    }

    @Test("Every failure has something a person can read")
    func failuresAreLegible() {
        for failure: RemoteIllnessLoader.Failure in [.unreachable, .notPublished,
                                                     .unsupportedVersion, .malformed] {
            #expect(failure.errorDescription?.isEmpty == false)
            #expect(failure.localizedDescription.isEmpty == false)
        }
    }
}

@Suite("RemoteIllnessViewModel")
@MainActor
struct RemoteIllnessViewModelTests {
    private let sample = IllnessTemplate(
        id: "x", name: "X", symbolName: "cross.case.fill",
        treatments: [IllnessItem(name: "T", symbolName: "pills.fill",
                                 colorName: ItemColor.teal.rawValue, tracksSeverity: false)],
        symptoms: [IllnessItem(name: "S", symbolName: "bolt.fill",
                               colorName: ItemColor.red.rawValue, tracksSeverity: true)])

    @Test("It starts with nothing loaded and nothing in flight")
    func initialState() {
        let model = RemoteIllnessViewModel(loader: StubRemoteIllnessLoader())
        #expect(model.phase == .idle)
        #expect(model.illnesses.isEmpty)
        #expect(model.isLoading == false)
        #expect(model.errorMessage == nil)
    }

    @Test("A successful load exposes the illnesses")
    func loads() async {
        let model = RemoteIllnessViewModel(
            loader: StubRemoteIllnessLoader(templates: [sample]))
        await model.load()
        #expect(model.illnesses.map(\.name) == ["X"])
        #expect(model.isLoading == false)
        #expect(model.errorMessage == nil)
    }

    @Test("The built-in illnesses are excluded from the request")
    func excludesBuiltIns() async {
        let stub = StubRemoteIllnessLoader(templates: [sample])
        await RemoteIllnessViewModel(loader: stub).load()
        #expect(stub.lastExcludedIDs == Set(IllnessTemplate.all.map(\.id)))
        #expect(stub.lastExcludedIDs.contains("migraine"))
    }

    @Test("A failure surfaces a readable message and no illnesses")
    func failureMessage() async {
        let model = RemoteIllnessViewModel(loader: StubRemoteIllnessLoader(
            failure: RemoteIllnessLoader.Failure.notPublished))
        await model.load()
        #expect(model.illnesses.isEmpty)
        #expect(model.errorMessage == RemoteIllnessLoader.Failure.notPublished.localizedDescription)
    }

    @Test("Retrying after a failure replaces the message with the result")
    func retryAfterFailure() async {
        let stub = StubRemoteIllnessLoader(failure: RemoteIllnessLoader.Failure.unreachable)
        let model = RemoteIllnessViewModel(loader: stub)
        await model.load()
        #expect(model.errorMessage != nil)

        stub.failure = nil
        stub.templates = [sample]
        await model.load()
        #expect(model.errorMessage == nil)
        #expect(model.illnesses.count == 1)
    }

    @Test("Reappearing doesn't refetch what's already shown")
    func loadIfNeededIsIdempotent() async {
        final class CountingLoader: RemoteIllnessLoading {
            var calls = 0
            let templates: [IllnessTemplate]
            init(templates: [IllnessTemplate]) { self.templates = templates }
            func load(excluding excludedIDs: Set<String>) async throws -> [IllnessTemplate] {
                calls += 1
                return templates
            }
        }
        let loader = CountingLoader(templates: [sample])
        let model = RemoteIllnessViewModel(loader: loader)
        await model.loadIfNeeded()
        await model.loadIfNeeded()
        #expect(loader.calls == 1)

        // But an explicit pull-to-refresh does go again.
        await model.load()
        #expect(loader.calls == 2)
    }

    @Test("Reappearing after a failure does try again")
    func loadIfNeededRetriesAfterFailure() async {
        let stub = StubRemoteIllnessLoader(failure: RemoteIllnessLoader.Failure.unreachable)
        let model = RemoteIllnessViewModel(loader: stub)
        await model.loadIfNeeded()
        stub.failure = nil
        stub.templates = [sample]
        await model.loadIfNeeded()
        #expect(model.illnesses.count == 1)
    }
}
