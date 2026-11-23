# Third-party notices

Mumble is derived from Handy by CJ Pais and contributors, released under the MIT license.

- Original source: https://github.com/cjpais/Handy
- Baseline: v0.9.8, commit 14f6f0d31cb22a4268acfbddba3052820fd0a06e.
- Original copyright: Copyright (c) 2025 CJ Pais.
- The full MIT notice is retained in LICENSE and included with app distributions.

The dictation implementation comes from that project. Mumble changes branding, application identity and release configuration. It does not claim original authorship of the upstream implementation.

Speech engines, keyboard libraries and other dependencies retain their own names, copyrights and licenses. See Cargo.toml, Cargo.lock, package.json and bun.lock for dependency identities. Downloaded speech models have separate licenses provided by their publishers. Technical model download hosts remain unchanged in this first preview.

The rounded “m” voice-wave mark is an original Mumble asset. The accent values match the Grove theme in T3 Code.

English number parsing uses text2num 2.8.0 by Groupe Allo-Media and its daachorse dependency under the MIT license. Their full notices are bundled as `text2num-LICENSE` and `daachorse-LICENSE-MIT` in the app’s licenses directory.
