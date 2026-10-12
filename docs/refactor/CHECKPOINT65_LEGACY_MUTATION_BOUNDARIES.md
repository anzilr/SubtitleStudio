# Checkpoint 65 — Legacy line-mutation boundaries

Date: 2026-10-12
Branch: `refactor/riverpod-architecture`
Starting verified baseline: Checkpoint 64 R2 (`1e39a1e`), zero analyzer issues, 235 tests passed.

## Changes

Checkpoint 64 blocked *full-collection* compatibility writers from bypassing
Git-inspired V2 checkpoints. This milestone extends that protection to the
remaining direct, sessionless line mutation methods, including dormant methods
that external integration callers may still invoke.

- `SubtitleRepository`: sessionless `updateMultipleLines`,
  mark/comment/unmark/resolve, delete, add, split and merge are guarded
  **inside their Isar write transaction**.
- `EditLineRepository`: sessionless `updateSubtitleLine`, add/delete,
  mark/comment/resolve are guarded inside their Isar write transaction.
- The old `updateSubtitleLine` previously read and mutated the collection
  *before* starting its transaction, allowing stale writes even without a
  checkpoint. Its read/validate/update now execute in one transaction.
- `SubtitleRepository.syncSourceViewToDatabase()` refuses the sessionless
  fallback on V2 history; the active Editor passes its session ID to the
  existing history-safe writer.
- `WaveformSubtitleRepository.updateLines()` likewise refuses its
  compatibility-only sessionless write on V2 history; active waveform UI uses
  `updateLinesWithHistory()`.
- Shared `LegacyCollectionWriteGuard` makes the distinction from a
  checkpoint's post-operation V2 metadata for the destination collection.
  **On V2 projects, callers must provide a valid session and use the existing
  V2 mutation APIs.** Legacy unversioned/v1-only data remains supported.

## Regression tests

`test/legacy_mutation_boundary_integration_test.dart` verifies:
- All Editor legacy mutations refuse an existing V2 history, leaving lines
  and active HEAD unchanged.
- Edit Line legacy line editing, insert/delete and annotations refuse a V2
  document, leaving its history intact.
- Sessionless waveform timing does not mutate a V2 document.
- Legacy-only data retains compatible raw editing and annotation paths.

The existing separate V2 integration suites continue testing legitimate
session-scoped editing and undo/redo.

## Encoding expansion requirement added to roadmap

The user requested **more SRT encodings for both parsing and compiling**.
The top of `REFACTOR_ROADMAP_V4.md` now explicitly tracks:
- Symmetric decode/encode, not just a longer encoding dropdown.
- UTF-8 and UTF-16 BOM and endian handling, ASCII, Latin-1, Windows-1252 and
  feasibility-checked regional encodings such as Arabic/Cyrillic/East Asian.
- An explicit override and preview for uncertain detection, lossless
  round-trip coverage, and explicit warnings for unrepresentable characters.
- File picker/SAF and five native platforms, plus compatibility with .msone.
- Specific existing flaw to address: Latin-1 fallback precedes Windows-1252,
  and the compiler silently falls back to UTF-8 for unsupported labels.

This encoding requirement is **planned, not implemented in Checkpoint 65**.

## Deferred
- The new desktop workspace layout and widgets.
- Dedicated persisted history HEAD, named branch and bookmark refs and the
  branch-aware history UI.
- Additional real archived v1/.msone fixture compatibility and native
  cross-platform verification.
- Removal of dormant compatibility methods requires an end-to-end caller audit,
  and should be performed after legacy import fixtures are available.

CI for Checkpoint 65: `flutter analyze` and `flutter test -j 1`, run only
at the milestone marker. No native builds, upstream/main merges, release tag
edits, or mobile layout changes.
