# SubtitleStudio — CP92 R7: Proven-unused compatibility shims

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Changes and evidence

- Removed `SubtitleImportResult.fromLegacyMap` and `toLegacyMap`.
  Repository-wide usage search found only two old tests calling the converter;
  production `SubtitleImportRepository` already returns a typed
  `SubtitleImportResult` with `Session` and `SubtitleCollection` directly.
  Replaced those tests with typed-contract checks for existing and newly
  imported session state.
- Removed the deprecated Dart-only `SafFileHandler.openFileUriOnly` forwarding
  method. Its sole caller, the Android URI-only video picker, now calls
  `SafFileHandler.openFile`. The existing `openFile` implementation already
  invokes Android's `openFileUriOnly` method channel. The Kotlin `openFile`
  and `openFileUriOnly` handlers both delegate to the same URI-only document
  picker; no content is read eagerly.
- Added a small source-contract test that guards the typed import boundary,
  Dart picker dispatch and unchanged Android URI-only channel wiring.

## Compatibility decisions

- **Retained** persisted `.msone`/checkpoint V1/V2 adapters, history HEAD and
  reference repair, Isar schemas/ID mapping, encoding aliases, Android
  document URI and grant handling, cached waveform V1/V2 files, and user
  saved preferences: these are real backward-compatibility surfaces.
- **Retained** the native Android `openFileUriOnly` channel and the public
  `FilePickerSAF.pickFileUriOnly` API, which is actively used by video picker
  callers. The removed Dart alias never represented a separate operation.
- No file parser, Isar model, migration, serialization format, FFmpeg path,
  widget layout, or media lifecycle was changed.

## Verification

- Local repository-wide usage scans and `git diff --check` completed.
- Final Linux GitHub [Flutter quality gate 39948838690](https://github.com/anzilr/SubtitleStudio/actions/runs/39948838690)
  **passed 785 Flutter tests, zero analyzer issues**. The test count adds
  two compatibility source-contract checks relative to the 783-test R6 gate.
- Verified code commit: `bcfad76bda19017684cdab7c0870843691aa0439`.
- Android/Windows/macOS/iOS builds and device tests: not performed in CI.

## Next

CP93 shared-core acceptance: complete automated quality gate, review legacy
project/encoding/import roundtrips, and prepare a focused Android/desktop
physical-device smoke checklist. Native desktop data/media integration remains
gated on CP93; appearance and progressive waveform experiments stay frozen.
