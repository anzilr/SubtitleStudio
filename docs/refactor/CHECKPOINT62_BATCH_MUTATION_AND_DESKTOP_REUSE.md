# Checkpoint 62 — Batch mutation safety + desktop reuse boundary

Branch: `refactor/riverpod-architecture`
Date: 2026-10-12
Last verified baseline: Checkpoint 61 R2 `e42b411`, analyzer clean, 209 passing tests.
Status: implementation committed; analyzer/test quality gate pending.

## Atomic batch operations

- Added `SubtitleRepository.updateMultipleLinesWithHistory`, a session-scoped
  sparse batch mutation method.
- Input includes original preview snapshots per 1-based cue ID and requested
  replacement lines. The method verifies positive unique IDs and presence in
  the preview before starting a mutation.
- Each affected cue is re-read and verified **inside the V2 Isar transaction**.
  A stale, deleted or renumbered target aborts the whole batch.
- Generates strict positional `modify` deltas and one post-operation history
  commit for each changed batch; unchanged batches do not emit new commits.
- Unaffected cue state comes from the live collection, not from an outdated UI
  list, so unrelated concurrent edits survive.

## Call-site migration

- Live Subtitle Sync sheet -> all-cue time shift / framerate conversion calls
  pass session ID and expected original snapshots.
- Selected-cue sync supports the same history-aware API when session ID is
  supplied; sessionless callers retain a legacy fallback while migrating.
- Updated time-shift DTOs preserve marks, comments and resolution flags;
  previously several sync helpers constructed replacement lines with only
  timing and text fields.
- Live Malayalam normalization sheet passes previewed original targets,
  session scope and normalized replacements, producing an undoable V2 commit.
- Session context is threaded through `edit_menu_actions`,
  `edit_tool_sheets`, and tool widget constructors without visual changes.
- Legacy `updateMultipleLines` is now **all-or-nothing** even before full
  removal: invalid/duplicate/missing cue IDs fail without partial writes.

## Integration regression suite

`test/checkpoint_batch_edit_migration_integration_test.dart` covers:
- V2 normalization round-trip including marks/comments and exact undo/redo.
- Stale target rejection of the entire batch.
- Unrelated concurrent edit preservation.
- Missing cues, duplicate IDs, and foreign session rejection.
- Timecode sync preserving annotation fields and valid history.

Additional existing persistence tests cover duplicate and missing cue rejection
for legacy sparse batch writes.

## Desktop workspace architecture findings

See [DESKTOP_WORKSPACE_REUSE_AUDIT_2026-10-12.md](DESKTOP_WORKSPACE_REUSE_AUDIT_2026-10-12.md).

The shared Riverpod `EditController` / `EditState` and repositories can be
reused across PC and mobile. `EditorVideoPane`, `VideoPlayerSection`,
`WaveformWidget` and `SourceViewPane` are composable primitives, but
`SubtitleCard`, `CheckpointSheet`, modal presentation functions and
`_EditScreenState` extension methods are **not** a drop-in dense desktop
workspace. The existing `EditScreenHost` always renders the legacy
`EditScreen`; extract a shell boundary before desktop implementation.

**Desktop rollout guard:** physical desktop platforms get a new workspace
shell; Android/iOS continue using unchanged mobile routes and widgets.
Shared command/controller/repository paths must not be forked.

## Deferred

- Remaining legacy raw collection writes and generic saveCollection entry
  points, plus older sync/effects/waveform compatibility APIs.
- Desktop shell, grid and inspector widgets (not implemented in this checkpoint).
- Persisted HEAD/bookmark/branch ref schema and history graph visualizer.
- Real-device/native builds and archived .msone/Isar fixtures.

No changes to Isar schema, mobile screen visuals, upstream, release tags, or
native platform CI in Checkpoint 62.
