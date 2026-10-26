# SubtitleStudio: Format expansion and Subtitle Edit parity backlog

Recorded at the user's request on 2026-10-27. **Future work**, not a claim
that ASS/SSA or WebVTT editing is already supported.

## Format expansion — required, not yet implemented

1. **WebVTT (`.vtt`)**: read/write the WEBVTT header, cue identifiers,
   cue settings (position, alignment, line, size, vertical), comments/NOTE,
   STYLE and REGION blocks, timestamps, and WebVTT text markup. Preserve
   unrecognized but valid metadata on a no-op round trip.
2. **Advanced SubStation Alpha (`.ass`) and SSA (`.ssa`)**: preserve script
   information, styles, event column formats/order, dialogue and comments,
   actors/layers/margins/effects, and style override tags. Support external
   fonts/attachments only with an explicit policy; never silently drop data.
3. **Shared editor bridge**: keep the current Riverpod/project/checkpoint
   architecture, allow a format-specific document sidecar for data not
   representable as an SRT `SubtitleLine`, and distinguish subtitle-format
   syntax from the rendered plain text in grid, preview, search, and Source
   View. Mobile and Studio Dock must expose the same editing functionality.
4. **Conversion is explicit**: never implicitly flatten ASS/SSA/VTT into SRT
   and overwrite the source. Warn when converting about lost style, motion,
   cue settings, ruby/voice annotations, font assets, or animation.
5. **Acceptance**: round-trip golden fixtures (including CRLF, BOMs,
   malformed cases, encodings, RTL and Malayalam graphemes), source-view
   editing, time shifts, undo/redo, marked lines, import/export, save-as and
   cross-platform UI parity. Update `.msone` package schema/version only
   after backward-compatibility tests exist.

The current SRT-only timed-frame effect engine remains separate. ASS/SSA
karaoke, fade and positioning should eventually use an appropriate renderer,
not be mislabeled as portable SRT effects.

## Subtitle Edit feature parity — tracked commitments

This extends the existing
`SUBTITLEEDIT_WAVEFORM_SOURCE_AUDIT_2026-10-14.md` and
`SUBTITLECOMPOSER_WAVEFORM_AND_ENCODING_SOURCE_AUDIT.md` instead of replacing
their pinned reference evidence. Benchmark and validate behaviour; do not
copy incompatible native source into Flutter.

| Workstream | Proposed features | State |
| --- | --- | --- |
| Format and encoding | WebVTT, ASS/SSA, extended encodings, reliable detection, line-ending/BOM preservation | Backlog |
| Text QA | CPS/WPM/readability warnings, excessive line-length detection, line balancing, punctuation and whitespace fixes | Audit current checker first |
| Timing tools | Frame-accurate shifts, gap/overlap checks, shot-change snapping, duration suggestions, sync by anchors | Partial shared tools exist; parity audit needed |
| Audio visualizer | Peak-preserving streaming/cache, track-aware audio timestamps, efficient zoom and tile rendering, optional spectrogram/speech view | Research recorded; native experiments deferred |
| Audio-only timing | Offline VAD speech regions to blank timed cues, preview/confidence, editable padding and gaps | Planned; no transcription |
| Video export | Soft-track muxing and hard burn-in, format/quality warnings, progress/cancel | Planned; no implementation |
| Batch actions | Search-and-replace filters, bulk case/style fixes, selective corrections with reversible history | Partial tools exist; audit coverage |
| Effects | Standard SRT frame-based effects, character/grapheme support, auto-recognition, collapsing, remove/restore | Active SRT checkpoint |

## Audio-only subtitle timing — planned (no transcription or LLM)

**Speech-region timing mode** takes audio/video, detects likely speech starts,
ends and pauses, and produces **empty, editable timed cues**. It does not
recognize words, infer the spoken language, or promise sentence-perfect
segmentation. Keep this distinct from future audio + transcript *forced
alignment*, which requires an acoustic model and provided text.

- Use an offline speech activity detector, with an optional simpler
  energy/silence heuristic; keep processing local. Surface music, effects,
  overlapping speakers and low-confidence intervals as review cases.
- Offer user-adjustable onset/offset padding, silence gap joining, minimum and
  maximum cue duration, splitting long regions, and optional snap-to-waveform.
  Avoid duplicate/overlapping cues and media-out-of-range timestamps.
- Preview detected regions as a non-destructive waveform overlay and blank
  subtitle list. Require explicit **Apply**; respect manual edits, undo/redo,
  checkpoints and unsaved-change safety. Never overwrite existing cues by
  default.
- Test clean dialogue, noisy scenes, background music, multiple speakers,
  long silence, track switching, variable frame rates/timebase and start PTS,
  cancellation and memory/performance on Android and desktop.
- Evaluate cue-boundary error against manually timed reference videos and
  report both typical errors and missed/false speech regions. Do not claim a
  fixed accuracy percentage before measurement.

## Encode subtitles into video — planned export capability

Two distinct export paths, both selectable from an **Export Video** workflow:

1. **Soft subtitles / muxing**: add selectable subtitle track(s) to an output
   container where compatible (e.g. SRT/ASS in MKV, or MP4-compatible text
   track). Prefer stream-copying video/audio without quality loss or a full
   transcode. Preserve existing audio/subtitle tracks by default; allow
   language/title/default/forced flags and track choice. Explain container and
   codec/style limitations, particularly when ASS/SSA/VTT styling would be
   lost in MP4, and never silently flatten rich subtitle data.
2. **Hard subtitles / burn-in**: render captions permanently into picture
   frames. Video must be re-encoded; offer codec, quality, resolution,
   hardware-acceleration availability, and subtitle style/font preview.
   Respect existing SRT effects and future format-aware ASS/SSA effects only
   where the renderer faithfully supports them. Show an explicit quality/
   time/storage warning before starting.

Shared safeguards: independent destination file (never in-place overwrite
of source video); safe unique default naming; progress, cancellation and
error recovery; insufficient-space handling; track/timebase/rotation/audio-sync
checks; long media and non-ASCII/Malayalam/RTL test fixtures; preserve project
state/history; cross-platform native capability/licensing audit and local
Android/Windows/macOS/iOS/Linux qualification. An exported video is not the
editable subtitle project and must not replace the source subtitle document.

**Dependencies:** complete SRT export/encoding correctness first. Multi-format
soft-track export and burn-in rendering must follow the VTT/ASS/SSA
format-preservation model, not bypass it.

### Execution order

1. Finish SRT effect tools and Studio Dock reliability issues; finish native
   Android/Windows acceptance without GitHub Actions platform builds.
2. Audit existing Subtitle Edit-like features against actual Flutter code and
   mark implemented/partial/missing (do not duplicate existing tools).
3. Design the format-neutral editing model and lossless VTT/ASS/SSA source
   round trips before exposing a multi-format file picker.
4. Implement one format at a time with import/edit/save/undo tests, then
   integrate across mobile and desktop.
5. Prototype speech-region timing on representative media and measure
   false-positive/false-negative regions before enabling one-click apply.
6. Add video export in two milestones: soft-track muxing first, then
   hard-subtitle rendering with cross-platform native verification.

CI policy: GitHub Actions may run `flutter pub get`, `flutter analyze`, and
`flutter test` only. Platform builds remain local on the user's machine.
