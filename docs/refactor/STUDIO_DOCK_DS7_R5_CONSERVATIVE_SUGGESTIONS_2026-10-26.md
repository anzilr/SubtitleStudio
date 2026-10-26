# SubtitleStudio — DS7 R5: conservative line breaks and timing ideas

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Quality text fixes

- The Suggested fixes tab includes balanced **two-line** proposals for overly
  long, single-line plain text when both resulting lines satisfy the selected
  quality profile's character-per-line limit.
- Split only between complete words at an existing single space, choose the
  closest-balanced valid split, and preserve the exact original words, case,
  and punctuation. Skip text with existing line breaks, extra whitespace,
  markup/override tags, tabs or backslashes, too few words, an unbreakable
  line, or a profile that allows fewer than two lines.
- Per-cue fixes remain mutually exclusive: whitespace cleanup wins when the
  source needs normalization. After cleanup, the user can rescan for reflow.
- Each suggestion is **unchecked by default**. The persisted text writer
  rejects stale source, duplicate cue IDs, invalid split limits, and forged
  output by recalculating the deterministic transformation before committing.
  All selected changes form **one undoable checkpoint**.

## Timing previews

- A separate **Timing ideas** tab considers only non-overlapping, positive
  gaps shorter than the selected profile's minimum gap.
- It previews an earlier end time which would create the configured gap by
  trimming the preceding subtitle's duration. Candidates are omitted if that
  trim violates minimum duration or reading speed.
- Timing ideas cannot be batch-applied in this checkpoint. Tap an idea to
  inspect and adjust the cue manually, preserving the shared timing editor's
  explicit Apply and history guard. No automatic video or waveform seek is
  required for preview.
- Overlaps, invalid timecodes, and unsafe trims remain diagnostic only.

## Validation

- Unit cases cover tag/blank-line and word preservation, custom profiles,
  insufficient gaps and unsafe timing cases.
- Widget cases cover explicit Apply for text reflow and read-only timing tab.
- Database integration asserts one checkpoint, original text preservation,
  and rejection of stale or forged reflow changes.
- GitHub Actions runs Flutter pub get, analyze and tests only; no builds.

## Follow-up

- Design a dedicated multi-cue optimistic timing transaction with neighbor
  snapshots before offering timing Apply. Avoid changing timecodes based on
  diagnostics without explicit review.
- Windows visual acceptance remains pending local hardware.
