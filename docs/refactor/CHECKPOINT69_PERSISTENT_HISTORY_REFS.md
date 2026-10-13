# Checkpoint 69 — Generated Isar HistoryRef schema and persistence foundation

Date: 2026-10-13
Branch: `refactor/riverpod-architecture`
Verified code/CI marker: `fd958dc6c642529ae5d587c116276e1bc8d2838e`
Baseline: Checkpoint 68 R2, analyzer clean, 266 tests.
**Verified Checkpoint 69 R3:** zero analyzer issues, **272 tests passed**.
CI: https://github.com/anzilr/SubtitleStudio/actions/runs/38442741186

## Schema generated in GitHub Actions — no user-side generator needed

- Added additive `@collection HistoryRef` to `lib/database/models/models.dart` with
  `sessionId` (indexed), `subtitleCollectionId`, `name`, `kind`,
  `targetCheckpointId`, optional `symbolicBranchName`, `schemaVersion`
  and created/updated timestamps.
- Added `.github/workflows/isar_schema_codegen.yml`, a narrowly triggered
  pinned Flutter 3.47.5 `build_runner` workflow. It generated and committed
  `lib/database/models/models.g.dart` automatically as `5921069`.
  The workflow commits *only* the generated Isar model file.
- Both production `lib/main.dart` and `TestIsarHarness` now open
  `HistoryRefSchema` alongside the older schemas.
- Successful generator run:
  https://github.com/anzilr/SubtitleStudio/actions/runs/38440954427

## Persistence and migration

New `HistoryRefRepository` owns additive persisted references and supports
lazy migration within an Isar write transaction:

1. For a session without refs, validate its full checkpoint graph using the
   read-only migration planner from Checkpoint 67. Invalid V2 HEAD or missing
   parent fails without writing refs.
2. Normalize multiple/no active legacy flags only when the migration plan
   requires it and atomically create HEAD, main branch, alternate leaf refs
   and manual checkpoint bookmarks.
3. If refs already exist, verify their target ownership, schema version,
   unique names, single HEAD, and any attached branch/HEAD target agreement
   instead of silently regenerating or overwriting them.
4. HEAD/main refs advance in the same transaction as both direct checkpoint
   commits and V2 edit transactions. Legacy `isActive` flags remain the
   compatibility mirror in this milestone.
5. Existing checkout semantics continue to advance main along with HEAD
   until user-facing *named branch switching* and complete custom-name
   import/export semantics are implemented. `HistoryRef.symbolicBranchName`
   reserves the future attached/detached distinction but is not yet an
   exposed user action.
6. Pruning protects all persisted branch and bookmark targets with their
   parent chains; it may exceed `maxCheckpoints` when those refs need to
   remain. Deleting a session's checkpoint history deletes refs in the
   same transaction.
7. Replacing a project deletes prior refs and history atomically, and
   reconstructs new refs after imported checkpoint IDs have been assigned.
   A prior portable `.msone` `historyRefs` section remains strictly
   validated; this milestone persists reconstructable derived refs.

## Verification

- Flutter analyze: **0 issues**.
- Serialized Flutter tests: **272 passed**, 6 more than checkpoint 68.
- New Isar tests: legacy HEAD normalization and migration idempotency,
  transactionally synchronized HEAD/main updates, checkout, foreign ref
  rejection, branch-tip retention, atomic deletion.
- An actual file-backed upgrade test opens an Isar database with the **old
  schema list**, writes real Session, SubtitleCollection, and Checkpoint
  rows, closes it, reopens with `HistoryRefSchema`, and verifies the
  previously stored subtitle data survives and refs migrate.
- Note: this runtime-generated pre-upgrade fixture is **not** yet the same as
  testing every published version's archived production database. Those real
  user backups/fixtures and five native platform builds are a later release gate.
- First test iteration exposed old pruning test expectations; these were
  changed to enforce the new persistent-reference retention contract.
  R2 revealed a missing Isar query extension import in the test; R3 is clean.

## What is NOT finished yet

- User APIs for creating, renaming, deleting or checking out named branches
  and independently lightweight bookmarks.
- Detached HEAD and `HEAD` symbolic branch-switching behavior.
- Full export/import of arbitrary user-named refs and `symbolicBranchName`
  through `.msone`, with all target ID remaps and rollback tests.
- Retention UX/quotas for pinned branches, explicit branch deletion policy,
  broken ref recovery UI, and storage usage warnings.
- Real user-database backup fixtures, final native-platform build gates.
- Expanded SRT encodings and waveform improvements from the attached KDE
  Subtitle Composer research; deferred desktop workspace redesign.

## Next proposed checkpoint

Checkpoint 70: protected named branch/bookmark management APIs, atomic ref
operations, checkout and retained-history invariants, and portable project
archiving of custom labels before presenting a branch editor UI. Continue
keeping the mobile interface unchanged while the shared history backend
stabilizes.

No production user files were touched. No native builds, upstream merges,
main branch changes or release-tag changes.
