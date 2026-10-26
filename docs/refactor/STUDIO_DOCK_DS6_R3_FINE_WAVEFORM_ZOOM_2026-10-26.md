# SubtitleStudio — DS6 R3: 3–4 second waveform fine zoom

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Goal

The desktop waveform must reach a usable fine-timing range of approximately
3–4 seconds across the visible canvas. Mobile's generated zoom ladder remains
unchanged. Windows hands-on testing is deferred until a device is available.

## Implementation

- The finest desktop-only zoom now targets **3.5 seconds** using the actual
  waveform viewport width and the decoded audio sample rate.
- When the waveform panel changes width, only the inexpensive fine-zoom
  metadata is recalculated. Existing generated levels and audio samples are
  reused, and the viewport remains anchored to the same timeline center.
- Resizing preserves the chosen native zoom level or the number of steps from
  the tightest desktop-only fine zoom.
- Fine zoom preferences now retain negative offsets relative to the original
  ladder, instead of rounding every fine setting up to native level zero.
  Mobile clamps these desktop-only values safely to its native minimum.
- The existing on-demand waveform peak tiles remain in place; no eager
  full-track arrays are allocated for fine zoom.

## Subtitle Edit reference

Reviewed the official `SubtitleEdit/subtitleedit` repository's
`src/ui/Controls/AudioVisualizerControl/AudioVisualizer.cs` and its waveform
documentation. Subtitle Edit separates horizontal timeline zoom (`ZoomFactor`)
from vertical amplitude zoom (`VerticalZoomFactor`) and derives sample-to-pixel
rendering from waveform view scale. The Studio Dock implementation likewise
sets its horizontal fine zoom in visible seconds, independent of vertical
waveform magnification; this is an adaptation, not a source-code port.

## Regression coverage and acceptance

- Pure zoom tests exercise 640, 850, 1200 and 1920px waveform widths and
  assert 3–4 seconds of visible audio at the finest step.
- Resize tests verify timeline-center anchoring, the selected native level,
  reuse of peak descriptors, and zero eager peak allocations.
- Repository integration test round-trips negative desktop zoom offsets.
- Run Flutter analyzer and focused/full tests in GitHub Actions (no platform
  builds). Native Windows visual and performance checks remain deferred.
