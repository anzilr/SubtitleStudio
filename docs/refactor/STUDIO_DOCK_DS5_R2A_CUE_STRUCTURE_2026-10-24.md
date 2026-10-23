# SubtitleStudio — DS5 R2a: Guarded cue insertion and deletion

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Implemented

- Studio Dock has Insert cue and Delete selected cue actions. A new blank project offers Insert first cue without navigating to classic Editor.
- The Insert dialog supplies canonical Start/End, Original and optional Edited text. Time order is validated before writing. Cancel does not persist an empty project, and a rejected commit keeps the draft open.
- Delete uses a confirmation dialog. After a successful structural edit, the entire cue list is refreshed and selection follows the renumbered timeline.
- Both commands use the existing V2 checkpoint transaction and snapshot persistence. New guarded repository entry points verify every displayed persisted cue inside the same transaction before positional changes. Concurrent modifications, insertions, deletions, and cross-session ownership errors fail closed.
- Existing mobile positional commands are unchanged. Single media player, waveform seek ownership, hotkeys, compact 43/13/44 layout and mobile interfaces remain unchanged.
- The unsaved Text/Timing popup guards insertion/deletion; waveform direct edits remain disabled until a separately guarded checkpoint.

## Tests and acceptance

- Integration: chronological insert/reindex, metadata preservation, deletion/reindex, stale snapshot rejection, wrong cue, invalid times, invalid owner, empty-to-one-to-empty and checkpoint history.
- Widgets: insert/cancel/validation/apply, failed-commit draft retention and retry, delete confirmation/renumbering, empty project insertion, and the unsaved-edit guard.
- GitHub Actions quality gates: `flutter pub get`, `flutter analyze`, and `flutter test` only; never native platform builds.
- Pending: native Windows interaction and media overlays after cue renumbering; DS5 R2b split/merge and further workflow commands; DS5 Save/Export.
