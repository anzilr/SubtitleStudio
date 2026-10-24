# SubtitleStudio — DS5 R4c: Production workspace naming

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Why

The desktop editor has evolved from a layout prototype to the only production
desktop workspace, but its main Dart filenames and types still said `preview`
and `read_only`. Those names incorrectly described an editor that now supports
checkpoint-backed text, timing, cue structure, file Save/Export, project Save,
native media and history.

## Current production entrypoints

- `lib/desktop/workspace/studio_dock_desktop_home.dart` chooses and opens real
  subtitle/project sessions.
- `lib/desktop/workspace/studio_dock_session_view.dart` hosts an active session
  and connects shared repositories, media, files and history.
- `lib/desktop/workspace/studio_dock_workspace.dart` renders the native desktop
  workspace with `StudioDockWorkspace`, `StudioDockCue`, and
  `StudioDockCueUpdate`.
- `enableEditing` and `isLiveSession` replace the obsolete `enableTextEditing`
  and `liveReadOnly` constructor names.

The production workspace **requires explicit cues** from the real session
adapter. No built-in sample cues or hardcoded selected cue remain. An empty
project receives an empty list, so it cannot silently display demo subtitles.
Initial cue selection may be supplied explicitly and falls back to the first
existing cue.

## Development-only demo

The standalone fixture and entrypoint are in `tool/studio_dock_demo.dart`.
Run with `flutter run -d windows -t tool/studio_dock_demo.dart` for the old
isolated layout exercise. It never connects Isar or media and is **not** the
production editor. All example subtitle text lives there; demo tests import
it directly. `lib/main.dart` remains the production application entrypoint.

Historic DS1–DS3 documents preserve their original checkpoint names and
commands; use this document for the current paths. Real feature names such as
`studio_skin_preview.dart` and `subtitle_encoding_preview.dart` are retained:
they implement actual user-visible previews, not a deprecated app shell.

## Verification and next checkpoint

- CI: Flutter dependency resolution, analyzer and focused/full test suites
  only. No native application builds in GitHub Actions.
- Native desktop acceptance is still pending for waveform/video behavior,
  1366×768 and 1920×1080 responsive layouts, theme contrasts, file dialogs,
  and `.msone` reopen/history.
- **DS5 R5 next:** integrate Source View using existing SRT parsing,
  checkpoint transactions and encoding/file services; preserve unsaved drafts
  and never bypass shared history state.

This checkpoint changes names and separates fixtures; it does not introduce
new persistence or alter the mobile editor.

## Accepted Flutter CI

- [Focused Studio Dock quality #40070989138](https://github.com/anzilr/SubtitleStudio/actions/runs/40070989138): **PASS** — Flutter analyzer clean, **97 tests passed**.
- [Full repository quality #40071109612](https://github.com/anzilr/SubtitleStudio/actions/runs/40071109612): **PASS** — Flutter analyzer clean, **899 tests passed**.
- Both workflows used `flutter pub get`, `flutter analyze` and `flutter test` only; **no platform builds** were run.
