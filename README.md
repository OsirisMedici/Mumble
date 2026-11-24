# Mumble

Free, open-source dictation that runs on your computer. Press a shortcut, speak, and paste your words into the app you are using.

[Download the Mac preview](https://github.com/OsirisMedici/Mumble/releases) · [Report a problem](https://github.com/OsirisMedici/Mumble/issues)

## Download and start on Mac

1. Download the Apple Silicon DMG for an M-series Mac, or the Intel DMG for an Intel Mac. macOS 13 or newer is required.
2. Open the DMG and drag **Mumble** into Applications.
3. Launch Mumble. These early preview builds are ad-hoc signed, **not Apple notarized**. If macOS blocks opening, use System Settings → Privacy & Security → Open Anyway for the downloaded app. See [Apple's instructions](https://support.apple.com/en-us/102445).
4. Grant microphone and Accessibility access when prompted.
5. Download a speech model in the app. Try Parakeet V3 on Apple Silicon, or choose another model that fits your computer.
6. Set your shortcut, put the cursor in a text field, speak, and stop recording. The transcription appears there.

Quit other dictation apps while using the same shortcut. Mumble has its own settings and model directory, so another app's setup is not migrated automatically.

## Windows preview

Windows x64 builds target 64-bit Intel/AMD PCs. The **Windows preview** GitHub Actions workflow builds an NSIS setup executable and a portable ZIP, installs both on Windows, checks the packaged runtime files and transcribes generated speech using the installed app. Download the `windows-x86_64-pc-windows-msvc` artifact from a successful run. Tagged desktop releases include the same Windows files alongside Mac downloads.

Run the `windows_x64-setup.exe` installer, open Mumble, enable desktop microphone access in Windows Settings if needed, download a speech model, and choose a shortcut. Apple Intelligence is available only on supported Macs; local dictation and the Formatting options are shared. These Windows previews are unsigned. Windows ARM64 is not included yet. See [Windows setup and acceptance](docs/WINDOWS.md).

## What is included

- Local speech recognition with Whisper and ONNX models.
- Configurable shortcuts, hold-to-talk and toggle recording.
- Microphone selection, model management, transcript history and recording overlays.
- Light and dark themes with T3 Code Grove green accents.

This first release provides dictation. A connection to the Karen assistant and voice commands that perform actions are future work.

## Product inspiration

**Superwhisper is our primary product reference.** Its modes pair a speech model with optional text cleanup for a specific task. That fits Mumble's local dictation and gives us a clear direction for making optional formatting easier to use. [Superwhisper Modes](https://superwhisper.com/docs/modes/modes)

We also take inspiration from [Wispr Flow](https://docs.wisprflow.ai/articles/2772472373-what-is-flow), [Aqua Voice](https://aquavoice.com/guide), [Monologue](https://www.monologue.to/dictation), and [VoiceInk](https://github.com/beingpax/VoiceInk).

## Privacy and updates

Local dictation processes audio on your computer. Model downloads require the internet. Optional post-processing can send transcribed text to a provider you configure; it is off by default. Local history may contain sensitive text and audio, and you can manage it in Settings.

Preview releases use manual downloads from this repository. Automatic installation of updates is disabled until Mumble has its own signed update channel.

## Troubleshooting

If typing or shortcuts stop working, check microphone and Accessibility permissions for **Mumble**, confirm your shortcut does not conflict with another app, and try a normal text field. macOS Secure Input in password fields or another app can block keyboard listeners. Keep password fields closed while dictating. Logs and the app data directory are available in Settings → About.

## Build and contribute

See [BUILD.md](BUILD.md) and [CONTRIBUTING.md](CONTRIBUTING.md). Release automation builds macOS and Windows x64 previews. Linux source is retained, but Linux installers are not published or verified yet.

## License

MIT. The original copyright and permission notices are preserved in [LICENSE](LICENSE). See [third-party notices](THIRD_PARTY_NOTICES.md) for source provenance and dependencies.
