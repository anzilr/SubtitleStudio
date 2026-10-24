# SubtitleStudio — DS5 R5a: Studio Dock raw Source View

Date: 2026-10-24
Branch: `feature/studio-dock-integration`
Predecessor: `STUDIO_DOCK_DS5_R4C_PRODUCTION_NAMING_2026-10-24.md`

## Implementation

- Production Studio Dock has a **Source View** navigation-rail section, using
  the existing one-field `RawSrtEditor` and `RawSrtDocument.parseStrict`.
  The view remains plain SRT source text, not a graphical cue form. The
  shared theme tokens color the raw editor. Read-only sessions expose
  selectable source without an Apply action.
- The session host composes raw text from the authoritative loaded cue values
  (`storedEdited ?? original`), preserving intentional empty translations and
  interior blank lines. The demo-only entrypoint stays separate.
- Editing an existing Source View document uses
  `StudioDockSourceViewService` ->
  `SubtitleRepository.syncSourceViewFromSnapshotWithHistory` ->
  the existing `SourceViewReconciler` and `CheckpointHistoryTransaction`.
  The whole displayed cue list, including review/notes/nullable edited
  metadata, is compared with persisted state **inside** the history write
  transaction. A stale window cannot overwrite newer edits. One committed
  raw document creates one checkpoint snapshot; changes that do not alter
  stored subtitle fields avoid a redundant checkpoint.
- Invalid or empty documents fail validation before persistence, with raw
  draft text retained. Failed/stale commits also retain the draft. Successful
  commits replace the complete cue list and reload the canonical SRT text.
- Leaving Source View with unsaved changes requires **Apply / Discard /
  Cancel**. Project/file navigation, native Pop, and history navigation use
  the same draft confirmation boundary as existing inspector edits.
- The existing project file Save/Save As/Export services remain the sole
  filesystem writers and keep encoding/BOM/newline/file-permission policies.
  Applying Source View changes saves a checkpoint **inside the project**;
  it does not silently rewrite the external subtitle file.

## Regression acceptance

- `test/studio_dock_source_view_integration_test.dart`: exact composition of
  interior blank lines and empty edited text; one atomic bulk history commit;
  mark/comment preservation, insertion/deletion, stale cue/notes conflict,
  no-op and invalid document behavior.
- `test/studio_dock_source_view_widget_test.dart`: single raw editor, strict
  validation, stale-save draft retention, Apply refresh, Discard/Cancel and
  selectable read-only source.
- Run `flutter pub get`, `flutter analyze` and `flutter test` in CI only.
  Native desktop app builds are **not** CI jobs.

## Remaining

1. **DS5 R5b:** complete Style and Notes inspector integrations through the
   existing checkpoint services; integrate remaining search/tool panels.
2. **DS6 native acceptance:** Windows video/waveform follow/seek/controller
   visibility, 1366×768 and 1920×1080 layouts, theme contrast, native file
   dialogs, encoding/file round-trip, `.msone` reopen/history; macOS/Linux
   native smoke checks. Android/iOS UI and shared persistence must remain
   unchanged except for the backward-compatible guarded repository method.

## Accepted CI

- [Focused Studio Dock #40073038430](https://github.com/anzilr/SubtitleStudio/actions/runs/40073038430): **PASS**, analyzer clean, **108 tests passed**. Initial run #40072787062 exposed three widget-test frame-timing failures; the tests now pump after entering raw text before tapping the newly enabled Apply button.
- [Full Flutter repository #40073192564](https://github.com/anzilr/SubtitleStudio/actions/runs/40073192564): **PASS**, analyzer clean, **910 tests passed**.
- GitHub Actions ran `flutter pub get`, `flutter analyze` and `flutter test` only, with no application/platform builds. Native desktop acceptance is pending.
