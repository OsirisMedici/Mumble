# Mumble first public preview

## Outcome

People can download a free Mac or Windows x64 dictation app, choose a local speech model, set a shortcut and put spoken words into the app they are using. The recognizable product name is Mumble, with green accents matching T3 Code's Grove palette.

## Included

Existing recording, speech recognition, paste, history, settings and overlay behavior. Separate bundle and data identity, original waveform branding, public source, Mac and Windows x64 downloads, reproducible CI, release checksums and required legal notices.

## Number formatting

Formatting contains an opt-in **Numbers as digits** setting for English dictation. It converts completed transcripts locally, including after optional Clean Dictation and on cleanup fallback. It supports number phrases, decimals, negatives, ordinals and Indian lakh/crore scales. For example, “twenty five” becomes “25” and “three point five million” becomes “3500000”. Existing installations keep their previous output until the setting is enabled. The page includes a local preview using the same native formatter; preview text is not saved.

## Spoken email formatting

Formatting also has an opt-in **Spoken email addresses** setting for English dictation. It recognizes “at the rate”, “attherate”, “at sign”, “at” and `@`, plus dotted domains and spoken local-part separators. “pranshi attherate gmail dot com” becomes `pranshi@gmail.com`; “john dot smith at company dot co dot uk” becomes `john.smith@company.co.uk`. It requires a spoken or written dotted domain and does not invent a missing `.com`. It runs before number formatting and again after optional cleanup. Already-written email addresses are preserved, including words in usernames and domain names. Existing installations keep it off until enabled.

## Deferred

Assistant chat, task execution, wake words, cloud accounts, automatic migration of another app's data, signed auto-updates, Apple notarization and Windows ARM64 and published Linux installers. The local speech model pipeline and model download services are retained from the baseline.

## Acceptance

1. Install the correct Mac build and open it as Mumble.
2. Grant permissions, download a model and choose a nonconflicting shortcut.
3. Dictate into a normal text field, cancel a recording, and repeat recording.
4. Confirm green branding in light/dark mode, the recording overlay and tray states.
5. Change a setting, relaunch and confirm it persists under the Mumble identity.
6. Confirm legal notices are bundled and all download/update links belong to this repository.

CI validates builds and native startup. Human microphone, Accessibility and real paste acceptance remains a distinct check. The absence of Developer ID notarization is disclosed in both the README and release notes.
