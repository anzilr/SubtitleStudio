# SubtitleStudio — DS7 R8: 1.75-second desktop waveform fine zoom

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## User request

Increase waveform magnification beyond the previously delivered 3.5-second
maximum while keeping long-media performance and mobile behavior stable.

## Implementation

- The desktop-only finest horizontal viewport now targets **1.75 seconds**
  (roughly twice the previous magnification). Intermediate coarse/fine zoom
  levels remain available. The target is converted to integer
  samples-per-pixel using the actual waveform viewport width, so resizing
  does not unexpectedly widen the displayed time span.
- Existing desktop metadata-only levels and bounded on-demand peak tiles are
  reused. No new FFmpeg extraction, audio decoding, eager full-track peak
  array, or changes to Isar waveform cache format are introduced.
- Each newly visited tile does scan the relevant already-decoded PCM samples;
  the peak work covers only the requested visible time, and cached tiles are
  reused. Increasing horizontal zoom grows total virtual pixels, not the
  number of on-screen pixels or the long-media allocation.
- Platform detection and mobile zoom ladders are unchanged: the extra fine
  levels are added on Windows/Linux/macOS only.
- Resize continues to preserve the timeline center, selected native zoom
  level, and raw waveform data. Stored zoom preferences remain compatible;
  users at their previously saved zoom may zoom in further using the existing
  controls.

## Regression coverage

Flutter tests check that 640–2560 px desktop widths achieve a 1.5–2.0 second
maximum viewport, metadata-only fine levels do not materialize peak arrays,
and panel resizing preserves the time anchor and underlying native levels.

Native Windows visual/seek/scroll and gesture acceptance is deferred until a
desktop device is available. GitHub Actions run only Flutter dependency
resolution, analysis, and tests—no native platform builds.
