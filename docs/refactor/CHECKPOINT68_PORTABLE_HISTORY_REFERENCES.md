# Checkpoint 68 — Versioned portable history refs in .msone projects

Date: 2026-10-13
Branch: `refactor/riverpod-architecture`
Starting verified baseline: Checkpoint 67, analyzer 0 issues, 258 tests passed (CI marker `cac51c3`).

**Verified Checkpoint 68 R2:** code/CI marker [`b16793a`](https://github.com/anzilr/SubtitleStudio/commit/b16793a1c4e240e6056f2503557700ae8882bf82), **0 Flutter analyzer issues**, **266 tests passed**, [GitHub Actions run 38439105267](https://github.com/anzilr/SubtitleStudio/actions/runs/38439105267). The initial CI attempt caught a malformed automated insertion in the codec; it was corrected and the successful R2 run verified the final code. 

## Scope and why this is staged

Checkpoint 67 prepared a read-only deterministic ref migration plan. The
next full Git-style ref feature requires an additional Isar `HistoryRef`
collection, updated generated `models.g.dart`, archive migration and
legacy database compatibility. The installed tooling in this checkpoint
cannot safely regenerate the Isar code. Shipping a handwritten or
ungenerated schema would break analyzer/native builds.

Checkpoint 68 therefore implements **the portable archive contract first**
and retains the current generated Isar schema and mobile UI unchanged.

## Implemented

- `ProjectHistoryReferenceData` / `ProjectHistoryReferencesData`
  are typed optional `.msone` sections named `historyRefs`, with
  `schemaVersion: 1` and `entries` of
  `{ name, kind, targetCheckpointId }`.
- Strictly validates schema version, positive checkpoint IDs, names,
  ref kind/namespace correspondence, duplicate names, path traversal,
  and exactly one HEAD when nonempty.
- `ProjectDocumentCodec` reads/writes the **optional** historyRefs section
  and excludes it from legacy extra-field handling; old `.msone` files
  without refs decode without creating any bogus HEAD entries.
- `ProjectDocumentBuilder` writes logical refs derived from the validated
  checkpoint graph: HEAD, `refs/heads/main`, alternate tip references,
  and bookmarks for existing `manual` checkpoint commits.
- `ProjectHistoryReferenceImportPlan` runs **before either project
  import transaction**. It requires the declared archive refs to match
  the deterministically derived graph, rejecting corrupt/missing targets
  and custom names that could not yet be preserved.
- Both project-import paths remap verified references from source
  checkpoint IDs to new Isar IDs *inside* their existing transactional
  checkpoint import. Those refs are currently validated, **not stored in
  a separate Isar reference table**. HEAD semantics remain stored in
  `Checkpoint.isActive`; branch leaves/manual snapshots are reconstructable
  from the saved checkpoint graph.
- For unsupported true user-named branches, fail closed with a clear
  message and allow subtitle-only recovery, rather than silently lose
  named reference metadata.

## Tests

- Codec round-trip, optional-field backward compatibility, invalid
  schema versions, wrong kinds, reserved/path-unsafe names, duplicated HEADs.
- Builder exports versioned HEAD and `refs/heads/main` references.
- Existing real-Isar typed import test now includes explicit portable
  reference targets and remaps the checkpoint IDs.
- Pure import guard accepts known derived refs and rejects incorrect
  HEAD, unknown branches, wrong targets, or refs without checkpoints.
- The preexisting importer/undo/redo/validation tests remain unchanged.

## Explicit limitations

- These are **portable derived refs**, not user-editable durable named
  branches, detached HEAD or independently persisted lightweight tags.
- The auto-generated `alternate-<id>`/manual identifier may be different
  after import when checkpoint IDs are reassigned. Custom names are
  deliberately refused until the real reference table exists.
- An old application version may ignore unknown JSON sections if it reads
  a new file. Avoid using this portable extension to promise backward
  preservation of future user-defined labels.
- The durable `HistoryRef` Isar schema, generated code, DB migration,
  delete/retention protections for named refs, session deletion and full
  export/import of user-defined refs require subsequent checkpoint work.

## Next checkpoint

Implement the durable Isar ref schema only with an environment capable
of running `build_runner` and verifying generated code, opening real old
database fixtures, import/replace/delete rollback and real platform build
compatibility. Continue to defer desktop UI. Encoding expansion and
waveform improvements remain separately tracked research-informed items.

CI quality gate: `flutter analyze` and `flutter test -j 1`, one deliberate
checkpoint trigger. No native builds, no changes to upstream/main/tags.
