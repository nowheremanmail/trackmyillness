//
//  LogEntryViewModelTests.swift
//  TrackMyIllnessTests
//
//  The Report tab: picking an item, adjusting when it happened, saving, undoing.
//
//  Serialized because the view model remembers the last kind in UserDefaults,
//  which is process-wide state these tests both read and write.
//

import Foundation
import Testing
@testable import TrackMyIllness

@Suite("LogEntryViewModel", .serialized)
@MainActor
struct LogEntryViewModelTests {
    private let catalog: CatalogStore
    private let entries: EntryStore
    private let painkiller = Fixture.item(kind: .treatment, name: "Painkiller",
                                          defaultDose: "500 mg", sortIndex: 0)
    private let pain = Fixture.item(kind: .symptom, name: "Pain",
                                    tracksSeverity: true, sortIndex: 0)
    private let fatigue = Fixture.item(kind: .symptom, name: "Fatigue",
                                       tracksSeverity: false, sortIndex: 1)

    init() {
        Fixture.resetDefaults()
        let container = Fixture.container()
        catalog = CatalogStore(container: container)
        entries = EntryStore(container: container)
        for item in [painkiller, pain, fatigue] { catalog.save(item) }
    }

    private func makeModel() -> LogEntryViewModel {
        let model = LogEntryViewModel(catalog: catalog, entries: entries,
                                      calendar: Fixture.calendar)
        model.refresh()
        return model
    }

    // MARK: Kind

    @Test("The form opens on treatments and lists only that kind")
    func opensOnTreatments() {
        let model = makeModel()
        #expect(model.kind == .treatment)
        #expect(model.items.map(\.name) == ["Painkiller"])
        #expect(model.showsDose)
        #expect(model.showsSeverity == false)
    }

    @Test("Switching kind reloads the items and clears the half-filled form")
    func switchingKindResetsForm() {
        let model = makeModel()
        model.select(painkiller)
        model.dose = "1 tablet"
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Pain", "Fatigue"])
        #expect(model.selectedItemID == nil)
        #expect(model.dose.isEmpty)
        #expect(model.severity == 0)
        #expect(model.showsDose == false)
    }

    @Test("The last kind used is remembered for the next visit")
    func remembersLastKind() {
        let model = makeModel()
        model.kind = .symptom
        #expect(UserDefaults.standard.string(forKey: AppSettings.lastEntryKindKey)
            == EntryKind.symptom.rawValue)
        // A fresh view model picks it back up.
        #expect(makeModel().kind == .symptom)
    }

    // MARK: Ordering

    @Test("A fresh catalog keeps the order configured in Settings")
    func unusedItemsKeepSettingsOrder() {
        let model = makeModel()
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Pain", "Fatigue"])
    }

    @Test("The most-reported item comes first, whatever Settings says")
    func mostReportedComesFirst() {
        // Fatigue is second in Settings but reported twice as often as Pain.
        entries.add(Fixture.entry(reporting: fatigue, date: Fixture.daysAgo(1)))
        entries.add(Fixture.entry(reporting: fatigue, date: Fixture.daysAgo(2)))
        entries.add(Fixture.entry(reporting: pain, date: Fixture.daysAgo(1)))

        let model = makeModel()
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Fatigue", "Pain"])
    }

    @Test("Items reported equally often fall back to the Settings order")
    func tiesKeepSettingsOrder() {
        entries.add(Fixture.entry(reporting: pain, date: Fixture.daysAgo(1)))
        entries.add(Fixture.entry(reporting: fatigue, date: Fixture.daysAgo(1)))
        let model = makeModel()
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Pain", "Fatigue"])
    }

    @Test("An item that's never been reported sinks below the ones that have")
    func unusedItemsSinkToTheBottom() {
        entries.add(Fixture.entry(reporting: fatigue, date: Fixture.daysAgo(1)))
        let model = makeModel()
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Fatigue", "Pain"])
    }

    @Test("Ranking counts only what was reported, so the other kind can't skew it")
    func rankingIsPerKind() {
        for day in 0..<5 {
            entries.add(Fixture.entry(reporting: painkiller, date: Fixture.daysAgo(day + 1)))
        }
        let model = makeModel()
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Pain", "Fatigue"])
    }

    @Test("The chips hold still after a save, so the grid can't shift under a finger")
    func orderIsStableWithinAVisit() {
        entries.add(Fixture.entry(reporting: fatigue, date: Fixture.daysAgo(1)))
        let model = makeModel()
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Fatigue", "Pain"])

        // Three reports of Pain would put it top — but not until the tab reappears.
        for _ in 0..<3 {
            model.select(pain)
            #expect(model.save())
        }
        #expect(model.items.map(\.name) == ["Fatigue", "Pain"])

        model.refresh()
        #expect(model.items.map(\.name) == ["Pain", "Fatigue"])
    }

    @Test("Re-ranking survives switching kinds and back")
    func orderSurvivesKindSwitch() {
        entries.add(Fixture.entry(reporting: fatigue, date: Fixture.daysAgo(1)))
        let model = makeModel()
        model.kind = .symptom
        model.kind = .treatment
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Fatigue", "Pain"])
    }

    @Test("An archived item is still left out however often it was reported")
    func rankingNeverResurrectsArchivedItems() {
        for day in 0..<5 {
            entries.add(Fixture.entry(reporting: fatigue, date: Fixture.daysAgo(day + 1)))
        }
        var archived = fatigue
        archived.isArchived = true
        catalog.save(archived)

        let model = makeModel()
        model.kind = .symptom
        #expect(model.items.map(\.name) == ["Pain"])
    }

    // MARK: Selection

    @Test("Tapping an item selects it and prefills its default dose")
    func selectPrefillsDose() {
        let model = makeModel()
        model.select(painkiller)
        #expect(model.selectedItemID == painkiller.id)
        #expect(model.selectedItem?.name == "Painkiller")
        #expect(model.dose == "500 mg")
        #expect(model.canSave)
    }

    @Test("Tapping the selected item again deselects it, so a mis-tap is one tap to fix")
    func selectTogglesOff() {
        let model = makeModel()
        model.select(painkiller)
        model.select(painkiller)
        #expect(model.selectedItemID == nil)
        #expect(model.dose.isEmpty)
        #expect(model.canSave == false)
    }

    @Test("Picking a severity-tracking symptom starts at the middle of the scale")
    func symptomStartsAtMidSeverity() {
        let model = makeModel()
        model.kind = .symptom
        model.select(pain)
        #expect(model.severity == 3)
        #expect(model.showsSeverity)
    }

    @Test("A symptom that doesn't rate severity is never asked for one")
    func symptomWithoutSeverity() {
        let model = makeModel()
        model.kind = .symptom
        model.select(fatigue)
        #expect(model.severity == 0)
        #expect(model.showsSeverity == false)
    }

    @Test("An already-set severity isn't overwritten when switching symptoms")
    func severityIsKeptAcrossSymptoms() {
        let model = makeModel()
        model.kind = .symptom
        model.select(pain)
        model.severity = 5
        model.select(pain)      // deselect
        model.select(pain)      // and back
        #expect(model.severity == 5)
    }

    @Test("A selection that's been archived in Settings is dropped on refresh")
    func refreshDropsVanishedSelection() {
        let model = makeModel()
        model.select(painkiller)
        var archived = painkiller
        archived.isArchived = true
        catalog.save(archived)
        model.refresh()
        #expect(model.items.isEmpty)
        #expect(model.selectedItemID == nil)
        #expect(model.canSave == false)
    }

    // MARK: Time

    @Test("A quick-time button backdates the entry and lights up")
    func timeShortcut() {
        let model = makeModel()
        model.apply(.oneHour)
        #expect(model.activeShortcut == .oneHour)
        #expect(abs(model.timestamp.timeIntervalSinceNow - (-3600)) < 5)
    }

    @Test("Editing the time by hand un-highlights the shortcut")
    func manualEditClearsShortcut() {
        let model = makeModel()
        model.apply(.twoHours)
        model.timestamp = Fixture.fixedDate
        #expect(model.activeShortcut == nil)
        #expect(model.timestamp == Fixture.fixedDate)
    }

    @Test("\"Now\" brings the time back to the present")
    func resetToNow() {
        let model = makeModel()
        model.timestamp = Fixture.fixedDate
        model.resetToNow()
        #expect(model.activeShortcut == .now)
        #expect(abs(model.timestamp.timeIntervalSinceNow) < 5)
    }

    // MARK: Saving

    @Test("Saving with nothing selected does nothing")
    func saveNeedsASelection() {
        let model = makeModel()
        #expect(model.save() == false)
        #expect(model.today.isEmpty)
        #expect(model.lastSavedEntry == nil)
    }

    @Test("Saving copies the item's details onto the entry and clears the form")
    func saveTreatment() throws {
        let model = makeModel()
        model.select(painkiller)
        model.dose = "  1 tablet  "
        model.note = "  after food  "
        #expect(model.save())

        let saved = try #require(model.lastSavedEntry)
        #expect(saved.kind == .treatment)
        #expect(saved.itemID == painkiller.id)
        #expect(saved.itemName == "Painkiller")
        #expect(saved.symbolName == painkiller.symbolName)
        #expect(saved.colorName == painkiller.colorName)
        // Trimmed, and a treatment never carries a severity.
        #expect(saved.dose == "1 tablet")
        #expect(saved.note == "after food")
        #expect(saved.severity == 0)

        // The form is ready for the next entry, and today's list confirms the tap.
        #expect(model.selectedItemID == nil)
        #expect(model.dose.isEmpty)
        #expect(model.note.isEmpty)
        #expect(model.activeShortcut == .now)
        #expect(model.today.map(\.itemName) == ["Painkiller"])
    }

    @Test("A symptom saves its severity but no dose")
    func saveSymptom() throws {
        let model = makeModel()
        model.kind = .symptom
        model.select(pain)
        model.severity = 4
        model.dose = "should be ignored"
        #expect(model.save())
        let saved = try #require(model.lastSavedEntry)
        #expect(saved.kind == .symptom)
        #expect(saved.severity == 4)
        #expect(saved.dose.isEmpty)
    }

    @Test("A symptom that doesn't rate severity saves without one")
    func saveSymptomWithoutSeverity() {
        let model = makeModel()
        model.kind = .symptom
        model.select(fatigue)
        model.severity = 4      // set by hand, but this symptom doesn't track it
        #expect(model.save())
        #expect(model.lastSavedEntry?.severity == 0)
    }

    @Test("Today's list shows the newest entry first")
    func todayIsNewestFirst() {
        let model = makeModel()
        model.select(painkiller)
        model.apply(.twoHours)
        #expect(model.save())
        model.select(painkiller)
        model.dose = "second"
        #expect(model.save())
        #expect(model.today.first?.dose == "second")
    }

    @Test("Undo removes the entry that was just saved")
    func undoLastSave() {
        let model = makeModel()
        model.select(painkiller)
        #expect(model.save())
        model.undoLastSave()
        #expect(model.lastSavedEntry == nil)
        #expect(model.today.isEmpty)
        #expect(entries.entries(in: .distantPast ... .distantFuture).isEmpty)
    }

    @Test("Undo with nothing saved is harmless")
    func undoWithoutSave() {
        let model = makeModel()
        model.undoLastSave()
        #expect(model.today.isEmpty)
    }

    @Test("Dismissing the confirmation keeps the entry")
    func dismissConfirmation() {
        let model = makeModel()
        model.select(painkiller)
        #expect(model.save())
        model.dismissConfirmation()
        #expect(model.lastSavedEntry == nil)
        #expect(model.today.count == 1)
    }

    @Test("Deleting the just-saved entry also clears the confirmation it belongs to")
    func deleteClearsStaleConfirmation() throws {
        let model = makeModel()
        model.select(painkiller)
        #expect(model.save())
        let saved = try #require(model.lastSavedEntry)
        model.delete(saved)
        #expect(model.lastSavedEntry == nil)
        #expect(model.today.isEmpty)
    }

    @Test("Deleting an older entry leaves the confirmation for the new one alone")
    func deleteKeepsUnrelatedConfirmation() throws {
        let model = makeModel()
        model.select(painkiller)
        #expect(model.save())
        let first = try #require(model.lastSavedEntry)
        model.select(painkiller)
        #expect(model.save())
        let second = try #require(model.lastSavedEntry)
        model.delete(first)
        #expect(model.lastSavedEntry?.id == second.id)
        #expect(model.today.count == 1)
    }
}
