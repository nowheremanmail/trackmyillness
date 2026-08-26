//
//  ScreenshotSupport.swift
//  TrackMyIllness
//
//  Debug-only plumbing for Tools/screenshots.sh: it launches the app with a
//  populated store, straight onto the screen it wants to photograph, so App Store
//  screenshots are reproducible instead of a tapping session nobody can repeat.
//
//  Wrapped in #if DEBUG in full — a shipped build has no launch argument that
//  rewrites the user's database.
//

#if DEBUG
import Foundation
import SwiftData

/// The screen a screenshot run wants on display.
enum ScreenshotRoute: String {
    case report
    case history
    case settings
    /// Settings with the "close this illness" sheet already up.
    case close
}

enum ScreenshotMode {
    private static let seedArgument = "-seedScreenshotData"
    private static let routeArgument = "-screenshotRoute"

    /// Set when this launch is a screenshot run.
    static let isActive = ProcessInfo.processInfo.arguments.contains(seedArgument)

    static let route: ScreenshotRoute? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: routeArgument),
              arguments.indices.contains(index + 1) else { return nil }
        return ScreenshotRoute(rawValue: arguments[index + 1])
    }()

    /// Replaces whatever is in the store with a tidy sample: a filled catalog,
    /// three weeks of entries, and one already-closed illness so the archive
    /// screens have something to show.
    static func seedIfRequested() {
        guard isActive else { return }
        let context = ModelContext(AppDatabase.container)
        try? context.delete(model: LogEntryRecord.self)
        try? context.delete(model: CatalogItemRecord.self)
        try? context.delete(model: ClosedIllnessRecord.self)

        let catalog = IllnessTemplate.general.catalogItems
        for item in catalog { context.insert(CatalogItemRecord(item)) }

        let entries = PreviewData.sampleEntries(catalog: catalog)
        for entry in entries { context.insert(LogEntryRecord(entry)) }

        // One closed illness, built from a made-up earlier stretch so it doesn't
        // eat into the live log the other screenshots need.
        let calendar = Calendar.current
        let earlier = entries.compactMap { entry -> LogEntry? in
            guard let date = calendar.date(byAdding: .day, value: -60, to: entry.date) else { return nil }
            var copy = entry
            copy.id = UUID().uuidString
            copy.date = date
            return copy
        }
        let dates = earlier.map(\.date)
        let closed = ClosedIllness(
            name: String(localized: "Winter flu"),
            closedAt: dates.max() ?? .now,
            startedAt: dates.min() ?? .now,
            endedAt: dates.max() ?? .now,
            treatmentCount: earlier.count { $0.kind == .treatment },
            symptomCount: earlier.count { $0.kind == .symptom })
        context.insert(ClosedIllnessRecord(closed))
        for entry in earlier {
            var archived = entry
            archived.archiveID = closed.id
            context.insert(LogEntryRecord(archived))
        }

        try? context.save()
        // The walkthrough would cover every screenshot.
        UserDefaults.standard.set(true, forKey: AppSettings.hasSeenFirstStepsKey)
        UserDefaults.standard.set(false, forKey: AppSettings.biometricLockKey)
    }
}
#endif
