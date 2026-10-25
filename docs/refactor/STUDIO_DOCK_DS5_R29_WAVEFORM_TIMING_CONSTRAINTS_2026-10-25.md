# SubtitleStudio — DS5 R29 safe waveform timing-handle constraints

Date: 2026-10-25
Branch: `feature/studio-dock-integration`

## Audit findings

The shared mobile/desktop waveform gesture logic snapped a start or end handle
when it approached either edge of an unrelated subtitle, but always jumped to
the unrelated subtitle's opposite edge (plus or minus 25 ms). A 5-second cue
could therefore cause a several-second jump. Snapping also occurred *after*
the no-overlap correction without a final validity check. Moving an overlay
into another subtitle could truncate its duration instead of stopping the
whole interval at the collision boundary.

## DS5 R29 change

- Introduce a pure `WaveformTimeRangePlanner` for start-handle, end-handle and
  whole-overlay drag proposals. Both mobile and Studio Dock use it through the
  existing shared `WaveformWidget` gesture adapter.
- Start handles consider only a preceding cue's **end + 25 ms**; end handles
  consider a following cue's **start − 25 ms**. Candidate proximity is
  measured to the *actual destination*, not an unrelated edge.
- Preserve a single handle's other endpoint, a minimum positive range and
  nonnegative timing. Reject magnet/playhead candidates that would cross an
  anchor or enter another subtitle when overlap is disabled.
- Whole-overlay movement retains its duration. A drag stops at the first
  crossed subtitle barrier, even if a large pointer update jumps beyond it.
  Magnet alignment shifts both endpoints together and is revalidated.
- Respect the user's existing magnet and overlap toggles, the current cue
  exclusion, and the same selected original audio/video player. No new media
  controller, persistence operation or mobile UI is introduced.

## Test and acceptance boundaries

- Nine pure regression tests: prior-end/following-start snap targets, avoiding
  far-edge jumps, rejecting overlapping playhead snaps, handle crossing,
  forward/backward whole-overlay motion and fast crossing, gap-aligned moving
  snap, and overlap-toggle behavior.
- Focused Studio Dock CI also runs the pure planner tests. Full Flutter
  analysis/test suite remains a separate triggered quality gate. **GitHub
  Actions performs no platform builds.**
- Native Windows acceptance is still required for zoomed handle hit targets,
  pointer precision, snapping at dense cue boundaries, waveform responsiveness
  on long media, and checkpoint-backed Save/Undo after timing edits.
