//
//  IllnessTemplateTests.swift
//  TrackMyIllnessTests
//
//  The predefined illnesses are content, and content is where typos live: a
//  misspelled SF Symbol draws nothing, an unknown colour name silently turns
//  blue, and a duplicate name inside one illness would create two identical
//  chips. These check the data rather than the code that reads it.
//

import Foundation
import UIKit
import Testing
@testable import TrackMyIllness

@Suite("IllnessTemplate")
@MainActor
struct IllnessTemplateTests {
    @Test("Something to pick from, each illness identified once")
    func catalogIsWellFormed() {
        #expect(IllnessTemplate.all.count >= 5)
        let ids = IllnessTemplate.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        let names = IllnessTemplate.all.map(\.name)
        #expect(Set(names).count == names.count)
        // The generic set is the last resort, so it belongs at the end.
        #expect(IllnessTemplate.all.last?.id == IllnessTemplate.general.id)
    }

    @Test("Every illness is named, has an icon and offers both kinds",
          arguments: IllnessTemplate.all)
    func illnessIsUsable(_ illness: IllnessTemplate) {
        #expect(!illness.id.isEmpty)
        #expect(!illness.name.isEmpty)
        #expect(illness.name.trimmingCharacters(in: .whitespaces) == illness.name)
        #expect(UIImage(systemName: illness.symbolName) != nil,
                "\(illness.id): unknown symbol \(illness.symbolName)")
        // An illness with no treatments or no symptoms would leave half the app
        // empty after picking it.
        #expect(!illness.treatments.isEmpty)
        #expect(!illness.symptoms.isEmpty)
        #expect(illness.itemCount == illness.treatments.count + illness.symptoms.count)
    }

    @Test("Every item is named, drawable and validly coloured",
          arguments: IllnessTemplate.all)
    func itemsAreUsable(_ illness: IllnessTemplate) {
        for kind in EntryKind.allCases {
            for item in illness.items(of: kind) {
                #expect(!item.name.isEmpty)
                #expect(item.name.trimmingCharacters(in: .whitespaces) == item.name)
                #expect(UIImage(systemName: item.symbolName) != nil,
                        "\(illness.id)/\(item.name): unknown symbol \(item.symbolName)")
                // A typo here wouldn't fail — it would just quietly draw blue.
                #expect(ItemColor(rawValue: item.colorName) != nil,
                        "\(illness.id)/\(item.name): unknown colour \(item.colorName)")
            }
        }
    }

    @Test("No illness lists the same item twice", arguments: IllnessTemplate.all)
    func itemsAreUniqueWithinAnIllness(_ illness: IllnessTemplate) {
        for kind in EntryKind.allCases {
            let keys = illness.items(of: kind).map { $0.name.catalogMatchKey }
            #expect(Set(keys).count == keys.count, "\(illness.id): repeats a \(kind.rawValue)")
        }
    }

    @Test("Only symptoms rate severity", arguments: IllnessTemplate.all)
    func severityTrackingIsPerKind(_ illness: IllnessTemplate) {
        #expect(illness.treatments.allSatisfy { !$0.tracksSeverity })
        #expect(illness.symptoms.allSatisfy { $0.tracksSeverity })
    }

    @Test("A template item becomes a catalog item of the right kind")
    func catalogItemConversion() throws {
        let template = try #require(IllnessTemplate.migraine.symptoms.first)
        let item = template.catalogItem(kind: .symptom, sortIndex: 3)
        #expect(item.kind == .symptom)
        #expect(item.name == template.name)
        #expect(item.symbolName == template.symbolName)
        #expect(item.colorName == template.colorName)
        #expect(item.tracksSeverity)
        #expect(item.sortIndex == 3)
        #expect(item.isArchived == false)
        #expect(item.defaultDose.isEmpty)
    }

    @Test("A symptom template used as a treatment doesn't smuggle severity across")
    func severityNeverLeaksToTreatments() throws {
        let symptom = try #require(IllnessTemplate.migraine.symptoms.first)
        #expect(symptom.catalogItem(kind: .treatment, sortIndex: 0).tracksSeverity == false)
    }

    @Test("Each conversion gets its own identity, so adding twice can't collide")
    func catalogItemsGetFreshIDs() {
        let first = IllnessTemplate.migraine.catalogItems
        let second = IllnessTemplate.migraine.catalogItems
        #expect(Set(first.map(\.id)).isDisjoint(with: second.map(\.id)))
        #expect(Set(first.map(\.id)).count == first.count)
    }

    @Test("catalogItems numbers each kind from zero, in template order")
    func catalogItemsAreNumberedPerKind() {
        let illness = IllnessTemplate.migraine
        let items = illness.catalogItems
        #expect(items.count == illness.itemCount)
        for kind in EntryKind.allCases {
            let ofKind = items.filter { $0.kind == kind }
            #expect(ofKind.map(\.name) == illness.items(of: kind).map(\.name))
            #expect(ofKind.map(\.sortIndex) == Array(0..<ofKind.count))
        }
    }

    @Test("No template suggests a dose — that's between the user and their doctor",
          arguments: IllnessTemplate.all)
    func templatesNeverSuggestDoses(_ illness: IllnessTemplate) {
        #expect(illness.catalogItems.allSatisfy { $0.defaultDose.isEmpty })
    }

    @Test("The generic set is what the app used to create on first run")
    func generalMatchesTheOldStarterSet() {
        let general = IllnessTemplate.general
        #expect(general.treatments.map(\.name).count == 3)
        #expect(general.symptoms.map(\.name).count == 4)
    }
}

@Suite("Catalog match key")
struct CatalogMatchKeyTests {
    @Test("Case, accents and surrounding space don't make a different item",
          arguments: ["Nausea", "nausea", "NAUSEA", "  Nausea  ", "Náusea", "náusea\n"])
    func equivalentSpellings(_ name: String) {
        #expect(name.catalogMatchKey == "nausea")
    }

    @Test("Genuinely different names stay different")
    func differentNames() {
        #expect("Nausea".catalogMatchKey != "Neck pain".catalogMatchKey)
        #expect("Cough".catalogMatchKey != "Coughing".catalogMatchKey)
    }

    @Test("A name that's only whitespace has no key to match on")
    func blankName() {
        #expect("   ".catalogMatchKey.isEmpty)
        #expect("".catalogMatchKey.isEmpty)
    }
}
