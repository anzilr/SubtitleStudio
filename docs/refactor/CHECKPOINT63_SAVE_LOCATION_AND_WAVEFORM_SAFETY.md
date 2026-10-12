# Checkpoint 63 — Edit Line file-location and waveform history safety

Date: 2026-10-12
Branch: `refactor/riverpod-architecture`
Starting verified baseline: Checkpoint 62 (`45f3ec0`), analyzer clean, 217 tests passed.

## Scope
This checkpoint intentionally **does not start the desktop UI**. All changes are
repository/persistence fixes and a narrow wiring adjustment to existing Edit
Line and Waveform screens. No Isar schema or mobile layout modifications.

### 1. Edit Line Save As
- Earlier `_performEnhancedFileSave()` modified the cached
  `_subtitle` and called `saveCollection()`, writing every old subtitle line
  back even if edits had occurred while the OS file picker was open.
- Added `EditLineRepository.updateSubtitleSaveLocation()`, reading
  the current collection and validating its owning session **inside the Isar
  transaction**, then changing only `filePath` and `originalFileUri`.
- The Edit Line controller delegates to this targeted operation; the Save As
  UI updates its local path fields **only after the DB operation succeeds**.
- Prevents the immediate null assertion on `originalFileUri` in older files.
- Saved project subtitle content and checkpoint HEAD are not changed by file
  location updates. (A file system write and an Isar transaction cannot be
  made jointly atomic; failed metadata persistence is surfaced to the user.)

### 2. Waveform timing edits
- `updateLinesWithHistory()` now applies **only start/end times**, preserving
  the stored cue text, edited text, comment, mark and resolved flag.
- Optional `expectedLines` snapshots are compared to the freshly loaded
  destination cue inside the history write transaction. Stale active waveform
  edits are rejected instead of overwriting newer state.
- Rejects duplicate/invalid cue IDs and missing destination cues.
- A no-op timing request succeeds and does not create an extra V2 edit commit.
- Waveform UI only changes cached cue time fields after successful persistence.
- The sessionless legacy `updateLines()` fallback also rejects missing or
  duplicate IDs without partial writes and only modifies timing fields.

### 3. Regression tests
- Edit Line Save As preserves edits and annotations made after a stale
  collection snapshot was fetched.
- Wrong session, missing destination and empty paths are rejected.
- Waveform V2 commit cannot overwrite unrelated original text or annotations.
- Expected-cue mismatch cancels the complete operation and preserves the
  concurrent edit.
- No-op request has success semantics without an extra history commit.
- Legacy waveform batch validation rejects missing/duplicate cues atomically.

## Status and following work
- **Checkpoint 63 verified:** CI marker `8a67248`, `flutter analyze`
  reported **0 issues** and serialized `flutter test -j 1` reported
  **223 tests passed**. See
  https://github.com/anzilr/SubtitleStudio/actions/runs/38285975951.
- Remaining legacy APIs (including `SubtitleRepository.updateCollection`,
  `EditLineRepository.updateSubtitleCollection`, and direct standalone
  insert/delete/split helpers) remain **compatibility-only**, and should not be
  used for new live edits. The actively identified Edit Line Save As caller
  no longer uses the raw collection write.
- Additional work: audit all old-library and plugin callers for raw mutations,
  refine shared command boundaries, and later implement dedicated persisted
  HEAD/bookmark/branch refs with migration coverage.
- Desktop workspace UI and its shell are **explicitly deferred** until the
  agreed later milestone. Keep existing mobile widgets intact.
- No upstream merge, release-tag modification, or native platform builds.
