# SubtitleStudio — DS7 R3: inspector character counts and custom quality rules

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Character counter parity

- Restore the **mobile Edit Line** `N chars` counters in Studio Dock's line
  inspector: bottom right of the Original box and the Edited / Subtitle Text
  box. Edit Mode shows only the latter; hidden original text does not consume
  space. Counters update as the user types without committing the draft.
- Share the mobile strip-tags-and-count helper, preserving mobile behavior:
  HTML `<br>` becomes a newline, HTML and subtitle tags are ignored, and
  character length uses Dart string code units. A long line makes the
  counter bold/danger-colored. The display follows the Isar-backed
  `maxLineLength` preference (32 by default) in both mobile and desktop.
- Reserve bottom text padding so the overlay doesn't obscure edited content;
  preserve scrollability and selection in both inspector text boxes.

## Quality profiles

- Add **Custom** to General, Streaming, and Relaxed. The custom configuration
  dialog edits CPS, max characters per line, max text lines, min/max duration
  and minimum gap. Cross-field and numeric validation prevents invalid limits.
- Save both the chosen preset and the six custom limits via SharedPreferences.
  Invalid or old profile JSON falls back to General defaults; built-in presets
  are untouched. Changes cause a live quality rescan and do not edit cues.
- DS7 R2 guarded safe-fix behavior and history rules are unchanged.

## Verification

- New isolated counter semantics tests, live inspector counter/long-line test,
  profile round-trip/fallback tests and persisted custom dialog test.
- CI is Flutter pub get/analyze/test only. No platform builds in Actions.
- Visual acceptance remains pending until native Windows hardware is available.

## Next work

- Consider optional manual suggestions for line breaks and timing adjustments,
  previewed and guarded through one checkpoint; never silently alter timing.
- Continue desktop/mobile feature parity review after native acceptance.
