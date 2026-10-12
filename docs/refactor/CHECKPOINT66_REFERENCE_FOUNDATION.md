# Checkpoint 66 — Git-inspired reference foundation and atomic pruning

Date: 2026-10-12
Branch: `refactor/riverpod-architecture`
Starting verified baseline: Checkpoint 65 R3 (`3dbd0fa`), analyzer zero issues, 239 tests passing.

## What was implemented

### Typed reference catalog (read-only, no Isar schema change)

- New `CheckpointReferenceCatalog` produces the following logical names
  for one valid session's graph:
  - `HEAD` -> uniquely resolved active checkpoint.
  - `refs/heads/alternate-<checkpointId>` -> other leaf/branch tips.
  - `refs/bookmarks/manual-<checkpointId>` -> existing user-created manual
    checkpoints, including those on non-active branches.
- Reference kinds are typed as `head`, `branchTip`, `manualBookmark`.
  The catalog rejects duplicate IDs, cross-session/collection graphs, missing
  parents, and malformed V2 HEAD flags. Legacy multiple active ancestor flags
  still resolve the newest legacy HEAD.
- `CheckpointStore`, `CheckpointManager`, and `CheckpointRepository`
  expose a shared `getReferencesForSession` API. A future desktop/mobile
  history graph should consume this instead of querying raw active flags.
- **The names are currently DERIVED views, NOT persisted named branches
  or lightweight user-created tags.** Manual bookmarks remain normal manual
  checkpoint commits. No user-editable refs have been added yet.

### Strict HEAD semantics

- `CheckpointHeadReference.resolveForMutation` rejects both zero and
  multiple active HEADs when V2 history exists. Legacy-only empty active
  sets remain compatible.
- `CheckpointStore.getCurrentHeadCheckpoint()` reads and resolves the whole
  history through the shared resolver rather than simply returning the newest
  active row, which masked V2 graph corruption.
- `CheckpointStore.insertAsHead()` checks the expected HEAD against the
  full graph, validates the checkpoint's session/collection, and requires
  a parent equal to the expected HEAD. This prevents attaching an unrelated
  commit or silently accepting an invalid multiple-HEAD V2 graph.

### Atomic retention policy

- Before this checkpoint, cleanup computed its deletion candidates and HEAD
  outside the Isar transaction, then deleted those IDs later. A checkout or
  branch change between these actions could cause a newly protected HEAD or
  bookmark ancestor to be deleted.
- New `CheckpointStore.pruneSession(sessionId, maxCheckpoints)` reads the
  current graph, validates HEAD, computes `CheckpointPolicy.cleanupCandidates`,
  and deletes only permitted leaves **inside one Isar write transaction**.
- Both `CheckpointHistoryTransaction` and `CheckpointManager` now use
  the atomic pruning API.
- `deleteCheckpointIds` is intentionally unsafe for active histories and
  is blocked when an active HEAD is present. Pruning clients should not
  precompute checkpoint IDs outside the transactional store boundary.
- Retention policy remains unchanged: active HEAD ancestry, manual checkpoint
  ancestry and the two newest alternate branch tips are protected. Under
  this safety policy actual storage may exceed the user-configured limit.

## Tests added

- Pure ref catalog: HEAD, alternate tips, manual bookmarks, legacy active
  ancestors, invalid V2 HEAD, cross-session and broken parent validation.
- Real Isar: missing/duplicated V2 HEADs are rejected by store reads.
- Real Isar: transactional pruning preserves active HEAD, newest alternate
  tips, and recomputes references after HEAD moves.
- Direct deletion cannot bypass active HEAD retention.

## What's explicitly NOT completed

1. **Persisted HEAD/branch/bookmark reference table**: requires schema
   generation and migration of legacy `Checkpoint.isActive` and .msone
   export/import. Do not manually edit `models.g.dart` or create an
   incompatible schema without an explicit compatibility test phase.
2. User-defined branch names, rename/delete/ref switching, branch pinning
   and bookmarks pointing to existing commits without creating snapshots.
3. Branch-aware history graph and desktop workspace UI.
4. Expanded SRT character encoding (roadmap and
   `SRT_ENCODING_REFERENCE_RESEARCH_2026-10-12.md` already include KDE
   Subtitle Composer and Subtitle Edit references).
5. Native multi-platform builds and archived .msone/Isar recovery fixtures.

### Next checkpoint

Checkpoint 67 should design the durable reference schema and migration
boundary, and implement only after testing automatic Isar code generation
and older project-file compatibility. Keep the mobile UI unchanged and
postpone the desktop layout as requested.

Quality gate: `flutter analyze` and `flutter test -j 1` on CI marker
only; no native platform builds, upstream merges or release tag changes.
