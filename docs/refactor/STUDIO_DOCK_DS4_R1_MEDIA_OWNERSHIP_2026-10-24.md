# SubtitleStudio — Studio Dock DS4 R1 Native Media Ownership

**Date:** 2026-10-24  
**Branch:** `feature/studio-dock-integration`  
**Prior checkpoint:** [DS3 R2 text editing](STUDIO_DOCK_DS3_R2_TEXT_EDIT_2026-10-24.md)

## Scope delivered
- Real saved-media lookup through the existing `VideoRepository(EditorPreferencesRepository(isar))`, preserving current macOS bookmark handling. Verify that a saved local path exists before mounting any media widget. Missing/invalid path leaves the clearly identified disconnected preview.
- `StudioDockMediaPlan` maps actual cue timestamps, original/edited state, marks, and comments into existing `VideoPlayerWidget` subtitle overlay objects. A null edit uses original text; an intentionally empty edit is left blank. Invalid cues are ignored for playback overlay without changing stored subtitle data.
- `StudioDockVideoSurface` is a thin wrapper around the pre-existing `VideoPlayerSection`. Its State owns one `GlobalKey<VideoPlayerWidgetState>` and does not instantiate a second media engine.
- `StudioDockReadOnlySessionView` mounts the native player **only** when `allowNativePlayback=true`. The standalone desktop Home passes true; the legacy Editor's optional Studio Dock route leaves it false, preventing duplicate player ownership.
- The center work area uses `IndexedStack` so navigating to History/Search/Tools does not unmount the player's widget and reconstruct it. Resizing the three dock panels retains the same surface.
- Entering the legacy Home/import flow turns off Studio Dock playback and allows the old Editor to own its media, then restores the desktop surface on return. Returning also refreshes the project session snapshot.
- The newly attached player uses its existing internal transport/controls. Studio Dock's separate *fake* transport row is suppressed when a native player is present. Waveform still correctly says pending until DS4 R2.

## Verification
- `test/studio_dock_media_plan_test.dart`: missing/existing saved video decisions, null vs explicit blank translated subtitles, malformed timing exclusion, widget owner kept alive while changing sections.
- Existing DS3 text edit and session ownership tests continue to run.
- GitHub Actions remains **Flutter dependency resolution, analyzer, and tests only**—never native platform builds.
- **Native Windows verification remains mandatory**: play/pause, seek, resize, switch panel, open classic importer/Editor, switch session, return, media reopening, subtitle overlay updates after Apply.
- Do not claim actual waveform integration or live playback acceptance solely from Linux Flutter tests.

## Next
DS4 R2: integrate existing waveform seek coordinator + widgets under one player owner, test edge/timecode seek and note/device lifetime. Next DS5: file save/export, native pickers, history and Source View integration.
