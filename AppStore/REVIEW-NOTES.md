# Notes for App Review

Paste the block below into App Store Connect → the version → **App Review
Information → Notes**. Leave the demo-account fields empty and untick "Sign-in
required": the app has no account.

---

Symptrace is an offline diary for a personal illness. No account, no sign-up, no
server, no analytics, no ads. Everything the user records is stored in a local
database on the device and is never transmitted.

Getting started (the app deliberately ships with an empty catalog):
1. Open the Settings tab and choose "Add from an illness", then pick any illness
   from the list. This creates the treatments and symptoms usually tracked for it.
2. On the Report tab, choose Treatment or Symptom, tap one of the items, and press
   Save. The date and time default to now.
3. The History tab shows what was recorded, grouped by day, with a chart.
4. Settings → "Close this illness" archives the current log; Settings → "Closed
   illnesses" reads it back and can export it as a PDF.

Face ID: Settings → Privacy → "Require Face ID". It is off by default. It uses
device-owner authentication, so on a simulator or a device without biometrics the
passcode sheet appears instead, and the app can always be unlocked.

Network: the app makes exactly one request, and only if the reviewer taps
Settings → "Add from an illness" → "More illnesses". It downloads a public,
static JSON list of illness templates from raw.githubusercontent.com. Nothing is
uploaded, and no user data is included in the request. If the list is unreachable
the screen shows an error and the rest of the app is unaffected.

Medical claims: there are none. Symptrace does not diagnose, does not recommend or
calculate doses, and does not interpret what is recorded. Doses are free text that
the user types. The store description and the app itself both state that it is a
diary and not a substitute for medical advice.

Source code: https://github.com/nowheremanmail/trackmyillness
