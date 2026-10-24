# SubtitleStudio — DS5 R8: secondary subtitle parity

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Scope

Reconnect the live native Studio Dock video surface to the existing mobile
secondary subtitle functionality without introducing a desktop-only file
format, separate media player, or independent persistence path.

## Implementation

- Studio Dock Tools now offers **Load secondary subtitles** using the shared
  `SecondarySubtitleSheet`, including external SRT/VTT/ASS files, primary
  original text, and text-based tracks embedded in the current video.
- The host reads the existing secondary subtitle selection from
  `VideoRepository.loadSavedSecondarySubtitle` on opening/changing a project.
  It tolerates unavailable optional external tracks, as on mobile.
- The source is tracked explicitly: an original-text overlay is projected from
  the latest primary cues, while an external track is retained independently
  of primary cue edits. The player receives the selected list rather than an
  always-empty placeholder.
- Studio Dock provides **Show/Hide secondary subtitles** after a source is
  selected. Visibility does not erase the saved source preference.
- The existing video player instance is made available to the shared picker
  for embedded-text extraction; no new media player is allocated.
- The secondary picker is opened after the Tools popup has fully dismissed.
  This preserves route-barrier ordering used by the MSone submission fix.
- No mobile Editor UI, Isar schema, or shared subtitle parser changes.

## Validation

- Widget regression coverage for desktop menu gating, picker invocation and
  visibility actions; Flutter analysis and focused/full tests in GitHub Actions.
- Native Windows/macOS/Linux acceptance is **not** claimed: verify selection
  from file, video-embedded extraction, missing file recovery, persistence,
  original-text overlay refresh and playback after media reattachment.
- Media playback native checks remain deferred until the user's Windows
  machine is available. Do not use CI to build native applications.

## Next

P0 waveform gesture timing changes and cue insertion remain. P1 Project
Settings integration is still needed for project encoding/media/secondary
cleanup controls. MSone banners and Malayalam normalization remain P2 work.
