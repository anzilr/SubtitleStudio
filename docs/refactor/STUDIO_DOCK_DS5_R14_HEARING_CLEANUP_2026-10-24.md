# SubtitleStudio — DS5 R14 Hearing-Impaired Annotation Cleanup

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Scope

Bring the established mobile **Remove Hearing Impaired** tool into the sole
desktop Studio Dock editor without inventing an alternative parser or persistence
path. Mobile uses `HearingImpairedCleanupService.execute`, which commits the
entire cleanup through `CheckpointHistoryTransaction`.

## Desktop interaction

- Tools menu and Tools panel display the operation for editable live projects
  with at least one cue.
- A departing Tools popup is fully dismissed before opening any confirmation.
  The common unsaved-edit gate applies to both entry points.
- Confirmation describes bracketed text, descriptions, music/sound effects,
  speaker labels, and cue deletion when the cleaned source text is empty.
- After confirmation, Studio Dock checks its loaded cue snapshot against the
  current repository state, then calls the shared transaction and reloads all
  cues, mark/review fields and checkpoint history.
- Preserve the selected cue where possible, otherwise choose a surviving
  position. A project with no remaining cues stays empty.
- Only source subtitle text is cleaned. Existing translated text, timing,
  marks, comments and resolution on surviving cues follow the shared mobile
  service's rules. Deleted cues, including any attached annotation data, are
  removed as part of that operation. The source SRT file is not overwritten.
- The mobile confirmation now correctly states that Undo is available through
  editing history; the service and mobile UI layout are otherwise unchanged.

## Validation

Widget tests cover read-only/empty projects, menu cancellation, confirmation,
unsaved draft cancellation, Tools panel access, refresh and failure. The shared
cleanup plan test covers surviving translation, timing and review annotations.
Run Flutter pub get/analyze, focused Studio Dock suite, and full Flutter suite
on GitHub Actions; never build native platforms in CI.

Native Windows acceptance is deferred: test large projects, multi-delete
selection reconciliation, undo/redo, UI focus, and actual file export later.
MSone submission is unrelated and must remain available under its existing
feature flag; do not submit test data to the live service.
