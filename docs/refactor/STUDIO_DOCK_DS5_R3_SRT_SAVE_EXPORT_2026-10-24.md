# SubtitleStudio — DS5 R3: Studio Dock SRT Save / Save As / Export

Date: 2026-10-24  
Branch: `feature/studio-dock-integration`

## Implemented

- Studio Dock has a live **File** menu (Save, Save As, Export SRT) and a compact toolbar Save command. Native desktop integrates them with the existing source file and export service boundaries; demo/read-only routes do not offer filesystem mutations.
- **Save** uses `EditorDirectSaveService`: existing native path/URI and macOS security-scoped bookmark policy, charset validation before a write, with Save As fallback if no writable source exists. Ctrl/Cmd+S reuses `MSoneHotkeyManager`; Ctrl/Cmd+Shift+S is a new action on the same manager, not a parallel native keyboard handler.
- **Save As** prepares strict encoding-preserving SRT bytes, opens the native desktop Save dialog, checks that all persisted cue fields and source metadata still match after the dialog, then writes via `EditorExportService`. It relinks `filePath`/`originalFileUri` transactionally against the expected source identity. A macOS new location is linked only if a new security-scoped bookmark was created.
- **Export** offers Original and Edited text separately, using the established `SrtCompiler`/strict encoder. It never relinks the project or changes checkpoints. An empty Edited string stays an intentional blank cue; Original remains available independently.
- Both Save As and Export refuse to replace an existing file until an explicit confirmation, even if the native picker already displayed one. Cancel and failure never produce a success Snackbar; stale project data aborts before writing. A successfully written but unlinked file is reported distinctly.
- Inspector Text/Timing drafts are resolved with the existing Apply / Discard / Cancel popup before any file action. A running save blocks duplicate commands and closing the workspace; no classic Editor or mobile bottom sheet is invoked.

## Tests and safety scope

- Integration cases: Save As/Save round trip, original/edited export and deliberate blank edited content, existing-file protection and explicit replacement, snapshot conflicts, wrong session and file identity, invalid filename/encoding, macOS missing/fresh bookmark, and metadata integrity.
- Widget cases: Save feedback, Save As fallback cancellation, File menu and both export choices, dirty draft Apply/Cancel, and duplicate Save suppression.
- CI gates: `flutter pub get`, `flutter analyze`, focused Studio Dock tests, then full `flutter test`. GitHub Actions must **never run native/platform builds**. Native Windows/macOS/Linux file-dialog acceptance and permission behavior remain separate manual checks.

## Next checkpoint

- DS5 R4: `.msone` project document Save / Save As from Studio Dock, with existing checkpoint graph/history and safe overwrite handling; add Undo/Redo/history panel integration, then Source View and remaining inspector panels.
- DS6: Windows native acceptance at 1366×768 and 1920×1080, including SRT Save/Export encoding and cancelled picker, file relinking after reopen, split/merge undo, single video owner, waveform and playback sync, controller visibility and semantic themes. Follow with macOS/Linux file-picker smoke checks on their hosts.

## Session handoff

Studio Dock is the **only** native desktop UI. Keep its integration branch, do not reintroduce classic Editor or mobile layout changes. Avoid separate media players, direct waveform mutations or stale Isar full-object writes. `StudioDockFileActions` is the new SRT-only byte preparation/write guard; ProjectSaveCoordinator remains the authoritative `.msone` builder for the next phase.
