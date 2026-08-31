//
//  PurposeStringTests.swift
//  TrackMyIllnessTests
//
//  Guards the Info.plist purpose strings.
//
//  Version 1.0 was rejected by App Review because en.lproj/InfoPlist.strings held
//  `NSFaceIDUsageDescription = "NSFaceIDUsageDescription"`: the string catalog had
//  a translation for all six other languages but none for the source language, and
//  the compiler emits the key as its own value in that case. A .lproj overrides the
//  base Info.plist, so the one language Apple reviews in was the one that broke.
//
//  These tests read the built bundle, not the catalog, so they fail on whatever
//  actually ships.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("Info.plist purpose strings")
struct PurposeStringTests {
    /// Every key iOS treats as a permission prompt.
    private var usageKeys: [String] {
        (Bundle.main.infoDictionary ?? [:]).keys
            .filter { $0.hasSuffix("UsageDescription") }
            .sorted()
    }

    /// Long enough that "Face ID" or "Camera access" alone can't pass.
    private static let minimumLength = 30

    @Test("The app declares the purpose strings it needs")
    func declaresFaceID() {
        // The app locks with LocalAuthentication, so this one is mandatory.
        #expect(usageKeys.contains("NSFaceIDUsageDescription"))
    }

    @Test("The base Info.plist carries real text for every purpose string")
    func baseValuesAreReal() {
        for key in usageKeys {
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
            #expect(value != key, "\(key) in the base Info.plist is its own key name")
            #expect(value.count >= Self.minimumLength,
                    "\(key) in the base Info.plist is too short to describe anything: \(value)")
        }
    }

    @Test("Every shipped localization carries real text, not the key name")
    func everyLocalizationIsReal() throws {
        let localizations = Bundle.main.localizations.filter { $0 != "Base" }
        #expect(!localizations.isEmpty)

        for language in localizations {
            guard let path = Bundle.main.path(forResource: "InfoPlist", ofType: "strings",
                                              inDirectory: nil, forLocalization: language),
                  let strings = NSDictionary(contentsOfFile: path) as? [String: String]
            else {
                // No InfoPlist.strings for this language is fine: it falls back to
                // the base Info.plist, which the test above already checked.
                continue
            }
            for key in usageKeys {
                guard let value = strings[key] else { continue }
                // Concatenation would make this a String; a test comment has to be
                // a single literal.
                #expect(value != key,
                        "\(language).lproj ships \(key) as its own key name, the defect App Review rejected 1.0 for")
                #expect(value.count >= Self.minimumLength,
                        "\(language).lproj has a \(key) too short to describe anything: \(value)")
            }
        }
    }

    @Test("The source language is one of the shipped localizations")
    func sourceLanguageShips() {
        // The catalog's source language had no entry of its own, which is how the
        // placeholder got in. If en ever stops shipping, that assumption changed.
        #expect(Bundle.main.localizations.contains("en"))
    }
}
