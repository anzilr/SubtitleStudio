# SubtitleStudio — Studio Dock DS5 R4a: Save .msone Project Documents

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Scope implemented

- The native Studio Dock **File** menu exposes **Save project (.msone)** and **Save project as…**, separate from subtitle SRT Save / Save As / Export. No classic Editor route is used.
- Project documents are produced exclusively with `ProjectSaveCoordinator.buildDocument`, preserving subtitle metadata, checkpoint snapshots/deltas, graph references, bookmarks and review notes. A single capture timestamp makes rechecks deterministic without altering the versioned document format.
- A Save with no writable existing `.msone` location opens Save Project As. The native Save dialog selects a concrete `.msone` file; cancellation writes nothing. Existing destinations require an explicit **Replace project** confirmation.
- A prepared document is revalidated after the dialog against the fresh persisted session, subtitle collection, checkpoints and references. Changed content aborts with a stale-state message before writing. Save As relinks the session path only after a successful file write and a second graph check. The path update is an optimistic Isar transaction, guarded by session/collection identity and previous project path.
- Inspector draft Apply / Discard / Cancel applies to project saves. Pending file operations block duplicate actions and workspace closing. The UI distinguishes cancellation, invalid targets, overwrite refusals and saved-but-unlinked outcomes.
- SRT Save and `.msone` Save use different commands. Ctrl/Cmd+S remains mapped to SRT Save and Ctrl/Cmd+Shift+S to SRT Save As through the existing hotkey manager.

## Verification

- New `test/studio_dock_project_save_actions_test.dart`: complete project document/history save and direct update, no-location fallback, overwrite protection, stale subtitle/graph checks, path/owner protection, invalid target. Existing Studio Dock import/create tests remain intact.
- Extended `test/studio_dock_file_actions_widget_test.dart` for project Save/Save As File menu commands, fallback, success and cancel semantics.
- Run focused Flutter analysis/tests, the full Flutter suite and platform-sensitive host tests in GitHub Actions. Only `flutter pub get`, `flutter analyze` and `flutter test` are allowed; **no native/platform builds in CI**.
- Physical Windows acceptance is still required for save picker, overwrite dialog, relinking after restart, checkpoint history import, file associations, 1366×768 / 1920×1080 layout and OS permissions. Later smoke-test macOS/Linux dialogs on their hosts.

## Next

- DS5 R4b: checkpoint Undo / Redo and human-readable edit history integration within Studio Dock, reusing history services and existing hotkey manager.
- DS5 R5: Source View and remaining inspector panels. DS6: native desktop performance and interaction acceptance for player/waveform sync, controller visibility, themes and file I/O.

## Handoff

The single native desktop workspace is **Studio Dock**. Keep the new SRT file service (`StudioDockFileActions`) distinct from the `.msone` project document service (`StudioDockProjectSaveActions`); the prior `StudioDockProjectActions` remains the **import/new-project** service. Neither save service replaces checkpoint transactions or reintroduces classic desktop Editor.
