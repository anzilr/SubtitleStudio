# SubtitleStudio Studio Dock — DS3 R1 Read-only Shared-core Integration

Date: October 23, 2026
Branch: `feature/studio-dock-integration`
Parent baseline: `refactor/riverpod-architecture` at `076ba98a`
Ported shell: DS1/DS2 preview at `ec29dbf`

## Motivation
The isolated preview branch was 135 commits behind the core refactor branch. Do **not** directly merge the divergent branches or treat the demo as a production editor. Instead create this integration branch from the current refactoring code, with only the verified preview files ported by their Git blobs. Both original branches remain unchanged.

## DS3 R1 implementation
- `studio_dock_session_snapshot.dart`: typed immutable DTOs for cue text, timestamp, marking and selected encoding, independent of generated Isar classes.
- `studio_dock_session_loader.dart`: read-only loader composed from existing `ProjectRepository` and `SubtitleRepository`. Verify the session exists and owns the requested collection before requesting its cues. No database write, checkpoint initialization, video player, or new schema.
- `studio_dock_read_only_session_view.dart`: Riverpod `ConsumerStatefulWidget`, scoped to a real session and collection, with loading and failure states. It displays live subtitle cues in the Studio Dock shell; standalone preview demo remains unchanged.
- `DesktopWorkspacePreview` now accepts optional external cue snapshots and a `liveReadOnly` flag. Real cue mode explicitly disables text mutation, marking, playback preview, and edit-like context/command actions; timecodes can still be copied.
- Actual media playback, write transactions, source views and final save/export remain DS3 R2/DS4/DS5.
- A source-only loader can be embedded in a desktop route with `ProviderScope` overriding `isarProvider` using the already-bootstrapped Isar; do not initialize a second database.

## Tests and acceptance
- Integration tests with isolated actual Isar schema: nullable edits, blank lines, original/edited text, timestamps/encoding and non-mutating loads.
- Reject mismatched session and collection IDs; do not generate history/checkpoint entries on reads.
- Flutter analyzer and complete tests via GitHub Actions. Workflow on this branch remains `flutter pub get`, `flutter analyze`, `flutter test` only. **Never platform builds in GitHub Actions.**
- Native Windows visual acceptance and DS2 shortcut-focus validation remain pending because local Workspace Bridge was offline.

## Follow-up
1. Verify DS3 R1 full Flutter gate.
2. Add a desktop-only, explicit UI route to the read-only session with proper active ProviderScope and isolated media-free lifetime.
3. Prepare guarded edit transaction bridge using existing `EditController`/`SubtitleRepository` plus optimistic stale-edit checks; only then enable edit/reset/mark controls and Save As.
4. Connect existing media widget/waveform without duplicate GlobalKey ownership.
5. Finish native Windows, Linux and macOS smoke tests.

This checkpoint intentionally does **not** modify production Android navigation.
