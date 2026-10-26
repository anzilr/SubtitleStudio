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
| Batch actions | Search-and-replace filters, bulk case/style fixes, selective corrections with reversible history | Partial tools exist; audit coverage |
| Effects | Standard SRT frame-based effects, character/grapheme support, auto-recognition, collapsing, remove/restore | Active SRT checkpoint |

### Execution order

1. Finish SRT effect tools and Studio Dock reliability issues; finish native
   Android/Windows acceptance without GitHub Actions platform builds.
2. Audit existing Subtitle Edit-like features against actual Flutter code and
   mark implemented/partial/missing (do not duplicate existing tools).
3. Design the format-neutral editing model and lossless VTT/ASS/SSA source
   round trips before exposing a multi-format file picker.
4. Implement one format at a time with import/edit/save/undo tests, then
   integrate across mobile and desktop.

CI policy: GitHub Actions may run `flutter pub get`, `flutter analyze`, and
`flutter test` only. Platform builds remain local on the user's machine.
