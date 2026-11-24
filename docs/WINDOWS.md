# Mumble on Windows

## Download and install

Use a successful **Windows preview** workflow run in this repository and download its `windows-x86_64-pc-windows-msvc` artifact. Extract the artifact ZIP to find:

- `Mumble_<version>_windows_x64-setup.exe`, the normal installer.
- `Mumble_<version>_windows_x64_portable.zip`, the portable app with its runtime files.
- `SHA256SUMS-windows-x64.txt` and the Windows verification report.

The preview targets Windows 10/11 on Intel/AMD x64 PCs. Windows ARM64 is not included. Builds are unsigned; a publisher certificate has not been configured. Use only downloads from this repository and compare their hashes with `Get-FileHash <file> -Algorithm SHA256`.

Run the setup executable for a normal installation, or extract the portable ZIP into a writable folder and open `Mumble/karen-voice.exe`. Keep all the included DLLs and resources beside the executable. The internal executable name stays stable for compatibility; the product name and icon are Mumble. The installer can install the Microsoft Edge WebView2 runtime if it is missing, which requires internet access.

Download a speech model in Mumble. Choose a shortcut that does not conflict with another dictation app. The Mac Fn shortcut and Apple Intelligence are Mac-specific; Windows has its own shortcut defaults and microphone settings. Local dictation, history, number formatting and spoken-email formatting are shared.

If microphone access is disabled, open Windows Settings > Privacy & security > Microphone and enable microphone access for desktop apps. Dictation into an elevated application may require matching privileges; use a normal text editor for the first test.

Normal installations use `%APPDATA%/com.osirismedici.karenvoice` for app data. Portable installations store settings, models and history in `Data` beside the executable. Preserve the `portable` marker file. It uses the legacy compatibility string recognized by the app.

## Automated verification

The Windows workflow builds the actual release executable and NSIS installer on a Windows runner. It installs normal and portable copies, checks the Mumble product identity, legal notices and native runtime DLLs, and launches the installed app. It then removes build-tool paths from the test process, downloads a checksum-pinned public model into the temporary portable copy and transcribes generated speech. The test includes number and email formatting.

The portable ZIP is created before the verification model and settings are added. It contains no downloaded speech models, user audio or verification transcripts. Failed verification prevents upload of the Windows downloads and blocks tagged release publication.

## Interactive acceptance

A successful workflow proves build, packaging, native startup and file transcription on the runner. It does not prove microphone capture or interaction with another app on a user's Windows desktop. Before calling the preview fully accepted:

1. Install on a Windows PC and open Mumble with the expected name and icon.
2. Download a model and confirm microphone access.
3. Record with the selected shortcut, stop, and paste into a normal text editor.
4. Cancel a recording and repeat dictation.
5. Enable each Formatting option and dictate a number and an email using "at the rate".
6. Quit and reopen, verify saved settings, then uninstall the normal installation.
7. For portable use, move the whole folder and confirm settings/models stay in its `Data` folder.

Keep these results separate from CI's generated-speech test. Do not attach private recordings or transcripts to public bug reports.
