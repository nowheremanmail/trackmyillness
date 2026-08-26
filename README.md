# TrackMyIllness

An iOS app for keeping a personal log of an illness: what treatments you took and
what symptoms you felt, when. Everything stays on the device.

## Screens

- **Report** — pick treatment or symptom, tap the item, save. The date defaults to
  today and the time to now, with one-tap shortcuts for 30 min / 1 h / 2 h ago.
  Treatments carry an optional dose, symptoms an optional 1–5 severity.
- **History** — entries grouped by day over 7 / 30 / 90 days or all time, with an
  overview chart of entries per day and average symptom severity.
- **Settings** — configure the treatments and symptoms you can report (name, icon,
  colour, default dose, severity rating), the Face ID lock, PDF export, and About.

## Details

- SwiftUI + MVVM: one view per file, each with previews backed by an in-memory
  sample store (`PreviewData`).
- SwiftData for persistence (`AppDatabase`), reached through the `CatalogStoring`
  and `EntryStoring` protocols so views and view models stay testable.
- Face ID / Touch ID lock, off by default. Uses device-owner authentication, so a
  passcode always works as a fallback.
- PDF export of any period, rendered with `UIGraphicsPDFRenderer` and shared with
  `ShareLink`.
- English source strings with a Spanish translation in
  `Resources/Localizable.xcstrings`.

## Build

Open `TrackMyIllness.xcodeproj` in Xcode 26 or later, or:

```bash
xcodebuild -project TrackMyIllness.xcodeproj -scheme TrackMyIllness -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
