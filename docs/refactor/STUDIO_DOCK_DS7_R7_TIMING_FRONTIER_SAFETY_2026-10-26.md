# SubtitleStudio — DS7 R7: safe timing suggestions with overlapping cues

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Correction

The quality checker previously proposed shortening a caption's end when the
*immediately preceding* caption and the next caption had a small positive gap.
This was insufficient for unusual subtitle files with overlapping intervals:
an older, longer caption could still be running across the proposed gap.
The suggested change would not actually achieve the advertised clearance.

Timing suggestions now track the latest end time of every earlier caption
*other than the one being shortened*. A proposal is offered only when those
other captions end no later than the proposed end. The chronological scan
remains linear after sorting, and an unsafe pair does not hide safe pairs
later in the file. Existing overlap diagnostics continue to surface the
underlying issue for manual correction.

## Safety and scope

- Source timecodes and text are never changed by a scan or preview.
- The guarded Studio Dock writer recomputes proposals using this updated
  checker; a forged proposal that tries to bypass the rule is rejected before
  Isar or checkpoint history is written.
- The stricter rule applies to all callers of the shared checker and does not
  alter mobile/desktop editor layout, waveform zoom, seek, or playback.
- Regression coverage includes a long-running earlier cue, duplicate end
  times, a legitimate independent later pair, and rejection at the writer.

## Verification boundary

Flutter analysis and test workflows only; no platform builds in GitHub
Actions. Native Windows visual and playback acceptance is still pending until
the user's laptop is available. The desktop/mobile parity ledger remains
the source of truth for native acceptance.
