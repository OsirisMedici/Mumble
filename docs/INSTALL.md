# Install Mumble

Official repository: <https://github.com/OsirisMedici/Mumble>.

Use the downloads from [v0.1.0-preview.2](https://github.com/OsirisMedici/Mumble/releases/tag/v0.1.0-preview.2). These are public release assets; no GitHub account or source build is required. Do not use an unrelated app with the same name.

## For an agent

Detect the operating system and CPU before choosing an asset. Read the matching script in `scripts/install/`, explain the destination, then run it within the user's installation request. Preserve settings and models. Do not disable Gatekeeper, remove quarantine flags, bypass SmartScreen, change PowerShell execution policy or auto-grant permissions. Tell the user when the operating system needs a click.

The scripts pin the preview tag and verify the asset against its release SHA-256 manifest before installation. This checks download integrity; the previews do not yet have Apple notarization or Windows Authenticode signing. Scripts do not launch the app, record audio or download models. They refuse to update while Mumble is running.

## Mac

Requires macOS 13 or newer. Use `aarch64-apple-darwin` for an M-series Mac, or `x86_64-apple-darwin` for Intel. The script also detects an Apple Silicon Mac when Terminal runs under Rosetta.

```sh
curl -fsSL https://raw.githubusercontent.com/OsirisMedici/Mumble/main/scripts/install/macos.sh -o /tmp/mumble-install.sh
# Optional: read the script before running it.
cat /tmp/mumble-install.sh
bash /tmp/mumble-install.sh
```

The default destination is `~/Applications/Mumble.app`. No sudo is needed. A previous app at that location is preserved as a timestamped backup. User settings and models stay in their existing data directory.

To check the download without installing, use `bash /tmp/mumble-install.sh --verify-only`. For another directory, use `--destination /path/to/Applications`.

For manual installation, download the matching DMG, open it, and drag Mumble into Applications. The ZIP contains the same app.

Mac previews are ad-hoc signed, not Apple notarized. If macOS blocks the first launch, use System Settings → Privacy & Security → Open Anyway for this app. Follow [Apple's instructions](https://support.apple.com/en-us/102445). Approve Microphone and Accessibility for the exact app you installed. If a replacement build keeps requesting Accessibility despite an enabled switch, remove its old entry and add the installed Mumble app again. Replacing ad-hoc signed builds can invalidate earlier approvals.

## Windows

Requires Windows 10/11 x64 on an Intel or AMD processor. Windows ARM64 is not included.

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/OsirisMedici/Mumble/main/scripts/install/windows.ps1 -OutFile "$env:TEMP\mumble-install.ps1"
# Optional: read the script before running it.
Get-Content "$env:TEMP\mumble-install.ps1"
& "$env:TEMP\mumble-install.ps1"
```

The default destination is `%LOCALAPPDATA%\Programs\Mumble`. The script runs the normal per-user installer and verifies the installed product name. It preserves app data. To check the download alone, add `-VerifyOnly`. To choose a different directory, add `-Destination 'C:\path\Mumble'`.

If script execution is restricted, download and run `Mumble_0.1.0_windows_x64-setup.exe` from the release page instead. Do not change the machine's execution policy. The unsigned preview may show a Windows security prompt; review the source and download before deciding whether to approve it. The installer supplies native runtime DLLs and handles WebView2 installation if needed.

For portable use, extract `Mumble_0.1.0_windows_x64_portable.zip` and open `Mumble\karen-voice.exe`. Keep the `portable` marker beside the executable. Its settings, models and recordings are stored in `Mumble\Data`; keep that directory when replacing the app.

## Verify a manual download

Download the matching manifest from the same release:

- Mac Apple Silicon: `SHA256SUMS-aarch64-apple-darwin.txt`
- Mac Intel: `SHA256SUMS-x86_64-apple-darwin.txt`
- Windows x64: `SHA256SUMS-windows-x64.txt`

On Mac, run `shasum -a 256 /path/to/download` and compare the full hash with the exact filename in the manifest. On Windows, use `Get-FileHash 'C:\path\download' -Algorithm SHA256`. Stop if the hashes differ. Native build reports are included as `Mac-verification-*.json` and `Windows-verification.json`.

## First launch and a short test

1. Open Mumble. Grant the requested microphone permission. On Mac, also grant Accessibility. On Windows, enable desktop-app microphone access in Settings if needed.
2. Download a model in **Models**. The download needs internet and disk space. Local dictation works offline after that download.
3. Choose a shortcut in **General**, and close other dictation apps that use it.
4. Open a normal text field. Record "This is my first Mumble test", stop, and check the text.
5. In **Formatting**, enable **Numbers as digits** and **Spoken email addresses**. Record "Send twenty five invitations to alex attherate example dot com". Check for `25` and `alex@example.com`. The model may vary capitalization and punctuation.
6. Cancel a recording, then record again. Relaunch Mumble and confirm the model and settings persist.

Do not use a password field for the test. The formatter's **Try it** preview checks text formatting alone; successful audio transcription and paste need the recording test above.

CI verifies packaged startup and speech recognition with generated audio. Live microphone capture, global shortcuts and paste on a particular desktop still need the user's test. [Report problems](https://github.com/OsirisMedici/Mumble/issues) with the OS, processor, model and steps. Do not attach private recordings or transcripts.
