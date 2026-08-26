# App Privacy answers (App Store Connect → App Privacy)

Fill the questionnaire exactly as below. Every answer is a factual claim about the
shipped binary; if the app ever gains analytics, a backend or an account, this file
and the answers have to change with it.

## Data collection

**"Do you or your third-party partners collect data from this app?"** → **No**

That produces the "Data Not Collected" label. It is accurate:

- No account, no sign-up, no identifiers of any kind.
- No analytics, crash-reporting, advertising or attribution SDK. The app links only
  Apple frameworks (SwiftUI, SwiftData, Charts, LocalAuthentication, PDFKit/UIKit).
- The health log lives in a local SwiftData store and is never transmitted.
- The single outbound request — the illness-template list, fetched only when the
  user opens *More illnesses* — sends no user data and receives a static public
  JSON file. Under Apple's definition this is not collection: nothing about the
  user is sent or stored off-device.

If a reviewer queries the network call, point them at
`TrackMyIllness/Services/RemoteIllnessLoader.swift`, which is deliberately the only
place in the codebase that touches `URLSession`, and uses an ephemeral session with
cookies disabled.

## Export compliance

`ITSAppUsesNonExemptEncryption` is already set to `false` in
`TrackMyIllness/Info.plist`, so App Store Connect will not ask each submission. The
app uses only HTTPS through the OS, which is exempt.

## Content rights

The app contains no third-party content. The illness templates are generic tracking
labels written for this project.

## Age rating

Expect **4+**. Answer "None" to every content question. The one to think about is
"Medical/Treatment Information": the app records what the *user* types and makes no
medical claims, gives no dosage guidance and offers no diagnosis, so answer **None**
— but be ready to justify it with the in-app disclaimer and the store description,
both of which state that it is a diary and not medical advice.
