# Symptrace

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
  **Add from an illness** fills the catalog in one go from a built-in list
  (migraine, cold or flu, seasonal allergy, asthma, back pain, digestive
  discomfort, cancer treatment, low mood or anxiety, or a generic set), and
  **More illnesses** downloads an extra list published on the project wiki.
  **Close this illness** archives the current log and starts the Report and
  History tabs clean; **Closed illnesses** reads any of them back and exports one
  on its own. A first run opens on **First steps**, which walks through the app
  and hands straight over to the illness picker.

## Details

- SwiftUI + MVVM: one view per file, each with previews backed by an in-memory
  sample store (`PreviewData`).
- Nothing is created on first run: the catalog starts empty and is filled either
  from an `IllnessTemplate` or item by item. Picking an illness only creates what
  isn't configured yet — matching on name, ignoring case and accents — so two
  overlapping illnesses don't produce duplicates and a rename is never undone.
- The illness templates are **tracking labels, not medical advice**: deliberately
  generic and with no default doses. What you actually take is between you and
  your doctor; every item is editable once created.
- The extra illness list is the app's only network request, made only when that
  screen is opened. Its JSON carries each name in every language the publisher
  provided, and the app resolves the closest match to the reader (exact tag, base
  language, English, then anything) — see `Illness-list` on the wiki. Downloaded
  content is treated as untrusted: unknown symbols and colours fall back, names
  are capped, half-formed illnesses are dropped, and counts are bounded.
- The Report tab orders its chips most-reported first, re-ranked when the tab
  appears so the grid never shifts under your finger mid-entry. Items used equally
  often keep the order set in Settings.
- SwiftData for persistence (`AppDatabase`), reached through the `CatalogStoring`,
  `EntryStoring` and `ClosedIllnessStoring` protocols so views and view models stay
  testable.
- Closing an illness copies and deletes nothing: it stamps every live entry with
  the new `ClosedIllnessRecord`'s id in a single save, and the live queries filter
  on `archiveID == ""` from then on. An archived entry therefore keeps every field
  it ever had, "delete all entries" can't reach it, and the app-wide reset clears
  both. There are no SwiftData relationships anywhere in the schema — `itemID` and
  `archiveID` are plain ids, so renaming or deleting a catalog item never rewrites
  history.
- Face ID / Touch ID lock, off by default. Uses device-owner authentication, so a
  passcode always works as a fallback.
- PDF export of any period, rendered with `UIGraphicsPDFRenderer` and shared with
  `ShareLink`. Free-text notes are included by default but can be left out — the
  report often goes to someone else. The switch only appears when there's a note
  in range, and the choice is remembered.
- English source strings translated into Spanish, Catalan, German, French,
  Italian and Portuguese in `Resources/Localizable.xcstrings`. Catalog content
  (illness, treatment and symptom names) is localized at first access and copied
  into the database as plain text, so history stays readable if the device
  language changes later.
- Swift Testing unit tests in `TrackMyIllnessTests`, covering the models, both
  stores (against a throwaway in-memory container) and every view model.

## Build

The Xcode target, module and folders are still called `TrackMyIllness`; only the
name users see is `Symptrace`.

Open `TrackMyIllness.xcodeproj` in Xcode 26 or later, or:

```bash
xcodebuild -project TrackMyIllness.xcodeproj -scheme TrackMyIllness -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## App icon

`AppIcon.appiconset` holds the light, dark and tinted 1024×1024 variants, and
`AppIconArt.imageset` a small copy that About displays — iOS can't load an app
icon out of the catalog by name, so the screen needs its own image. Both are
generated from one source, so they can't drift:

```bash
swift Tools/MakeIcon.swift TrackMyIllness/Assets.xcassets
```

## Test

```bash
xcodebuild test -project TrackMyIllness.xcodeproj -scheme TrackMyIllness -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The tests run against in-memory stores and a stub authenticator, so they never
touch the real database and never prompt for Face ID.

## Shipping to the App Store

`AppStore/` holds everything the repository can prepare for a submission:
store metadata for all seven languages (length-checked against Apple's limits),
screenshots at the two required sizes, the privacy policy to host, the App Privacy
questionnaire answers, the notes for App Review, and a checklist of the account
work that only the developer can do.

```bash
Tools/screenshots.sh        # regenerate the store screenshots
Tools/archive.sh            # test, archive, export a signed .ipa
Tools/archive.sh --upload   # …and send it to App Store Connect
```

The screenshots are reproducible rather than hand-taken: the script launches the
app with `-seedScreenshotData` and `-screenshotRoute`, which fill a throwaway
store and open one screen directly. Both are `#if DEBUG` only — see
`Services/ScreenshotSupport.swift` — so no shipped build carries a launch argument
that rewrites the user's database.

Start at [AppStore/CHECKLIST.md](AppStore/CHECKLIST.md).

## License

Licensed under the [Apache License, Version 2.0](LICENSE).

Attribution is required: section 4(d) of the licence obliges any redistribution
or derivative work to carry the notices in [NOTICE](NOTICE), which credit the
original developer (Nowhere man) and link back to this repository. Keep that file
with your fork, or reproduce its contents in your own credits screen or docs.
Changed files must also be marked as modified (section 4(b)).
