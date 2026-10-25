# SubtitleStudio — DS5 R25 Direct Video Unload Parity

Date: 2026-10-25
Branch: `feature/studio-dock-integration`

## Gap found

Mobile's main Edit menu supports Load and Unload Video directly. Studio
Dock already loaded/replaced video via the shared picker but previously only
unlinked media indirectly through Project Settings. This was accessible yet
not interaction-equivalent to the mobile editor.

## Source changes

- The existing desktop View menu offers **Unload video…** only when both a
  video surface and the real host unlink callback are present.
- Unsaved subtitle drafts must be Applied or Discarded before starting. A
  cancellation leaves both the cue and media state untouched.
- A dedicated confirmation explains that unloading detaches the project link
  but does not delete the user's video file. Popup exit completion is awaited
  so the following dialog is not blocked by the menu's closing barrier.
- The live session host calls the existing `VideoRepository.removeVideoPath`.
  Its current media Future is changed to `null` **only after persistence
  succeeds**. An error leaves the existing video and waveform mounted.
- Successful unlink stops active repeat and causes the existing keyed video
  and waveform widgets to detach through their normal lifecycle; no second
  player or waveform decoder is introduced. The option remains absent from
  read-only/non-media hosts and when there is no video.

## Flutter verification

- Widget coverage: visibility and callback gating, Cancel vs Confirm,
  failed persistence feedback while the video stays mounted, unsaved cue
  draft Cancel, and normal menu-to-dialog transition.
- CI: Flutter dependency resolution, full analyzer, focused Studio Dock tests,
  full Flutter tests; **no platform builds**.
- Native desktop acceptance remains pending: load MKV/MP4, unload during
  playback/fullscreen/repeat, waveform async load cancellation, reattach same
  file, media path persistence across app restart and a real `.msone` project.

The R25 interaction audit also identifies mobile Edit Line's visibility,
formatted-preview and auto-save navigation preferences as separate parity
questions. Their behavior is not silently declared complete by this change.
