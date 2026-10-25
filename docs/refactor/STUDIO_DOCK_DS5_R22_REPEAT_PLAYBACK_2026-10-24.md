# SubtitleStudio — DS5 R22 Repeat Playback Parity

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Implementation

The mobile Edit Line screen offers repeat-current-cue (Ctrl/Cmd+R) and
repeat-range (Ctrl/Cmd+Shift+R) commands with a dialog on a long/double tap
of fullscreen Repeat. Studio Dock now exposes both through the View menu and
the existing `MSoneHotkeyManager`, plus the mounted player's fullscreen repeat
button. Desktop uses the *same* `RepeatRangeDialog` without depending on a
classic mobile Edit Line ancestor; its mobile constructor and behavior remain
unchanged.

`StudioDockRepeatController` subscribes to the session's existing
`StudioDockPlaybackLink` position/attachment signals. There is no new
`media_kit` player, timer-based polling, waveform decoder, persisted mode or
subtitle repository. Its bounds follow the mobile 100 ms pre/post-margin,
clamp the beginning to zero, preserve the player's paused/playing state, and
loop only once per asynchronous native seek until playback position returns
below the endpoint. Changing the selected current cue follows the new cue;
custom ranges retain their explicit first/last positions. Retiming/deleting
cues recomputes or disables the active interval. Detaching a video disables
repeat so a replacement media path cannot inherit stale timing.

The desktop View menu disables repeat actions without a video/cues. Desktop
hotkeys are routed through the existing focus/modal guard and do not fire from
a focused `EditableText`. The player fullscreen button can open the same
dialog on desktop without altering the mobile callback path.

## Flutter validation scope

- Controller tests: start clamp, end crossing, asynchronous seek coalescing,
  selected cue changes, inclusive ranges, stale/retimed cues, detach and
  disposal while paused.
- Widget tests: gated View actions, enable/disable label, range picker inputs,
  and native single-player surface preservation.
- CI: `flutter pub get`, `flutter analyze`, focused Studio Dock tests, full
  Flutter tests. No platform application builds or live MSone submissions.

## Still to accept

- Real Windows/media_kit playback, repeat crossing precision under buffering,
  fullscreen popup stacking, selected ranges and playback after source edits.
- Native key-chord conflicts on Windows/macOS/Linux and selection/focus with
  an attached player.
- Remaining DS5 R23 formatting, dictionary, Paste Original and context-menu
  hotkeys; DS6 end-to-end native acceptance.

R22 is source-level parity, not certified native feature parity.
