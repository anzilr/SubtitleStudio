# SubtitleStudio — Studio Dock DS3 R2: Checkpoint-backed Text Editing

Date: 2026-10-24
Branch: `feature/studio-dock-integration`
Base: DS3 R1 real-session startup + 823-test baseline, not the detached preview branch

## Completed

- The native desktop launch now uses Studio Dock directly; a real session in the desktop host opts into **LIVE · TEXT EDIT**.
- `StudioDockTextEditService` routes text changes through the existing `SubtitleRepository.updateMultipleLinesWithHistory` atomic checkpoint transaction. It never writes directly to Isar or SRT/\`.msone\` files.
- The immutable session snapshot now preserves the *exact* persisted nullable edited text, review mark, comment, resolution state, original, start/end timing, session and collection IDs. Reconstructed expected lines are verified against current persisted lines **inside** the shared history transaction.
- Missing/foreign sessions, missing cue numbers and stale text, timing or review metadata reject the update; a failure retains the user's draft.
- Text inspector supports **Apply**, **Discard**, and cue-leaving **Apply / Discard / Cancel**. Switching inspector tabs preserves the current draft. Project switching and in-app Back route are guarded while a draft is dirty.
- Successful Apply refreshes the immutable repository baseline for subsequent edits, updates the visible cue, and records native checkpoint history. Unchanged edited text is a no-op.
- All other production actions remain deliberately disabled: timing/style writes, notes writes, file export/Save As, video and waveform. The demo mode still supports isolated preview interactions. Real media placeholders are correctly labeled disconnected.
- Existing cross-platform `MSoneHotkeyManager` integration remains; the live session continues to suppress underlying classic-editor callbacks to avoid unintended mutations.

## New regression coverage

- Real isolated Isar integration: atomic edit, metadata/original/blank-line preservation, nullable empty text, no-op avoids commits, second edit refresh, stale-text and stale-comment rejection, foreign/deleted session protection.
- Widget checks: Apply is the only route to the persistence callback; Cancel/Discard guard on cue changes; failed Apply retains draft; native Studio Dock startup expects text-edit mode.
- GitHub Actions remains dependency resolution, `flutter analyze`, and `flutter test -j 1` **only**. Never run platform builds in CI.

## Remaining acceptance / known limitations

1. Physical Windows start should open Studio Dock rather than legacy Home, with actual SRT cues and columns; verify resizing at 1366×768 and 1920×1080.
2. Test real Apply, navigation Discard/Cancel, stale edit rejection, relaunch persistence, and undo through the existing editor/checkpoint screen.
3. Native OS window-close interception is not covered by Flutter Navigator PopScope; avoid claiming OS close protects drafts until that is separately implemented.
4. The production video, waveform, timing/style/notes actions, command/menu wiring, full native file workflows and SRT/.msone export remain separate DS4–DS5 checkpoints.
5. Editing persists to the local Isar subtitle collection and checkpoint history; it does **not** immediately write the external .srt file. Do not confuse Apply with file Save.
6. Existing legacy Home 12-pixel overflow remains a separate issue when explicitly opening classic Home.

Next checkpoint: native Windows acceptance and focus/persistence verification; then extend production editing and begin DS4 media/waveform ownership integration. Keep this separate from mobile theme and waveform experiments.
