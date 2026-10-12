# Checkpoint 64 — Legacy writer audit and remaining live caller migration

Date: 2026-10-12
Branch: `refactor/riverpod-architecture`
Starting verified baseline: Checkpoint 63, code commit `8a67248`, analyzer clean, 223 tests passed.

## Key findings from source-level caller audit

### Live Find & Replace was still bypassing history
- `lib/widgets/search_replace_sheet.dart` used `SubtitleRepository.updateMultipleLines()` for both **Replace All** and **Replace Selected**. This wrote subtitle lines without a V2 history commit.
- When several selected matches belonged to the same cue, its old loop repeatedly replaced the *original match text*, keeping only the last selected replacement. It also cleared `_selectedIndices` before displaying the success count.
- Introduced UI-independent `SubtitleSearchReplacePlanner` that groups by cue, validates captured match spans, applies matches in **descending offset** order, and preserves original text, mark, comment and resolved flags.
- Captured search-result cues are copied when searching rather than retaining mutable UI line objects. Conflicting cue snapshots, invalid ranges and overlaps fail closed.
- Both replace operations use `updateMultipleLinesWithHistory` with original expected lines, session ID and operation type `replace`. The shared transactional writer rejects stale target cues.
- Successful replacement closes the modal to avoid operating on invalidated match offsets; the existing mobile layout is unchanged.

### Project encoding setting wrote stale subtitle collections
- `lib/widgets/project_settings/parts/project_settings_media_actions.dart` used `updateCollection(widget.subtitleCollection)` after changing encoding in the cached object, risking overwrite of newer edits.
- Introduced `SubtitleRepository.updateEncoding(collectionId, sessionId, encoding)`: verify session ownership and modify only fresh Isar encoding metadata inside the write transaction.
- Settings now checks the save result and updates its local encoding only after success. Encoding metadata is not a subtitle-state history mutation.

### Unsafe full-object writers are now guarded
- Added `LegacyCollectionWriteGuard` as a shared, transaction-scoped policy.
- `SubtitleRepository.updateCollection()` and `EditLineRepository.updateSubtitleCollection()` **reject** full-collection replacements after any V2 history exists for that subtitle collection.
- Legacy unversioned/v1-only data retains compatibility. A full-object replacement for a V2 document must instead use a targeted metadata setter or explicit session-scoped V2 mutation.
- This is intentionally narrower than deleting every old API; other legacy direct line-mutation entrypoints still need migration or a dedicated compatibility policy.

## Regression suite

- Pure planner: multiple case-insensitive matches in one subtitle, multiple selected matches, edited-field preservation, multi-cue batches, overlap and stale range rejection.
- Real Isar: grouped Find & Replace becomes one V2 edit, with exact undo/redo and valid history.
- Encoding: the change preserves newer subtitle edits; incorrect owners and empty values are rejected without writes.
- Repository guard: raw full-collection writes are rejected against an active V2 document (both editor repositories); the unversioned legacy path remains functional.

## Remaining legacy APIs / forward roadmap

**Compatibility-only** APIs still present include:
- `SubtitleRepository.updateMultipleLines`, `deleteLine`, `splitLine`,
  `mergeLines`, `addLine`, and sessionless mutation fallback methods.
- `EditLineRepository.updateSubtitleLine`, `addSubtitleLine`,
  `deleteSubtitleLine` and annotation methods without session scope.
- `WaveformSubtitleRepository.updateLines` for sessionless callers.
- Pre-operation checkpoint constructors in `CheckpointManager` for v1
  compatibility.

The live main Editor uses V2 methods for add/delete/split/merge; waveform,
sync, normalization and Source View live paths were migrated in checkpoints
60–63. This checkpoint specifically closes the remaining identified
Find & Replace / project encoding callers. It is **not** a proof that every
library/plugin integration uses only V2 APIs. Continue classifying callers
before removing compatibility entrypoints.

## CI and platform constraints

Use the one deliberate Checkpoint 64 gate: `flutter analyze` and
`flutter test -j 1`. Do not run platform builds or modify upstream/release
tags. Do not begin desktop layout work in this milestone: the reuse audit and
PC-first design are explicitly deferred.
