# SubtitleStudio — DS5 R4b: Studio Dock History Navigation

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Changes

- The production Studio Dock uses `StudioDockHistoryService` to read the shared checkpoint graph and restore an existing history point through `CheckpointRepository.checkoutCheckpoint`. No separate desktop persistence, media player or checkpoint schema is introduced.
- Checkout requires the displayed HEAD and exact persisted baseline (including source, nullable edited text, timing, review notes, review flags, encoding and collection ownership). The underlying transaction verifies the expected HEAD and working-state hash again before committing the restoration.
- Toolbar Undo/Redo and the History rail use the same restoration flow. Redo on a fork prompts for the desired direct child; arbitrary history-point restore asks for confirmation and keeps alternate saved versions intact.
- The editor always replaces its **complete** cue list after a successful restore; selection remains on an existing cue or moves to the last restored cue. Empty-cue restoration remains undoable through the empty-project toolbar.
- The new human-readable History page uses the existing shared checkpoint graph and `CheckpointHistoryLabels`; persisted branch/ref names are unchanged. It refreshes after text, timing, structural edits and history navigation.
- Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z and Ctrl+Y are scoped Flutter shortcuts. Unlike the native hotkey manager used for other editor commands, a focused text field retains its normal draft-level text undo behavior. History commands still use the same guarded action callbacks as toolbar buttons.
- Unsaved inspector drafts receive the existing Apply/Discard/Cancel confirmation before navigation. Failed or stale checkouts leave displayed cues intact and offer an explanatory message.

## Automated acceptance

- `test/studio_dock_history_integration_test.dart`: atomic round-trip, exact metadata preservation, stale displayed HEAD/data, undoable structural edit, alternate Redo paths.
- `test/studio_dock_history_widget_test.dart`: Undo/Redo buttons, human-readable History page, explicit fork selection, Cancel on an unsaved draft.
- Run Flutter-only focused and full CI gates (`flutter pub get`, `flutter analyze`, `flutter test`). Do not run app/platform builds in GitHub Actions.

## Next

- DS5 R5: Source View integration and remaining inspector functions, with shared edit transactions and correct draft boundaries.
- DS6: manual native Windows acceptance for video/waveform following, seek accuracy, theme contrast, 1366x768 and 1920x1080 layout, project/SRT dialogs and reopened `.msone` history. macOS/Linux native smoke checks follow.

## Handoff

Studio Dock remains the **only native desktop editor**. Mobile remains unchanged. Do not replace the guarded checkout with a UI-only undo stack; checkpoint graph references, bookmarks and alternate editing paths must persist. No desktop-native builds belong in CI.

## CI results

- [Focused Studio Dock quality #40069711061](https://github.com/anzilr/SubtitleStudio/actions/runs/40069711061): **PASS** — Flutter dependency resolution, analyzer and 101 passing focused tests, including DS5 R4b integration/widget cases.
- [Full repository Flutter quality #40069840759](https://github.com/anzilr/SubtitleStudio/actions/runs/40069840759): **PASS** — analyzer and 944 passing test entries across the repository on Linux.
- Both workflows ran `flutter pub get`, `flutter analyze` and `flutter test` only. No platform application builds were run; native desktop acceptance remains pending.
