//
//  IllnessTemplate.swift
//  TrackMyIllness
//
//  The predefined illnesses offered in Settings. Picking one creates the
//  treatments and symptoms usually tracked for it, so the catalog isn't something
//  you have to type out by hand — and nothing is created until you ask for it.
//
//  These are tracking labels, not medical advice: deliberately generic, with no
//  default doses, because what you actually take is between you and your doctor.
//  Everything a template creates is an ordinary catalog item afterwards — rename,
//  recolour, hide or delete it like any other.
//

import Foundation

/// One item inside a template: everything except the identity and the position,
/// which the store assigns when the item is really created.
struct IllnessItem: Hashable, Sendable {
    var name: String
    var symbolName: String
    var colorName: String
    /// Symptoms only; treatments have nothing to rate.
    var tracksSeverity: Bool

    /// The catalog item this template entry becomes. The id is fresh every time,
    /// so adding the same illness on two devices — or twice by mistake — can never
    /// collide on the store's unique key.
    func catalogItem(kind: EntryKind, sortIndex: Int) -> CatalogItem {
        CatalogItem(kind: kind, name: name, symbolName: symbolName, colorName: colorName,
                    tracksSeverity: kind == .symptom && tracksSeverity, sortIndex: sortIndex)
    }
}

/// A named bundle of treatments and symptoms. Not persisted: only the items it
/// creates are, which keeps a template free to change in a later release without
/// migrating anyone's catalog.
struct IllnessTemplate: Identifiable, Hashable, Sendable {
    var id: String
    /// Already localized — see the note on `treatment(_:_:_:)`.
    var name: String
    var symbolName: String
    var treatments: [IllnessItem]
    var symptoms: [IllnessItem]

    func items(of kind: EntryKind) -> [IllnessItem] {
        kind == .treatment ? treatments : symptoms
    }

    var itemCount: Int { treatments.count + symptoms.count }

    /// Every item as a catalog item, numbered from zero within its kind. The store
    /// renumbers when it appends to a catalog that already has something in it.
    var catalogItems: [CatalogItem] {
        EntryKind.allCases.flatMap { kind in
            items(of: kind).enumerated().map { $1.catalogItem(kind: kind, sortIndex: $0) }
        }
    }
}

extension String {
    /// The key used to decide "is this item already in the catalog?". Case, accents
    /// and stray spaces shouldn't be enough to create a second "Náuseas".
    var catalogMatchKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

extension IllnessTemplate {
    /// Localized at first access, like the rest of the catalog content: these names
    /// are copied into the database as plain text rather than resolved when drawn,
    /// so history stays readable even if the device language changes later.
    ///
    /// The entries live in `Localizable.xcstrings` and are maintained by hand,
    /// because the literals below are handed to `String(localized:)` through a
    /// helper rather than at the call site Xcode's extractor looks at.
    private static func treatment(_ name: String.LocalizationValue,
                                 _ symbolName: String,
                                 _ color: ItemColor) -> IllnessItem {
        IllnessItem(name: String(localized: name), symbolName: symbolName,
                    colorName: color.rawValue, tracksSeverity: false)
    }

    private static func symptom(_ name: String.LocalizationValue,
                                _ symbolName: String,
                                _ color: ItemColor) -> IllnessItem {
        IllnessItem(name: String(localized: name), symbolName: symbolName,
                    colorName: color.rawValue, tracksSeverity: true)
    }

    /// Every illness on offer, in the order the picker shows them. The generic set
    /// sits at the end, where "my condition isn't listed" belongs.
    static let all: [IllnessTemplate] = [
        migraine, coldOrFlu, allergy, asthma, backPain, digestive, cancerTreatment,
        mood, general,
    ]

    /// The illness-agnostic starter set — what the app used to create on first run.
    static let general = IllnessTemplate(
        id: "general",
        name: String(localized: "Something else"),
        symbolName: "cross.case.fill",
        treatments: [
            treatment("Morning medication", "sunrise.fill", .orange),
            treatment("Evening medication", "moon.stars.fill", .indigo),
            treatment("Painkiller", "pills.fill", .teal),
        ],
        symptoms: [
            symptom("Pain", "bolt.fill", .red),
            symptom("Fatigue", "zzz", .purple),
            symptom("Nausea", "drop.fill", .green),
            symptom("Fever", "thermometer.high", .pink),
        ])

    static let migraine = IllnessTemplate(
        id: "migraine",
        name: String(localized: "Migraine"),
        symbolName: "brain.head.profile",
        treatments: [
            treatment("Rescue medication", "pills.fill", .teal),
            treatment("Preventive medication", "pill.fill", .indigo),
            treatment("Cold pack", "drop.fill", .blue),
            treatment("Rest in a dark room", "moon.stars.fill", .purple),
        ],
        symptoms: [
            symptom("Headache", "bolt.fill", .red),
            symptom("Aura", "head.profile.arrow.forward.and.visionpro", .yellow),
            symptom("Nausea", "drop.fill", .green),
            symptom("Light sensitivity", "eye.fill", .orange),
            symptom("Sound sensitivity", "ear.fill", .brown),
            symptom("Neck stiffness", "hand.raised.fill", .gray),
        ])

    static let coldOrFlu = IllnessTemplate(
        id: "cold-or-flu",
        name: String(localized: "Cold or flu"),
        symbolName: "thermometer.high",
        treatments: [
            treatment("Painkiller", "pills.fill", .teal),
            treatment("Decongestant", "drop.fill", .blue),
            treatment("Throat lozenge", "pill.fill", .green),
            treatment("Fluids", "waterbottle.fill", .indigo),
            treatment("Rest", "moon.stars.fill", .purple),
        ],
        symptoms: [
            symptom("Fever", "thermometer.high", .pink),
            symptom("Cough", "lungs.fill", .orange),
            symptom("Sore throat", "mouth.fill", .red),
            symptom("Blocked nose", "nose.fill", .blue),
            symptom("Muscle aches", "figure.fall", .brown),
            symptom("Chills", "wind", .indigo),
            symptom("Fatigue", "zzz", .purple),
        ])

    static let allergy = IllnessTemplate(
        id: "seasonal-allergy",
        name: String(localized: "Seasonal allergy"),
        symbolName: "leaf.fill",
        treatments: [
            treatment("Antihistamine", "pills.fill", .teal),
            treatment("Nasal spray", "drop.fill", .blue),
            treatment("Eye drops", "eyedropper.halffull", .green),
        ],
        symptoms: [
            symptom("Sneezing", "wind", .blue),
            symptom("Itchy eyes", "eye.fill", .yellow),
            symptom("Runny nose", "nose.fill", .teal),
            symptom("Blocked nose", "nose.fill", .indigo),
            symptom("Itchy skin", "hand.raised.fill", .pink),
            symptom("Wheezing", "lungs.fill", .orange),
        ])

    static let asthma = IllnessTemplate(
        id: "asthma",
        name: String(localized: "Asthma"),
        symbolName: "lungs.fill",
        treatments: [
            treatment("Reliever inhaler", "inhaler.fill", .blue),
            treatment("Preventer inhaler", "inhaler.fill", .indigo),
            treatment("Breathing exercise", "lungs.fill", .teal),
        ],
        symptoms: [
            symptom("Shortness of breath", "lungs.fill", .red),
            symptom("Wheezing", "wind", .orange),
            symptom("Chest tightness", "heart.slash.fill", .pink),
            symptom("Cough", "mouth.fill", .brown),
            symptom("Night waking", "moon.zzz.fill", .purple),
        ])

    static let backPain = IllnessTemplate(
        id: "back-pain",
        name: String(localized: "Back pain"),
        symbolName: "figure.walk",
        treatments: [
            treatment("Painkiller", "pills.fill", .teal),
            treatment("Anti-inflammatory", "pill.fill", .orange),
            treatment("Heat pack", "bandage.fill", .red),
            treatment("Stretching", "figure.walk", .green),
            treatment("Physiotherapy", "stethoscope", .indigo),
        ],
        symptoms: [
            symptom("Lower back pain", "bolt.fill", .red),
            symptom("Neck pain", "hand.raised.fill", .orange),
            symptom("Stiffness", "figure.fall", .brown),
            symptom("Radiating pain", "waveform.path.ecg", .purple),
            symptom("Numbness", "circle.dotted", .gray),
        ])

    static let digestive = IllnessTemplate(
        id: "digestive",
        name: String(localized: "Digestive discomfort"),
        symbolName: "fork.knife",
        treatments: [
            treatment("Antacid", "pills.fill", .teal),
            treatment("Antispasmodic", "pill.fill", .indigo),
            treatment("Probiotic", "leaf.fill", .green),
            treatment("Fibre supplement", "fork.knife", .brown),
        ],
        symptoms: [
            symptom("Abdominal pain", "bolt.fill", .red),
            symptom("Bloating", "circle.dotted", .orange),
            symptom("Heartburn", "flame.fill", .pink),
            symptom("Nausea", "drop.fill", .green),
            symptom("Diarrhoea", "exclamationmark.triangle.fill", .brown),
            symptom("Constipation", "hand.raised.fill", .gray),
        ])

    /// Named for the treatment rather than the diagnosis, because that's what
    /// there is to log day to day: the sessions and the side effects between them,
    /// which is exactly what an oncologist asks you to remember at the next
    /// appointment.
    static let cancerTreatment = IllnessTemplate(
        id: "cancer-treatment",
        name: String(localized: "Cancer treatment"),
        symbolName: "cross.vial.fill",
        treatments: [
            treatment("Chemotherapy session", "syringe.fill", .indigo),
            treatment("Radiotherapy session", "cross.case.fill", .blue),
            treatment("Oral medication", "pill.fill", .orange),
            treatment("Anti-nausea medication", "pills.fill", .green),
            treatment("Painkiller", "pills.fill", .teal),
        ],
        symptoms: [
            symptom("Fatigue", "zzz", .purple),
            symptom("Nausea", "drop.fill", .green),
            symptom("Pain", "bolt.fill", .red),
            symptom("Loss of appetite", "mouth.fill", .brown),
            symptom("Mouth sores", "flame.fill", .pink),
            symptom("Numbness", "circle.dotted", .gray),
            symptom("Fever", "thermometer.high", .orange),
        ])

    static let mood = IllnessTemplate(
        id: "mood",
        name: String(localized: "Low mood or anxiety"),
        symbolName: "heart.fill",
        treatments: [
            treatment("Medication", "pills.fill", .teal),
            treatment("Therapy session", "stethoscope", .indigo),
            treatment("Walk", "figure.walk", .green),
            treatment("Breathing exercise", "lungs.fill", .blue),
        ],
        symptoms: [
            symptom("Anxiety", "waveform.path.ecg", .orange),
            symptom("Low mood", "cloud.rain.fill", .indigo),
            symptom("Poor sleep", "moon.zzz.fill", .purple),
            symptom("Irritability", "exclamationmark.triangle.fill", .red),
            symptom("Trouble concentrating", "circle.dotted", .gray),
            symptom("Fatigue", "zzz", .brown),
        ])
}
