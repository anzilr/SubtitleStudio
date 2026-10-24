# SubtitleStudio — DS5 R12 Go to Line

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Intent

Expose the existing mobile Go to Line command in the sole native Studio Dock
desktop editor. This is a navigation/UI feature; no subtitle repository,
export, Edit Mode, checkpoint or MSone submission behavior is replaced.

## Behavior

- Accessible from the **Edit** menu, subtitle-grid toolbar and existing
  platform hotkey `HotkeyAction.gotoLine` (Ctrl/Cmd+J where registered).
- A desktop dialog owns its input controller and accepts 1-based subtitle
  line numbers with a synchronized slider. Reject malformed/out-of-range
  entries without dismissing the dialog or changing selection.
- Before opening, the command goes through the same unsaved text, timing,
  notes and Source View draft guard as editor navigation.
- On success, the chosen cue is selected, the current search and review filter
  are cleared so hidden rows reappear, and the fixed-height list scrolls the
  destination into view even on very long projects.
- If and only if the session has an attached media player, invoke the shared
  playback link at the subtitle's start time plus **50 milliseconds**. This
  matches the mobile seek margin; it does not construct a second player or
  modify playback/waveform engine ownership.
- Cancel leaves the cue, filter and playback position unchanged.

## Automated acceptance

- Widget regression tests for distant-row scroll, the exact seek offset,
  invalid bounds, Cancel, hidden-row search reveal, unattached video, dirty
  inspector confirmation, Edit menu dispatch and slider/text synchronization.
- Flutter dependency resolution, analyzer, focused Studio Dock and full test
  suites via GitHub Actions. **No platform builds in CI.**

## Deferred native acceptance

Verify native desktop keyboard registration, large-file scroll accuracy,
video/waveform synchronization and focus behavior on the Windows machine when
it becomes available. The R7 MSone submission remains a separate existing
feature and must not be exercised against a live endpoint during UI testing.
