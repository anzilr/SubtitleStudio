# Checkpoint 67 — Durable reference migration preparation and KDE source audit

Date: 2026-10-13
Branch: `refactor/riverpod-architecture`
Starting verified baseline: Checkpoint 66 (code/CI marker `4dd480b`, analyzer 0 issues, 248 tests passed).

## Implemented in this checkpoint

### Migration plan — deliberately read-only

- New `lib/services/checkpoint_reference_migration_plan.dart` defines a
  typed, non-persistent `PlannedHistoryReference` and
  `CheckpointReferenceMigrationPlan`.
- Builds an import/migration plan from existing checkpoints without changing
  `Checkpoint.isActive`, parent IDs or subtitle state.
- Strictly validates: positive unique IDs, one session and collection,
  existing parent links and acyclic parent graph; malformed V2 missing or
  duplicate HEADs fail closed.
- Legacy-only active paths select the same newest-active checkpoint as existing
  HEAD resolver; legacy histories with no active flags select the newest
  timestamp (ID tie-break). A `requiresLegacyHeadNormalization` indicator
  makes the required future write explicit instead of mutating in place.
- Plans a primary `HEAD` plus `refs/heads/main` pointer to that HEAD;
  alternate leaf tips get names `refs/heads/alternate-<oldId>`, and old
  manual checkpoint commits receive `refs/bookmarks/manual-<oldId>`.
- Exposes `remap(destinationSessionId, destinationCollectionId, idMap)`
  for project imports that allocate new Isar checkpoint IDs: reject missing,
  invalid, duplicate or extraneous mappings before future persistence;
  preserve user-facing ref names while rebasing all targets.
- Existing `CheckpointStore`, `CheckpointManager` and
  `CheckpointRepository` now expose
  `previewReferenceMigration(sessionId)`, a **read-only** API.
- Added pure tests plus real-Isar integration tests ensuring previews do not
  change legacy active flags, no destination session is written by remapping,
  and malformed V2 graphs remain untouched after rejection.

**Not yet implemented:** a new on-disk Isar `HistoryRef` collection,
persisted branch names, user-created tag/bookmark edits, branch switching via
symbolic HEAD, or any UI/desktop workspace changes.

## Proposed durable Isar schema contract for subsequent milestone

A future separate `HistoryRef` collection should own the following
logical fields (exact generator-friendly types and indices to be validated
against `isar_community_generator`):

- `id`: Isar auto-increment identity.
- `sessionId` and `subtitleCollectionId`: stable owning session/collection.
- `name`: unique reference path within a session; reserve `HEAD`,
  `refs/heads/*`, and `refs/bookmarks/*`. Disallow empty names, traversal,
  reserved-name collisions, and platform-unsafe names.
- `kind`: typed `head | branch | bookmark` discriminator.
- `targetCheckpointId`: required existing checkpoint ID in same session.
- `schemaVersion`: explicit reference-format version for future migrations.
- `createdAt/updatedAt`: dates for UX/audit where needed.
- `symbolicBranchName` or separate HEAD mode if supporting attached vs
  detached HEAD; do not infer branch attachment from a checkpoint timestamp.

### Required migration transaction

1. After opening an old Isar database with a **verified generated schema**,
   read the session's checkpoints and any ref records inside one transaction.
2. Verify the checkpoint history and HEAD using current validators. For
   corrupted V2 history, abort without writes and offer backup/recovery.
3. If no ref records exist, compute this deterministic preview; persist all
   refs and normalize legacy active markers atomically. Existing refs must
   not be overwritten or silently regenerated on subsequent startup.
4. Maintain compatibility between new refs and `isActive` during a measured
   dual-read/dual-write transition, with a single authoritative HEAD and CAS
   on every mutation and checkout.
5. Never reference a checkpoint deleted by retention. Protect all named
   branch/bookmark targets and their required ancestor graph; do not use
   "two newest tips" as the sole branch retention policy once refs persist.
6. On session deletion, replace-session, import-as-new and backup restore,
   delete/remap refs in the **same transaction** as checkpoints. Reject missing
   target IDs and cross-session references.
7. Extend the portable `.msone` document format via an optional,
   versioned ref section so old archives import unchanged. Remap reference
   targets after destination IDs are assigned. For new archives, export and
   import refs with an explicit schema version; validate before writes.
8. Test generator output, opening existing database fixtures, importing
   old projects, retry/idempotence after interruption, concurrent mutations,
   rollback on corrupt refs, and backup/restore. Never edit `models.g.dart`
   manually or add an ungenerated schema to production.

Checkpoint 67 stops *before* step 1's persisted migration, preventing an
untested Isar schema or `.msone` change from reaching the five platforms.

## User-provided KDE Subtitle Composer source research

Reviewed the attached `subtitlecomposer(1).zip`, not merely a web summary.
The full file-level audit is
[SUBTITLECOMPOSER_WAVEFORM_AND_ENCODING_SOURCE_AUDIT.md](SUBTITLECOMPOSER_WAVEFORM_AND_ENCODING_SOURCE_AUDIT.md).

- **Encoding**: ICU `ucsdet_detectAll` / KEncodingProber candidates, live
  decoder preview, language-grouped manual selection and explicit output
  codec with QSaveFile. Preserve exact BOM policy in our independent Dart
  implementation; do **not** copy its unconditional UTF BOM behavior or
  one-megabyte subtitle-text read limit.
- **Waveform**: progressive PCM decimation and per-channel buffering,
  on-demand/visible-range prioritized zoom aggregation, separate renderer,
  playhead-centered zoom, and start/whole/end cue drag modes.
- **Flutter comparison**: our current `AudioProcessor` uses FFmpeg PCM
  extraction and `ZoomBufferGenerator` eagerly computes all zoom levels;
  investigate bounded tiles, cancellation, cache invalidation and initial
  latency via benchmarks rather than replacing working waveform logic.
- **Licensing**: use C++ architecture as research only. Do not paste or
  port KDE GPL routines without verifying distribution implications.

Waveform and expanded SRT encoding remain **planned separate milestones**,
not implemented in Checkpoint 67. Desktop redesign remains deferred.

## Verification and release constraints

CI: `flutter analyze`, `flutter test -j 1`; no native builds, no Isar
schema/codegen change, no mobile UI change and no upstream/release branch edits.
The verification result is recorded after CI passes.
