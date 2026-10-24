# SubtitleStudio — DS5 R9: native waveform history parity

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Problem

The live Studio Dock intentionally disabled waveform timing and cue-insertion
gestures, because the shared waveform's default persistence path could write
behind the Dock's optimistic project snapshot. Its 13%-height toolbar also
hid the mobile Apply/Cancel and Add controls.

## Changes

- Adds an **optional** `WaveformWidget.onApplyTimeEdit` callback. The native
  desktop host uses the existing guarded `StudioDockTimingEditService`, while
  mobile and other call sites retain their existing default history behavior.
- Exposes Add, Apply, Cancel, overlap and magnet-snap actions in the compact
  toolbar without substituting a new waveform renderer or audio player.
- Routes a confirmed waveform Add through `StudioDockCueStructureService`'s
  optimistic checkpoint transaction. A blank cue is inserted in start-time
  order (matching mobile), retaining the session's scratch Edit Mode or
  Translation Mode and without an extra unsaved draft.
- A pending Studio Dock inspector, notes or Source View edit must be Applied,
  Discarded or Cancelled before either waveform commit. Cancel leaves the
  project unchanged. Failed history guards are reported; no silent writes.
- After success, Studio Dock reconciles the **complete cue list**, current
  selection and history. Waveform double-click follows the selected cue into
  the native subtitle grid. The same player/waveform playback link is kept.
- Canonical SRT timecode conversion rejects out-of-day and negative duration
  values before a file/history write. Existing mobile waveform gesture logic
  remains intact.

## Verification

- Unit tests: valid millisecond conversion, out-of-range rejection and
  insertion ordering including equal start times.
- Widget tests: waveform compact editing/add controls and guarded host
  callback; unsaved Dock text draft cancellation before an external edit.
- GitHub Actions: Flutter dependency resolution, analyzer, focused Studio
  Dock tests and full Flutter tests **only**. No platform builds.

## Remaining

Native Windows/macOS/Linux gesture accuracy and video playback acceptance
must wait for a machine. P1 Project Settings, advanced selected-cue actions,
sync, imports and cleanup tools still need desktop entry points. P2 MSone
banners and Malayalam normalization are still separate from the now-wired
MSone submission route.
