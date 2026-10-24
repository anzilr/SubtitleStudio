# SubtitleStudio — DS5 R2b: Guarded desktop Split and Combine

Date: 2026-10-24  
Branch: `feature/studio-dock-integration`

## Implementation

- Studio Dock's toolbar now offers **Split selected cue** and **Combine with previous/next**. The old mobile/classic Editor split and merge flows are not opened or modified.
- The existing `MSoneHotkeyManager` actions are reused on the standalone desktop host: Split (`Ctrl/Cmd+Alt+V`) and Combine (`Alt+L`) when text inputs do not have focus. No duplicate native shortcut system is introduced.
- Split uses a desktop dialog with a canonical millisecond-precise time strictly inside the current cue, plus independently editable Original/Edited text for both halves. Its initial text division is only a suggestion; Cancel writes nothing, and failed/stale commits preserve the draft for retry.
- Combine offers only actual adjacent timeline neighbors. It joins source text without dropping intentional empty entries, preserves effective edited content, spans both cues' timing, keeps both comments (newline-separated), carries either mark, and treats the result as resolved only if both inputs were resolved.
- Split retains the original cue's mark/comment/review status in the first half; the new second half starts unmarked, without a comment, and unresolved. Unedited original cues retain null edited fields after splitting.
- Both commands run inside the existing V2 history transaction with a full persisted-collection snapshot check and ownership guard. Any stale text, timing, review metadata or cue structure rejects the command rather than shifting a positional edit onto another cue.
- A successful command reloads the complete cue collection, reindexes selection, and refreshes waveform/video subtitle projections. Dirty Text/Timing drafts must be Applied or Discarded before opening either command.

## Verification and next steps

- Integration regression cases cover split timing and metadata, translated/blank cue combine, the selected cue after chronological reindex, checkpoint creation, invalid times/neighbor indices/ownership and stale snapshot rejection.
- Widget cases cover validation, cancellation, failed-commit draft preservation, adjacency choice, list refresh, and the unsaved-edit guard.
- **Run** `flutter analyze` and `flutter test`, with the focused Studio Dock tests first. GitHub Actions must run only `flutter pub get`, `flutter analyze`, `flutter test`; no platform application builds.
- **Next:** DS5 project Save / Save As / Export through existing file and encoding services; then native Windows acceptance (1366×768 and 1920×1080, high-DPI, single media-player ownership, real waveform/controller visibility, Split/Combine/history/undo). Check toolbar crowding at narrow widths and move lower-frequency cue commands into an accessible menu if needed.

## Session handoff

Current production desktop UI: Studio Dock only (`feature/studio-dock-integration`). Classic Editor is not a desktop fallback. Keep mobile and its waveform untouched; retain existing hotkeys, semantic theme integration, player/seek ownership, and checkpoint boundaries. Verify quality CI after each change and record native acceptance separately from unit/widget tests.
