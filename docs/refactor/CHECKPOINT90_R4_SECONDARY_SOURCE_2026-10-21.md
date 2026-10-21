# SubtitleStudio — CP90 R4: Explicit secondary subtitle source

Date: October 21, 2026
Branch: `refactor/riverpod-architecture`
Verification: Linux Flutter analyzer/full suite passed

## Problem and extraction

The Riverpod Editor controller previously guessed whether secondary subtitles
came from the primary original text by comparing only the first subtitle's
text. External tracks can share that first cue, and original-text overlays
could become stale whenever hidden. UI callbacks also passed only parsed
secondary cues, discarding the source selected by the user. The two "Use
Original" sheets dropped blank cues before reaching the player.

The new pure `EditorSecondarySubtitleService` explicitly models three source
values (`none`, `originalText`, `external`) and projects every primary cue,
including deliberately empty originals and whitespace. `<br>` is decoded to
video-overlay newlines as before in the load-sheet path. `EditState` carries
the source separately from the visibility flag. The controller's primary-line
refresh and local-replace/update paths share the same projection operation:

- Original-text source: regenerate secondary cues after primary changes,
  regardless of whether the overlay is visible.
- External source: retain the user-loaded track unchanged; no first-cue
  comparisons or inferred origin.
- No source: do not synthesize secondary data.

The secondary load sheet, Project Settings and Edit Line callback contract now
reports `fromOriginal`; in-memory Editor initialization and the direct
secondary subtitle controller methods update the same origin field.

No Isar schema, checkpoint, raw Source View, file URI/Safari grant, native
video lifecycle, or mobile layout changes are involved. This is a shared-core
state change usable later by the desktop workspace.

## Regression plan

`test/editor_secondary_subtitle_service_test.dart` verifies blank and
whitespace cues, timing/index preservation, legacy line-break conversion,
hidden original refresh policy, external first-cue equality, the no-track
state and state copy/equality semantics. [Linux GitHub Actions run
39657803545](https://github.com/anzilr/SubtitleStudio/actions/runs/39657803545)
passed **666 Flutter tests with zero analyzer issues**. Windows/macOS host checks
are reserved for platform-sensitive file/path/save/import/encoding changes;
no platform builds are allowed in GitHub Actions.

## Deferred acceptance

- Native player overlay behavior and Android Back interaction require device
  testing, separate from pure Riverpod regressions.
- The media_kit native hot-restart SIGSEGV remains unresolved and outside this
  state-only refactor. Avoid hot restart in native QA.
- Continue CP90 Editor/media boundary cleanup, CP91 visual checkpoint history,
  CP92 targeted cleanup/performance and CP93 native acceptance before the
  desktop preview becomes a production editor.
