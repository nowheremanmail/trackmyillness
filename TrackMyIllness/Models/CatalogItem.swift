//
//  CatalogItem.swift
//  TrackMyIllness
//
//  A configurable treatment or symptom — the things you can report — plus its
//  SwiftData record.
//

import Foundation
import SwiftData

/// A treatment or symptom the user has configured in Settings.
struct CatalogItem: Identifiable, Hashable, Sendable {
    var id: String = UUID().uuidString
    var kind: EntryKind = EntryKind.treatment
    var name: String = ""
    var symbolName: String = "pills.fill"
    var colorName: String = ItemColor.blue.rawValue
    /// Prefilled in the entry form for treatments, e.g. "500 mg". Empty means none.
    var defaultDose: String = ""
    /// Symptoms only: whether the entry form asks for a 1–5 severity.
    var tracksSeverity: Bool = true
    /// Hidden from the entry form but kept so old history still resolves.
    var isArchived: Bool = false
    var sortIndex: Int = 0

    var color: ItemColor { ItemColor.named(colorName) }
}

/// The persisted form of a `CatalogItem`.
@Model
final class CatalogItemRecord {
    @Attribute(.unique) var id: String = UUID().uuidString
    var kindRaw: String = EntryKind.treatment.rawValue
    var name: String = ""
    var symbolName: String = "pills.fill"
    var colorName: String = ItemColor.blue.rawValue
    var defaultDose: String = ""
    var tracksSeverity: Bool = true
    var isArchived: Bool = false
    var sortIndex: Int = 0

    init(id: String = UUID().uuidString,
         kindRaw: String = EntryKind.treatment.rawValue,
         name: String = "",
         symbolName: String = "pills.fill",
         colorName: String = ItemColor.blue.rawValue,
         defaultDose: String = "",
         tracksSeverity: Bool = true,
         isArchived: Bool = false,
         sortIndex: Int = 0) {
        self.id = id
        self.kindRaw = kindRaw
        self.name = name
        self.symbolName = symbolName
        self.colorName = colorName
        self.defaultDose = defaultDose
        self.tracksSeverity = tracksSeverity
        self.isArchived = isArchived
        self.sortIndex = sortIndex
    }

    convenience init(_ item: CatalogItem) {
        self.init(id: item.id, kindRaw: item.kind.rawValue, name: item.name,
                  symbolName: item.symbolName, colorName: item.colorName,
                  defaultDose: item.defaultDose, tracksSeverity: item.tracksSeverity,
                  isArchived: item.isArchived, sortIndex: item.sortIndex)
    }

    /// Copies the editable fields across (used when saving an edit).
    func apply(_ item: CatalogItem) {
        kindRaw = item.kind.rawValue
        name = item.name
        symbolName = item.symbolName
        colorName = item.colorName
        defaultDose = item.defaultDose
        tracksSeverity = item.tracksSeverity
        isArchived = item.isArchived
        sortIndex = item.sortIndex
    }

    var value: CatalogItem {
        CatalogItem(id: id, kind: EntryKind(rawValue: kindRaw) ?? .treatment, name: name,
                    symbolName: symbolName, colorName: colorName, defaultDose: defaultDose,
                    tracksSeverity: tracksSeverity, isArchived: isArchived, sortIndex: sortIndex)
    }
}
