//
//  CatalogStoreTests.swift
//  TrackMyIllnessTests
//
//  The catalog store against a throwaway in-memory container.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("CatalogStore")
@MainActor
struct CatalogStoreTests {
    private let store = CatalogStore(container: Fixture.container())

    @Test("A new store is empty")
    func startsEmpty() {
        #expect(store.items(of: .treatment).isEmpty)
        #expect(store.items(of: .symptom).isEmpty)
    }

    @Test("Saving an item makes it readable by kind and by id")
    func saveAndRead() {
        let item = Fixture.item(name: "Painkiller", defaultDose: "500 mg")
        store.save(item)
        #expect(store.items(of: .treatment).map(\.name) == ["Painkiller"])
        #expect(store.item(id: item.id)?.defaultDose == "500 mg")
        // Kinds are separate lists.
        #expect(store.items(of: .symptom).isEmpty)
    }

    @Test("Saving an existing id updates that item instead of adding a second one")
    func saveUpdatesInPlace() {
        var item = Fixture.item(name: "Painkiller")
        store.save(item)
        item.name = "Ibuprofen"
        item.defaultDose = "400 mg"
        store.save(item)
        let items = store.items(of: .treatment)
        #expect(items.count == 1)
        #expect(items.first?.name == "Ibuprofen")
        #expect(items.first?.defaultDose == "400 mg")
    }

    @Test("An unknown id reads as nil rather than a blank item")
    func unknownIDIsNil() {
        #expect(store.item(id: "nope") == nil)
    }

    @Test("Items come back in sortIndex order, whatever order they were saved in")
    func sortedBySortIndex() {
        store.save(Fixture.item(name: "Third", sortIndex: 2))
        store.save(Fixture.item(name: "First", sortIndex: 0))
        store.save(Fixture.item(name: "Second", sortIndex: 1))
        #expect(store.items(of: .treatment).map(\.name) == ["First", "Second", "Third"])
    }

    @Test("Archived items are hidden from the entry form but still fetchable")
    func archivedAreFilteredUnlessAskedFor() {
        store.save(Fixture.item(name: "Current", sortIndex: 0))
        store.save(Fixture.item(name: "Retired", isArchived: true, sortIndex: 1))
        #expect(store.items(of: .treatment).map(\.name) == ["Current"])
        #expect(store.items(of: .treatment, includeArchived: true).map(\.name)
            == ["Current", "Retired"])
    }

    @Test("Deleting removes the item; deleting an unknown id changes nothing")
    func delete() {
        let item = Fixture.item(name: "Painkiller")
        store.save(item)
        store.delete(id: "not-a-real-id")
        #expect(store.items(of: .treatment).count == 1)
        store.delete(id: item.id)
        #expect(store.items(of: .treatment).isEmpty)
        #expect(store.item(id: item.id) == nil)
    }

    @Test("Reordering rewrites sortIndex so the new order is what comes back")
    func reorderPersists() {
        let a = Fixture.item(name: "A", sortIndex: 0)
        let b = Fixture.item(name: "B", sortIndex: 1)
        let c = Fixture.item(name: "C", sortIndex: 2)
        for item in [a, b, c] { store.save(item) }
        store.reorder([c, a, b])
        #expect(store.items(of: .treatment).map(\.name) == ["C", "A", "B"])
        #expect(store.item(id: c.id)?.sortIndex == 0)
        #expect(store.item(id: b.id)?.sortIndex == 2)
    }

    // MARK: Predefined illnesses

    @Test("Adding an illness creates all of its treatments and symptoms")
    func addIllnessCreatesItems() {
        let illness = IllnessTemplate.migraine
        let added = store.add(illness)
        #expect(added == illness.itemCount)
        #expect(store.items(of: .treatment).map(\.name)
            == illness.treatments.map(\.name))
        #expect(store.items(of: .symptom).map(\.name)
            == illness.symptoms.map(\.name))
    }

    @Test("Created items carry the template's icon and colour")
    func addIllnessCopiesAppearance() throws {
        store.add(IllnessTemplate.asthma)
        let template = try #require(IllnessTemplate.asthma.treatments.first)
        let created = try #require(store.items(of: .treatment).first)
        #expect(created.symbolName == template.symbolName)
        #expect(created.colorName == template.colorName)
        // No template suggests a dose — that's between the user and their doctor.
        #expect(created.defaultDose.isEmpty)
    }

    @Test("Symptoms rate severity and treatments never do")
    func addIllnessSetsSeverityTracking() {
        store.add(IllnessTemplate.migraine)
        #expect(store.items(of: .symptom).allSatisfy { $0.tracksSeverity })
        #expect(store.items(of: .treatment).allSatisfy { !$0.tracksSeverity })
    }

    @Test("Adding the same illness twice creates nothing the second time")
    func addIllnessIsIdempotent() {
        let illness = IllnessTemplate.coldOrFlu
        #expect(store.add(illness) == illness.itemCount)
        #expect(store.add(illness) == 0)
        #expect(store.items(of: .treatment).count == illness.treatments.count)
        #expect(store.items(of: .symptom).count == illness.symptoms.count)
    }

    @Test("Two illnesses that share a symptom create it once")
    func addIllnessMergesSharedItems() {
        // Both offer "Blocked nose"; the catalog should end up with one.
        store.add(IllnessTemplate.coldOrFlu)
        store.add(IllnessTemplate.allergy)
        let names = store.items(of: .symptom).map(\.name)
        #expect(Set(names).count == names.count)

        let shared = Set(IllnessTemplate.coldOrFlu.symptoms.map(\.name))
            .intersection(IllnessTemplate.allergy.symptoms.map(\.name))
        #expect(!shared.isEmpty, "the fixture relies on these two overlapping")
        for name in shared {
            #expect(names.filter { $0 == name }.count == 1)
        }
    }

    @Test("A rename the user made isn't undone by adding the illness again")
    func addIllnessKeepsUserEdits() throws {
        store.add(IllnessTemplate.asthma)
        var mine = try #require(store.items(of: .treatment).first)
        mine.name = "My blue inhaler"
        mine.colorName = ItemColor.pink.rawValue
        store.save(mine)

        // The old name is gone, so that template item is created afresh — but the
        // renamed one is left exactly as the user left it.
        store.add(IllnessTemplate.asthma)
        let renamed = try #require(store.item(id: mine.id))
        #expect(renamed.name == "My blue inhaler")
        #expect(renamed.colorName == ItemColor.pink.rawValue)
    }

    @Test("An item the user renamed to something else is created again")
    func addIllnessFillsTheGapLeftByARename() throws {
        let illness = IllnessTemplate.asthma
        store.add(illness)
        var mine = try #require(store.items(of: .treatment).first)
        let vacatedName = mine.name
        mine.name = "My blue inhaler"
        store.save(mine)
        #expect(store.add(illness) == 1)
        #expect(store.items(of: .treatment).map(\.name).contains(vacatedName))
    }

    @Test("Matching ignores case, accents and stray spaces",
          arguments: ["nausea", "NAUSEA", "  Nausea  ", "Náusea"])
    func addIllnessMatchingIsForgiving(_ existing: String) {
        store.save(Fixture.item(kind: .symptom, name: existing))
        store.add(IllnessTemplate.migraine)
        let nauseas = store.items(of: .symptom, includeArchived: true).filter {
            $0.name.catalogMatchKey == "nausea"
        }
        #expect(nauseas.count == 1)
        #expect(nauseas.first?.name == existing)
    }

    @Test("A hidden item counts as configured, so it isn't quietly re-created")
    func addIllnessRespectsArchivedItems() throws {
        let illness = IllnessTemplate.migraine
        store.add(illness)
        var hidden = try #require(store.items(of: .symptom).first)
        hidden.isArchived = true
        store.save(hidden)

        #expect(store.add(illness) == 0)
        // Still hidden, and not sitting next to a fresh duplicate.
        #expect(store.items(of: .symptom).map(\.name) == illness.symptoms.dropFirst().map(\.name))
    }

    @Test("New items are appended after what's already configured")
    func addIllnessAppendsAtTheEnd() {
        store.save(Fixture.item(kind: .treatment, name: "Mine", sortIndex: 0))
        let illness = IllnessTemplate.allergy
        store.add(illness)
        #expect(store.items(of: .treatment).map(\.name)
            == ["Mine"] + illness.treatments.map(\.name))
    }

    @Test("Appending survives a catalog whose indices have gaps")
    func addIllnessHandlesSparseSortIndices() {
        store.save(Fixture.item(kind: .treatment, name: "Mine", sortIndex: 40))
        store.add(IllnessTemplate.allergy)
        #expect(store.items(of: .treatment).first?.name == "Mine")
        #expect(store.items(of: .treatment).map(\.sortIndex) == [40, 41, 42, 43])
    }

    @Test("Every predefined illness can be added to a fresh catalog",
          arguments: IllnessTemplate.all)
    func everyIllnessAdds(_ illness: IllnessTemplate) {
        let store = CatalogStore(container: Fixture.container())
        #expect(store.add(illness) == illness.itemCount)
        #expect(store.items(of: .treatment).count == illness.treatments.count)
        #expect(store.items(of: .symptom).count == illness.symptoms.count)
    }

    // MARK: Reset

    @Test("Deleting everything empties the catalog, archived items included")
    func deleteAll() {
        store.add(IllnessTemplate.migraine)
        store.save(Fixture.item(kind: .treatment, name: "Mine", isArchived: true, sortIndex: 9))
        store.deleteAll()
        #expect(store.items(of: .treatment, includeArchived: true).isEmpty)
        #expect(store.items(of: .symptom, includeArchived: true).isEmpty)
    }

    @Test("Deleting everything on an empty catalog is harmless")
    func deleteAllWhenEmpty() {
        store.deleteAll()
        #expect(store.items(of: .treatment).isEmpty)
    }

    @Test("After deleting everything a template can be picked again from scratch")
    func deleteAllThenAddAgain() {
        let illness = IllnessTemplate.migraine
        store.add(illness)
        store.deleteAll()
        // Nothing is left to match against, so the whole template comes back — and
        // the indices restart rather than continuing from the old catalog.
        #expect(store.add(illness) == illness.itemCount)
        #expect(store.items(of: .symptom).map(\.sortIndex)
            == Array(0..<illness.symptoms.count))
    }

    @Test("Adding every illness leaves no duplicate names")
    func addingEveryIllnessNeverDuplicates() {
        for illness in IllnessTemplate.all { store.add(illness) }
        for kind in EntryKind.allCases {
            let keys = store.items(of: kind).map { $0.name.catalogMatchKey }
            #expect(Set(keys).count == keys.count)
        }
    }
}
