//
//  CatalogViewModelTests.swift
//  TrackMyIllnessTests
//
//  The Settings screens that configure what can be reported.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("CatalogViewModel")
@MainActor
struct CatalogViewModelTests {
    private let store: CatalogStore
    private let model: CatalogViewModel

    init() {
        let store = CatalogStore(container: Fixture.container())
        self.store = store
        model = CatalogViewModel(store: store)
    }

    @Test("Refresh splits the catalog by kind and keeps archived items visible here")
    func refreshIncludesArchived() {
        store.save(Fixture.item(kind: .treatment, name: "Painkiller"))
        store.save(Fixture.item(kind: .treatment, name: "Retired", isArchived: true, sortIndex: 1))
        store.save(Fixture.item(kind: .symptom, name: "Pain", tracksSeverity: true))
        model.refresh()
        // Settings has to show archived items — that's where you un-archive them.
        #expect(model.treatments.map(\.name) == ["Painkiller", "Retired"])
        #expect(model.symptoms.map(\.name) == ["Pain"])
        #expect(model.items(of: .treatment).count == 2)
        #expect(model.items(of: .symptom).count == 1)
    }

    @Test("A blank item is pre-set for its kind and slotted at the end of the list")
    func newItemDefaults() {
        store.save(Fixture.item(kind: .treatment, name: "Painkiller"))
        model.refresh()

        let treatment = model.newItem(of: .treatment)
        #expect(treatment.kind == .treatment)
        #expect(treatment.name.isEmpty)
        #expect(treatment.symbolName == EntryKind.treatment.systemImage)
        #expect(treatment.colorName == ItemColor.teal.rawValue)
        #expect(treatment.tracksSeverity == false)
        #expect(treatment.sortIndex == 1)

        let symptom = model.newItem(of: .symptom)
        #expect(symptom.symbolName == EntryKind.symptom.systemImage)
        #expect(symptom.colorName == ItemColor.orange.rawValue)
        // Symptoms rate severity by default; treatments have nothing to rate.
        #expect(symptom.tracksSeverity)
        #expect(symptom.sortIndex == 0)
    }

    @Test("Saving trims stray whitespace off the name and the dose")
    func saveTrimsWhitespace() {
        var item = Fixture.item(name: "  Painkiller \n")
        item.defaultDose = "  500 mg  "
        model.save(item)
        #expect(model.treatments.map(\.name) == ["Painkiller"])
        #expect(model.treatments.first?.defaultDose == "500 mg")
    }

    @Test("An item with no real name is rejected rather than saved blank",
          arguments: ["", " ", "\n", "\t  \n"])
    func saveRejectsBlankName(_ name: String) {
        model.save(Fixture.item(name: name))
        #expect(model.treatments.isEmpty)
        #expect(store.items(of: .treatment).isEmpty)
    }

    @Test("Saving refreshes the lists, so the editor's change shows without a reload")
    func saveRefreshes() {
        var item = Fixture.item(name: "Painkiller")
        model.save(item)
        item.name = "Ibuprofen"
        model.save(item)
        #expect(model.treatments.map(\.name) == ["Ibuprofen"])
    }

    @Test("Deleting an item drops it from the list")
    func deleteItem() {
        let item = Fixture.item(name: "Painkiller")
        model.save(item)
        model.save(Fixture.item(name: "Keep me", sortIndex: 1))
        model.delete(item)
        #expect(model.treatments.map(\.name) == ["Keep me"])
    }

    @Test("Swipe-to-delete removes exactly the rows the list offered")
    func deleteAtOffsets() {
        for (index, name) in ["A", "B", "C"].enumerated() {
            model.save(Fixture.item(name: name, sortIndex: index))
        }
        model.delete(at: IndexSet([0, 2]), in: .treatment)
        #expect(model.treatments.map(\.name) == ["B"])
    }

    @Test("An out-of-bounds offset is ignored instead of trapping")
    func deleteAtOffsetsOutOfBounds() {
        model.save(Fixture.item(name: "A"))
        model.delete(at: IndexSet([0, 7]), in: .treatment)
        #expect(model.treatments.isEmpty)
    }

    @Test("Deleting from one kind leaves the other alone")
    func deleteIsPerKind() {
        model.save(Fixture.item(kind: .treatment, name: "Painkiller"))
        model.save(Fixture.item(kind: .symptom, name: "Pain", tracksSeverity: true))
        model.delete(at: IndexSet([0]), in: .symptom)
        #expect(model.treatments.map(\.name) == ["Painkiller"])
        #expect(model.symptoms.isEmpty)
    }

    @Test("Dragging a row to a new position sticks")
    func moveReorders() {
        for (index, name) in ["A", "B", "C"].enumerated() {
            model.save(Fixture.item(name: name, sortIndex: index))
        }
        model.move(from: IndexSet([2]), to: 0, in: .treatment)
        #expect(model.treatments.map(\.name) == ["C", "A", "B"])
        // And it's the store that remembers, not just the in-memory list.
        #expect(store.items(of: .treatment).map(\.name) == ["C", "A", "B"])
    }

    @Test("Archiving hides an item from reporting without deleting it")
    func setArchived() {
        let item = Fixture.item(name: "Retired")
        model.save(item)
        model.setArchived(true, for: item)
        #expect(model.treatments.map(\.name) == ["Retired"])
        #expect(model.treatments.first?.isArchived == true)
        // Gone from the entry form, still on record for old history.
        #expect(store.items(of: .treatment).isEmpty)
        #expect(store.item(id: item.id) != nil)

        model.setArchived(false, for: model.treatments[0])
        #expect(store.items(of: .treatment).map(\.name) == ["Retired"])
    }

    // MARK: Predefined illnesses

    @Test("Adding an illness fills both lists and reports what it created")
    func addIllness() {
        let illness = IllnessTemplate.migraine
        #expect(model.add(illness) == illness.itemCount)
        #expect(model.treatments.map(\.name) == illness.treatments.map(\.name))
        #expect(model.symptoms.map(\.name) == illness.symptoms.map(\.name))
    }

    @Test("Adding an illness twice reports that there was nothing left to create")
    func addIllnessTwice() {
        let illness = IllnessTemplate.asthma
        model.add(illness)
        #expect(model.add(illness) == 0)
        #expect(model.treatments.count == illness.treatments.count)
    }

    @Test("The picker can tell which of an illness's items already exist")
    func isConfigured() throws {
        let illness = IllnessTemplate.migraine
        let first = try #require(illness.symptoms.first)
        #expect(model.isConfigured(first, of: .symptom) == false)
        model.add(illness)
        #expect(model.isConfigured(first, of: .symptom))
        // A symptom's name being taken says nothing about the treatment list.
        #expect(model.isConfigured(IllnessItem(name: first.name, symbolName: "pills.fill",
                                              colorName: ItemColor.teal.rawValue,
                                              tracksSeverity: false),
                                  of: .treatment) == false)
    }

    @Test("The pending count is what Add would really create")
    func pendingCount() {
        let illness = IllnessTemplate.coldOrFlu
        #expect(model.pendingCount(in: illness) == illness.itemCount)
        model.add(illness)
        #expect(model.pendingCount(in: illness) == 0)
    }

    @Test("Items shared with an illness already added don't count as pending")
    func pendingCountExcludesSharedItems() {
        model.add(IllnessTemplate.coldOrFlu)
        let allergy = IllnessTemplate.allergy
        let pending = model.pendingCount(in: allergy)
        #expect(pending > 0)
        #expect(pending < allergy.itemCount, "these two share at least one symptom")
    }

    // MARK: Reset

    @Test("Reset clears both lists")
    func reset() {
        model.add(IllnessTemplate.coldOrFlu)
        model.save(Fixture.item(name: "Mine"))
        model.reset()
        #expect(model.treatments.isEmpty)
        #expect(model.symptoms.isEmpty)
        #expect(model.isEmpty)
        #expect(store.items(of: .treatment, includeArchived: true).isEmpty)
    }

    @Test("Reset puts every template back on offer in full")
    func resetMakesTemplatesPickableAgain() {
        let illness = IllnessTemplate.asthma
        model.add(illness)
        #expect(model.pendingCount(in: illness) == 0)
        model.reset()
        #expect(model.pendingCount(in: illness) == illness.itemCount)
        #expect(model.add(illness) == illness.itemCount)
    }

    @Test("Reset on a catalog that's already empty is harmless")
    func resetWhenEmpty() {
        model.reset()
        #expect(model.isEmpty)
    }

    @Test("An empty catalog reports itself as empty, a filled one doesn't")
    func isEmptyFlag() {
        #expect(model.isEmpty)
        model.save(Fixture.item(kind: .symptom, name: "Pain", tracksSeverity: true))
        #expect(model.isEmpty == false)
    }

    @Test("A hidden item still counts as configured for the picker")
    func pendingCountCountsHiddenItems() throws {
        let illness = IllnessTemplate.migraine
        model.add(illness)
        let hidden = try #require(model.symptoms.first)
        model.setArchived(true, for: hidden)
        #expect(model.pendingCount(in: illness) == 0)
    }
}
