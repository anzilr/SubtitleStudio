# SubtitleStudio — CP93 R2: Project replacement cursor integrity

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Problem found in final compatibility review

`SessionProjectImportRepository.replaceSession` replaces subtitle content,
encoding, project identity and checkpoint history in a single Isar transaction.
However, `_applySessionSelection` previously changed `lastEditedIndex` **only
when the imported project carried a non-null edit position**. Replacing an
existing session with a legacy project that had no edit position therefore
retained the previous session's cursor. For example, an old two-line session
with `lastEditedIndex=2` could be replaced with a one-line archive while
leaving the editor pointed at an unrelated or invalid cue.

## Small correction

- Always apply the incoming project session's `lastEditedIndex` during
  replacement, including explicit null/legacy-absent positions. The new
  project's null means **no saved edit position**, not permission to retain
  a cursor from the previous project.
- Keep the existing nullable `editMode` handling and file selection rules,
  along with the atomic Isar transaction and history-ID remapping.
- New Isar integration acceptance test starts with a real previous session,
  two cues, a saved cursor and a checkpoint/HEAD reference. It replaces that
  session with a legacy `.msone` containing one intentionally blank cue, no
  cursor and no history. The test checks stable session/collection IDs, cleared
  edit index, new encoding/project path, blank cue retention and deletion of
  old checkpoints and refs.

## Scope and safety

No Isar schema, archive serialization, migration, new-session import,
checkpoint format, SAF file picker, video lifecycle or mobile layout changed.
Existing imports with a non-null saved position continue to restore it.

## Verification

- `git diff --check`: clean locally.
- [Linux Flutter gate 39952361531](https://github.com/anzilr/SubtitleStudio/actions/runs/39952361531):
  **788 tests passed, zero analyzer issues**.
- Verified code commit: `e3a6fa40783cde6010eb03b333cd775bf11d2e4c`.
- Device-level Android/Windows replacement and playback smoke: pending CP93
  native acceptance. Do not infer it from the automated Linux gate.

## Next

Continue CP93 risk-based acceptance of file/encoding, checkpoint replacement
and Editor lifecycle. Before production desktop workspace integration, gather
actual Android and Windows smoke evidence using the CP93 R1 checklist.
