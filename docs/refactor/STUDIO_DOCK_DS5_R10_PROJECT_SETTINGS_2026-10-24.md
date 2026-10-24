# SubtitleStudio — DS5 R10: native Project Settings parity

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Scope

Project Settings is a shared editor feature, not a separate desktop design.
Studio Dock must expose the existing `ProjectSettingsSheet`, preserving its
repository-backed project name, subtitle encoding, video and secondary media,
file information, and marked/commented-line actions.

## Implementation

- Adds Project Settings under the native **File** menu, top toolbar and empty
  scratch-project toolbar. Read-only/embedded desktop hosts do not offer it.
- The File popup finishes dismissing before the shared dialog is opened;
  repeated activations are guarded. Pending subtitle, timing, review-note or
  Source View edits must be Applied, Discarded or Cancelled first.
- The live host loads the authoritative `Session` and `SubtitleCollection`
  objects from existing repositories and opens `ProjectSettingsSheet` inside
  a bounded desktop dialog. No duplicate desktop settings storage or schema.
- Existing callbacks are connected for changing video, saving `.msone`,
  selecting secondary subtitles, using original text and clearing a secondary
  track. The Save Project adapter respects needs-location, cancel, stale
  snapshots and saved-but-unlinked results rather than reporting false success.
- After closing the dialog, the host reloads the project, reconciles the
  complete subtitle grid/history, refreshes the original/external secondary
  source and resolves the persisted video link. An unchanged video path keeps
  its current player instead of causing an unnecessary media restart; a
  removed or replaced video updates the live surface.
- All mobile screen layouts and existing Project Settings functionality are
  unchanged. Desktop Studio Dock remains the only native desktop editor.

## Verification

- Widget tests: hidden in a non-live host, File menu overlay barrier and Back
  cleanup, Cancel/Discard dirty-draft behavior, and empty-project access.
- Shared encoding and repository checks continue to run in the full suite.
- GitHub Actions: dependency resolution, Flutter analyzer, focused Studio
  Dock tests and complete Flutter tests. No native builds in CI.

## Native acceptance deferred

- Verify project rename, encoding updates, Save/Save As, video unlink and
  replacement, original/external secondary controls, marked-line editing,
  focus and navigation after dialog return on Windows/macOS/Linux.
- The next P1 parity work is selected-cue batch edit/delete, Go to Line,
  subtitle sync, comments import and hearing-impaired cleanup. MSone banners
  and Malayalam normalization remain P2; submission itself is already wired.
