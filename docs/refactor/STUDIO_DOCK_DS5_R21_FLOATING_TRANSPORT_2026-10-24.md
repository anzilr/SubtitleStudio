# SubtitleStudio — DS5 R21 Floating Transport Parity

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Scope and design

The mobile Edit editor has an optional floating play/pause action above
the video band, default disabled. Studio Dock previously offered only the
embedded native video controls and shared keyboard play/pause.

R21 adds **View → Show/Hide floating playback button** for an attached video
and available playback callback, matching that mobile toggle's ephemeral
(default off) behavior without creating or mounting a new player.

- The central video band uses a `Stack` with its existing player in a stable
  `Positioned.fill` child. Toggling the floating button only inserts/removes
  the additional overlay.
- The button reads `StudioDockPlaybackLink.playing` through
  `ValueListenableBuilder`, and delegates tap to the already-wired
  `onTogglePlayback` callback.
- If the shared playback link is detached or the native player is no longer
  available, the control becomes disabled. The View-menu entry is not
  advertised for projects without a video surface or playback handler.
- The optional overlay stays in the desktop editor band; fullscreen continues
  using the shared player's existing fullscreen controls.
- This is a desktop UI change only: subtitle persistence, mobile layout,
  waveform/audio controller, and MSone submission remain unchanged.

## Tests and risk boundary

Widget tests exercise visibility opt-in, updated Play/Pause icon/tooltip,
click delegation, disabled state after detachment, media-less menu gating,
and preservation of the exact player StatefulWidget across show/hide.

GitHub Actions may only run `flutter pub get`, `flutter analyze`,
focused Studio Dock tests and full `flutter test`. Do not build any platforms
in GitHub Actions, submit test data to MSone, or imply Windows acceptance.

## Still partial

- Video repeat-current-cue and repeat-range player behavior and keybindings
- Line-format, dictionary, and paste-original hotkey parity
- Native floating button interactions, hover/focus, waveform cache, media
  detach/reload and Windows multi-screen/fullscreen acceptance
- Remaining context menus and complete mobile/desktop regression review

The platform remains **not yet certified feature-parity complete**.

## Paused-detach refinement

The shared playback link now exposes an explicit attachment notifier. An already-paused player can detach without changing the `playing` value; the floating button listens to both values so it disables immediately and re-enables when a native player attaches again. A widget test verifies paused detach and reattach.

## Final analyzer clean-up

Removed an unnecessary import in the existing fullscreen review callback test. This was reported as one informational analyzer issue in the first passing R21 focused suite, not a runtime or widget failure.
