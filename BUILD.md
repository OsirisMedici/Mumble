# Building Mumble

Use Bun and stable Rust with the macOS Command Line Tools and CMake installed. Apple Silicon release builds use the native Metal backend. Intel builds require the matching ONNX Runtime dynamic library, configured by the release workflow.

The Apple Intelligence bridge also builds with standalone Command Line Tools when their SDK includes FoundationModels. Its structured response type uses explicit `Generable` conformance so it does not depend on Xcode's macro plugin. Older SDKs retain the unavailable-provider stub.

```sh
bun install --frozen-lockfile
bun run build
bun run tauri dev
```

The voice activity model is included at `src-tauri/resources/models/silero_vad_v4.onnx`. Speech recognition models download on first use; model weights and personal transcripts are not bundled or committed.

## Checks

```sh
bun run lint
bun run format:check
bun run build
bun run test:keyboard
bun run test:settings
cargo clippy --locked --manifest-path src-tauri/Cargo.toml
```

## Mac release

```sh
bun run tauri build --target aarch64-apple-darwin --bundles app,dmg -- --locked
```

The GitHub Actions workflow builds Apple Silicon and Intel apps, verifies their bundle identities and code signatures, checks native compute-device startup, and uploads archives with checksums. The release job publishes downloads only after all jobs pass. Published previews are ad-hoc signed and not notarized. Apple notarization requires a maintainer's Developer ID setup.

The displayed app name is `Mumble`. For compatibility with existing installations, the app identity remains `com.osirismedici.karenvoice`, the executable is `karen-voice`, and the data directory is managed by Tauri under that identity. The legacy identifier, executable name, theme storage key and portable marker remain stable so existing settings, models and recordings stay accessible. Repository links continue to point to `OsirisMedici/karen-voice`. The app and interface use the rounded Mumble “m” mark.

## Branding

The Mumble vector icon lives in `assets/icon.svg`. Its rounded “m” follows the voice-wave logo concept and matches `VoiceMark.tsx` in the interface. Regenerate platform icons with `bun run tauri icon assets/icon.svg`. Shared UI and recording-overlay accents live in `src/styles/theme.css`; their light and dark accent values match the Grove palette in T3 Code.

After replacing an ad-hoc signed preview, macOS can retain the previous build's Accessibility signing requirement even while its switch shows enabled. If the app stays on “Permissions Required”, remove only its old Accessibility entry and add the exact installed app again. This resolved the stale approval after the Mumble rename; toggling the old entry alone did not.

## Verify real speech recognition

In GitHub Actions, run **Verify built-app transcription** and provide the successful Mac build run ID. This downloads the exact Apple Silicon app artifact, verifies its archive and signature, downloads a pinned public model with a SHA-256 check, and transcribes generated speech. The model stays on the disposable runner and is not included in the release.

This checks the real speech engine. Microphone capture, Accessibility permissions and paste into another app remain separate user acceptance checks.
