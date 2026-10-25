# SubtitleStudio — DS5 R28 waveform seek handoff and target stability

Date: 2026-10-25
Branch: `feature/studio-dock-integration`

## Finding

The shared waveform seek coordinator used one active session for wheel bursts
and manual dragging. Starting a pan before the mouse-wheel idle final seek
cancelled the timer but inherited the wheel's old target. A drag released
without any actual movement could therefore seek to the previous wheel
position. At coarse waveform zoom, repeated pointer positions also mapped to
the same audio sample yet could issue redundant native preview seeks after
the preview cooldown expired.

## Change

- Treat the transition from a pending wheel burst to a new drag as a gesture
  handoff. Cancel the old wheel session and its timers, then start a clean
  drag with no inherited final seek target.
- Ignore identical quantized targets in a drag/wheel session, preserving the
  most recent unique target and its **exact final** native seek on release.
- Reuse the existing seek-hold/acknowledgement logic, scrub visual updates,
  preview throttling and zero/end-of-waveform clamping. Keep a single native
  media player and the existing mobile gesture behavior.

## Regression coverage

- Wheel-burst → moving drag completes at the drag target, never the stale
  wheel target; the cancelled idle timer cannot fire later.
- Wheel-burst → stationary drag releases without replaying the wheel target.
- Twenty repeated quantized drag updates generate no extra native preview
  after cooldown; the final seek still occurs.
- Padded waveform start/end positions produce exact final seek times of zero
  and the last audio sample's time.
- A stale wheel playback update cannot recenter the subsequent drag or its
  final-seek hold; a near-target acknowledgement resumes normal updates.
- The focused Studio Dock CI suite now includes the shared manual-waveform
  seek test file; full Flutter suite remains a separate gate. GitHub Actions
  execute Flutter dependency resolution, analysis and tests only.

## Native acceptance still pending

Windows mouse/trackpad wheel-to-drag input, actual native seek landing error,
subtitle snapping/overlap handles, long-media behavior and playback/list/
waveform scroll synchronization. This source-level correction does not claim
real-device precision or waveform-generation acceleration.
