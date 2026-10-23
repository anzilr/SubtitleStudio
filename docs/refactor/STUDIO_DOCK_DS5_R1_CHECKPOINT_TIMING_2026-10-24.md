# SubtitleStudio — DS5 R1: Checkpoint-backed inspector timing

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Scope

- Native Windows/macOS/Linux continue to use only Studio Dock; mobile screens and the existing full-size waveform remain untouched.
- The inspector Timing tab now accepts canonical `HH:mm:ss,SSS` Start and End values. Invalid components, ambiguous separators, and start-at/after-end are rejected before persistence.
- Apply commits both time values together through `SubtitleRepository.updateMultipleLinesWithHistory`, with an exact stored-cue comparison inside the checkpoint transaction. Original and edited text, mark, comment, and resolved metadata are retained.
- No-change Apply does not create a history entry. Concurrent edits are rejected while leaving the draft visible for correction.
- Apply/Discard and the existing unsaved-change popup guard cue switches, tab switches, and project/video/import navigation. Switching from Text to Timing also requires resolving an unsaved text draft first.
- Real playback and waveform remain attached to the same shared player. Waveform direct timing/add-line gestures remain disabled until their own checkpoint-backed commands are ready.

## Tests and pending acceptance

- Integration coverage: persistence, no-op, metadata integrity, invalid time formats, ordering, stale edits and missing cue IDs.
- Widget coverage: disabled Apply and error feedback on invalid time, Apply-only persistence, visible time update, and popup Cancel/Apply on tab switches.
- Gate: Flutter analyzer and focused Studio Dock tests, followed by full Flutter tests. GitHub Actions may run `flutter pub get`, `flutter analyze`, and `flutter test` only—never platform builds.
- Native Windows acceptance still requires visual/responsive timing inspector and real playback/waveform verification at desktop resolutions; DS5 R2 will address insertion/deletion through guarded history transactions and Save/Export in later steps.

## Focused CI result

- [Studio Dock Flutter quality #40033259224](https://github.com/anzilr/SubtitleStudio/actions/runs/40033259224) — passed, including analyzer and Studio Dock widget/integration regressions.
- Full repository regression is the next quality gate; it has not been substituted with a native build.
