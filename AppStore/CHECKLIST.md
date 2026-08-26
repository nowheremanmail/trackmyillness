# Shipping Symptrace to the App Store

What is in this folder is everything that could be prepared from the repository.
The rest is account work in App Store Connect, which needs your Apple ID.

## 0. Names, and the one that is already settled

The app is **named** Symptrace everywhere a user can see: the home screen
(`CFBundleDisplayName`), the icon, and the store metadata in this folder.

The bundle identifier is `eu.nowhereman.ios.trackmyillness`, and it stays that way
by decision — it can never be changed once a build has been uploaded, and it is
invisible to users, so the only place it will ever show up is your own App Store
Connect account. Use exactly that identifier when creating the record in step 3.

The Xcode target, the scheme and the source folders are still called
TrackMyIllness too. That is purely cosmetic and can be renamed at any time,
before or after shipping, without consequences.

## 1. Apple Developer account

- An active Apple Developer Program membership (99 EUR/year) on team `W37STSLM78`.
- That Apple ID signed in to Xcode → Settings → Accounts, so automatic signing can
  fetch the distribution certificate and provisioning profile.

## 2. Host the privacy policy

App Store Connect will not accept the submission without a reachable privacy
policy URL, and the app has no in-app link to one.

`AppStore/privacy-policy.html` is ready to publish. The simplest route, since the
repository is already public: enable GitHub Pages on `nowheremanmail/trackmyillness`
and copy the file to `docs/privacy.html`, which serves it at

    https://nowheremanmail.github.io/trackmyillness/privacy.html

That is the URL already written into `AppStore/metadata/*/privacy_url.txt`. If you
host it elsewhere, update those seven files to match.

## 3. Create the App Store Connect record

- **Platform** iOS · **Name** Symptrace · **Primary language** English (U.S.)
- **Bundle ID** whatever step 0 settled on
- **SKU** anything unique, e.g. `symptrace-ios`
- **Category**: currently declared as **Medical**
  (`INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.medical`).
  Worth a thought: Medical draws heavier review scrutiny, and a personal diary that
  makes no clinical claims usually sits more naturally in **Health & Fitness**. If
  you switch, change it in App Store Connect *and* in the build setting.
- **Price** Free.

## 4. Fill the metadata

`AppStore/metadata/<locale>/` holds one file per App Store Connect field, for
en-US, es-ES, ca, de-DE, fr-FR, it and pt-PT — the seven languages the app itself
ships. Every field has been checked against Apple's length limits.

Catalan is offered as an App Store localization, but if your App Store Connect does
not list it, drop that folder: the app still ships its Catalan interface either way.

`release_notes.txt` is unused for version 1.0 — App Store Connect only asks for it
from the first update onwards.

## 5. Upload the screenshots

`AppStore/screenshots/<locale>/` holds four screenshots per device, already at the
exact sizes Apple requires:

- `iphone-6.9/` — 1320 × 2868 (required)
- `ipad-13/` — 2064 × 2752 (required, because the app ships for iPad)

They exist for en-US and es-ES. App Store Connect reuses the primary language's
screenshots for any localization you leave empty, so the other five are optional.

To regenerate them — after a UI change, or for another language:

    Tools/screenshots.sh            # en-US and es-ES
    Tools/screenshots.sh de-DE      # one locale

The script seeds the app with sample data and opens each screen directly, so a
rerun produces the same images. It never touches your own data: it drives a
simulator, not a device.

## 6. Answer the privacy questionnaire

Follow `AppStore/APP-PRIVACY.md` — the answer is "Data Not Collected", and that
file explains how to justify it if asked.

## 7. Add the review notes

Copy the block from `AppStore/REVIEW-NOTES.md` into App Review Information. It
matters here: the app starts with an empty catalog, so a reviewer who opens it and
taps around without reading first will see an empty screen and may reject it as
non-functional.

## 8. Build and upload

    Tools/archive.sh                # runs the tests, archives, exports a signed .ipa
    Tools/archive.sh --upload       # …and uploads it

Uploading needs an App Store Connect API key; the script's header says which
environment variables to set. Without the key, drop `build/export/*.ipa` into
Transporter, or archive from Xcode and use Organizer → Distribute App.

## 9. Before you press Submit

- Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` for every new upload — App
  Store Connect rejects a build number it has already seen.
- Check the app on a real device once. The simulator does not exercise Face ID
  properly, and that is the one feature a reviewer is likely to try.
- Export compliance is already answered: `ITSAppUsesNonExemptEncryption` is
  `false` in `Info.plist`, so you will not be asked each time.
