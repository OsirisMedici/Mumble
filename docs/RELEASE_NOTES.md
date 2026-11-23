The first public preview of Mumble: free local dictation with a configurable shortcut, downloadable speech models, transcript history, a recording overlay and green branding.

## Downloads

- Choose the **aarch64 / Apple Silicon** DMG for an M-series Mac.
- Choose the **x64 / Intel** DMG for an Intel Mac.
- Open the DMG and drag Mumble into Applications. Grant microphone and Accessibility permissions, then download a model.
- ZIP archives contain the same app for people who prefer an archive. SHA256SUMS files verify download integrity.

Requires macOS 13 or newer. These preview builds are **ad-hoc signed and not Apple notarized**. macOS may block the first launch. Use System Settings → Privacy & Security → Open Anyway for this app, following [Apple's instructions](https://support.apple.com/en-us/102445).

This release provides dictation. Karen assistant actions are future work. Updates are manual through this repository. Keep other dictation apps closed when testing the same shortcut. Existing Karen Voice settings and models remain in the same data directory under `com.osirismedici.karenvoice`. The display name is now Mumble; the icon uses the rounded Mumble “m” mark.

Build and native-startup checks run in GitHub Actions before publication. Real microphone recording and paste into another app require a user acceptance check. Report problems with your Mac type, macOS version, model and reproduction steps, without sharing private transcripts.

MIT license and third-party notices are included in the app and downloads.
