# SubtitleStudio — DS5 R18 Fullscreen Review Parity

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Desktop-only additions on the shared player

The desktop session now supplies native fullscreen review callbacks through
`StudioDockVideoSurface` → `VideoPlayerSection` → `VideoPlayerWidget`.

- Mark/unmark uses `StudioDockNotesService.apply` with checkpoint history and
  existing unsaved-editor draft confirmation. Unmark clears the comment and
  resolution, matching desktop review semantics.
- The fullscreen comment modal uses an **optional atomic callback**, saving
  a new comment and its mark together, not as two independent checkpoints.
  Delete removes the comment while keeping its mark and resolved state.
- The existing fullscreen toolbar gets a **Resolve/Reopen** button only when a
  review-aware host provides its optional callback. The button is disabled
  unless the current cue is marked. Existing mobile toolbar layout is unchanged.
- `Subtitle.resolved` defaults false for existing constructors, and
  `StudioDockMediaPlan.overlayCues` includes marked, comment and resolved.
- The player's `updateSubtitles` now notices comment-only and resolved-only
  differences and refreshes its fullscreen overlay; video decoding/player
  lifecycle is unchanged.
- Review saves guard stale values via the shared optimistic update; failed
  writes do not overwrite a newer edit from another window. A single guarded
  callback refreshes the grid, history and same native player, with no remount.

## Scope limits

No new review repository or player engine, no live MSone submission, and no
native platform builds. The original mobile mark/comment callback path remains
when the optional atomic callback is absent. The fullscreen overlay rotates
on Android using its existing lifecycle; desktop Windows verification must
confirm dialog stacking, media playback and focus in a real window.

## CI and acceptance

Regression tests include mapped review metadata in video subtitles and
compile-time callback wiring through the native surface without launching a
media_kit player. Existing notes-service tests check atomic mark/comment
history, clear, stale writes and no-op. Flutter analysis and focused/full test
suites must pass through GitHub Actions.

Pending native test checklist: mark/unmark, append/delete a fullscreen comment,
resolve/reopen, Undo/Redo, hotkey focus and player overlay visibility; then
repeat after a video path change and after MSone import. Do not mark native
feature parity complete before these checks.
