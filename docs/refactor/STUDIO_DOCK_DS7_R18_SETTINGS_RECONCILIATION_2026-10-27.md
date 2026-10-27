# DS7 R18 — App Settings reconciliation after Studio Dock

Date: 2026-10-27. Branch: `feature/studio-dock-integration`.

## Decision: source-file save preference

The mobile `saveToFileEnabled` preference remains functional. The mobile Edit
Line save first commits to Isar/history, then (when enabled) writes the SRT
through the existing direct-save path. Preserve this behavior and its schema.

Studio Dock now owns its explicit File > Save and Save As workflow; ordinary
edits commit to Isar/history for recovery without writing to the source file.
The old global Save to File toggle is therefore shown only in the mobile
Settings UI, with wording explaining its scope. Desktop Settings explain
File > Save instead. Do **not** wire mobile auto-write semantics into the
desktop editor unless a future, explicitly designed opt-in is requested.

## Cleanup

- Grouped Settings under Appearance, Editing & Playback, History & Storage,
  Integrations, Waveform Settings, and Support & Maintenance.
- Removed legacy two-pane Switch Layout from desktop Settings while preserving
  it on large mobile/tablet layouts that still use the mobile editor.
- Kept active checkpoint retention, snapshot frequency and strategy settings;
  clarified that protected branches/bookmarks can exceed the history target.
- Kept waveform performance options, standardized effective zoom multiplier
  default/reset to the existing generator fallback (1.25).
- Retained Gemini settings; explained desktop AI explanation entry is pending.
- Restricted Google Play update checks to Android, and surfaced failed manual
  checks rather than reporting a false "latest version" result.
- Reset All Settings now also resets Studio Dock layout keys and refreshes the
  live theme. All Data clears Git-like `HistoryRef` entries, Dock layout and
  session activity metadata, while preserving dictionaries and external SRTs.
- Narrowed temporary cache cleanup to waveform-generated PCM filename shapes;
  never recursively empty the OS temp directory.

## Verification

- Added coverage for Studio Dock SharedPreferences reset and preservation of
  unrelated SAF/activity preferences, waveform config reset parity, Isar
  history-ref wipe versus dictionary preservation, and temporary-file names.
- Run Linux full Flutter analysis and tests plus Studio Dock quality checks
  through CI. Do not run Android, desktop, or other platform builds in CI.
- Native Windows/Android visual and file-save acceptance still pending.

### CI acceptance — source commit `b339a6276937af319943e57868f961706bef7ce3`

- [Studio Dock Flutter quality](https://github.com/anzilr/SubtitleStudio/actions/runs/40448627262): **381 tests passed**, analyzer clean.
- [Migration quality checks](https://github.com/anzilr/SubtitleStudio/actions/runs/40448627231): **1,233 tests passed**, analyzer clean.
- Both workflows run only `flutter pub get`, `flutter analyze`, and Flutter
  tests; no platform builds were performed in GitHub Actions.

## Pending parity and format work

Keep ASS/SSA and WebVTT editing, plus Subtitle Edit feature parity and audio
timing generation, on the separate format/feature backlog. Studio Dock must
retain mobile feature parity; Gemini explanation entry is not yet exposed there.
