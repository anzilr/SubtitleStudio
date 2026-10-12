# Checkpoint 60 — Live editor mutation migration

Date: 2026-10-12
Development branch: `refactor/riverpod-architecture`
Verified starting baseline: Checkpoint 59 R2, commit `f3dbcd4`, 194 tests passed, analyzer clean.

## Changes implemented

### Transaction-level guard
- `CheckpointHistoryTransaction.commit()` checks the session exists and owns the subtitle collection **inside the Isar transaction**. This prevents mismatched session/collection pairs from creating misleading history.
- The guard is applied to all modern atomic editing paths, including editor and waveform changes.

### Active editor paths
- Mark/unmark, comment, comment-resolution, and clear-comment changes use `CheckpointLineMetadataService` with an exact `modify` delta and post-operation history.
- Main Editor controller live add/delete actions now call `addLineWithHistory` and `deleteLineWithHistory`.
- Edit Line controller live add action uses `addSubtitleLineWithHistory`.
- Edit Line controller direct Save action now uses `saveSubtitleLineChanges`, retaining mark/comment/resolution fields.
- Live Source View saves run reconciliation and strict positional delta generation within `CheckpointHistoryTransaction`, generating a single complete post-operation snapshot per changed document.
- A no-op annotation does not make an extra commit.

### Tests
- Real Isar integration for four annotation actions with checkout/redo.
- Session ownership mismatch rejected without mutation.
- V2 add/delete and Edit Line annotation/add operations undo to exact initial state.
- Source View bulk reorder/insert/edit becomes one history snapshot, with full undo/redo validation.
- Pure index-diff replay covers shrink, grow, delete-all, add-first and no-op.

## Deliberately deferred
- Legacy repository APIs remain for older extension/test callers that do not provide a session ID; active screen controllers now pass session scope where migrated.
- Legacy pre-operation `CheckpointManager.create*Checkpoint()` methods are kept for on-disk v1 histories and existing migration tests. Removing or replacing them requires auditing all possible integration callers and existing history fixtures.
- Sessionless raw collection writes elsewhere (project comment import, generic updateCollection and some older waveform/library APIs) are not yet wholly migrated.
- Bookmark/reference schema, history graph UI, retention compaction, and real archived .msone fixture migration remain subsequent checkpoints.

## CI contract
Run analyzer and serialized tests only at the Checkpoint 60 marker. Do not build five native platforms or merge upstream/release branches until a deliberate integration gate.
