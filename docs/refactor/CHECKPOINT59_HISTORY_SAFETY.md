# Checkpoint 59 — History checkout and project-import safety

Branch: `refactor/riverpod-architecture`  
Date: 2026-10-12  
Previous verified baseline: Checkpoint 58 R2, `9c45f17`, analyzer clean, 181 tests passed.

## Implemented

### Atomic checkout / undo / redo
- A checkout captures the observed HEAD and working-subtitle-state hash before reconstruction.
- The store re-reads HEAD and the collection **inside its Isar write transaction**. Changed HEAD or subtitle working-tree content aborts without writing anything.
- Checkout only modifies the fresh collection's subtitle lines; concurrent changes to filenames, URIs and other collection metadata are preserved.
- The target is re-resolved from the same transaction's session graph; wrong-session or missing target is rejected.
- Undo/redo pass their previously observed HEAD to the checkout operation, preventing stale navigation from silently advancing relative to a newer HEAD.
- Strict working-tree hashes intentionally detect concurrent subtitle edits that bypass history; a plain HEAD check cannot detect those external writes.

### .msone history import
- Preflight converts the imported graph into in-memory checkpoints and validates IDs, parent references, cycles, source-session/collection ownership, history version, v2 HEAD cardinality, v2 state hashes and reconstructability.
- A new or replacement session, its subtitle collection, checkpoint insertion, parent-ID remapping and HEAD selection are handled by **one Isar write transaction**.
- Replacement deletes its previous incompatible checkpoints in the same transaction rather than mixing histories.
- Invalid history is no longer silently discarded. UI asks whether to **cancel** or deliberately **import subtitles only**. The existing project remains unchanged when cancelled.
- Legacy exported histories with multiple active ancestry flags normalize to one newest HEAD; the application continues to accept v1 checkpoint semantics.

### Tests added
- Store integration: stale HEAD; altered working tree without HEAD movement; unrelated metadata preservation.
- Manager integration: undo/redo navigation with an expired HEAD observation.
- Project import integration: invalid graph refuses new import atomically, explicit subtitle-only recovery, failed replacement keeps old subtitles and history.
- Project graph unit tests: valid v2 SHA-256 state, tampered v2 snapshot, hash omission, multiple HEADs, invalid parents, unknown versions, cross-session ownership, legacy active paths.

## Remaining risks / following checkpoints

- All v1 editing paths are not yet converted to atomic v2 mutation transactions.
- `Checkpoint.isActive` is still a temporary persisted HEAD compatibility flag, not a dedicated `HistoryRef` record.
- `.msone` imported HEAD and working-tree reconciliation, large graph limits and malformed untrusted file size budgets need further testing.
- Bookmarks remain manual snapshot commits, not lightweight references; retention currently keeps ancestor chains and recent alternate branch tips, but has no validated compacting garbage collector.
- Legacy on-disk Isar migration and real exported `.msone` fixtures from older releases must be tested on copies of user files.
- CI analyzer and tests do not substitute for cross-platform runtime builds; preserve the planned final five-platform gate.

No Isar schema change or merge into upstream/release branches in this checkpoint.
