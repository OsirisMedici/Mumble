Mumble 0.1.0 preview 2 brings local dictation to macOS and Windows x64, with the Mumble name and waveform icon, Controls settings, and optional English number and email formatting.

## Downloads and setup

- **Apple Silicon Mac:** `aarch64-apple-darwin` DMG or app ZIP, macOS 13+.
- **Intel Mac:** `x86_64-apple-darwin` DMG or app ZIP, macOS 13+.
- **Windows Intel/AMD PC:** `windows_x64-setup.exe` or portable ZIP, Windows 10/11 x64.
- SHA-256 manifests, native verification reports and license notices accompany the downloads.

[Agent install prompt and terminal commands](https://github.com/OsirisMedici/Mumble#install-with-your-agent) · [Full installation guide](https://github.com/OsirisMedici/Mumble/blob/main/docs/INSTALL.md)

Open Mumble, grant the platform's microphone/Accessibility permissions, download a speech model and choose a shortcut. Models are downloaded separately. Local dictation works offline afterward. Optional Clean Dictation uses a provider you configure.

In Settings → Formatting, enable Numbers as digits and Spoken email addresses for English. "twenty five" becomes `25`; "alex attherate example dot com" becomes `alex@example.com`. Both start off until enabled. Existing Karen Voice settings, models and recordings retain the same app data identity.

Mac previews are ad-hoc signed and not Apple notarized. If macOS blocks the first launch, follow [Apple's instructions](https://support.apple.com/en-us/102445) for Open Anyway. Replacing an ad-hoc signed preview can require renewing its Accessibility entry. Windows previews are unsigned. The installer supplies native runtime DLLs and handles WebView2 if needed. Windows ARM64 and Linux installers are not included.

Updates are manual through this repository. These checks cover packaged startup, normal/portable Windows installation and real transcription of generated speech. Live microphone, global shortcuts and paste on each user's desktop still need the [short acceptance test](https://github.com/OsirisMedici/Mumble/blob/main/docs/INSTALL.md#first-launch-and-a-short-test).

MIT license and third-party notices are included. Mumble transcribes speech; assistant actions and commands that execute tasks are not part of this preview.
