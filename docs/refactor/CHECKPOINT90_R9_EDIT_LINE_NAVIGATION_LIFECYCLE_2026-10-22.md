# SubtitleStudio — CP90 R9: Edit Line navigation lifecycle

Date: October 22, 2026
Branch: `refactor/riverpod-architecture`

## Issues

Edit Line formerly started Jump to Line's async reload within a synchronous
`setState`, without passing through navigation autosave. Multiple taps could
overlap database fetches; an older load could complete after a newer one and
replace its selected cue or seek the video incorrectly. Its loading method
also examined the initial route `widget.index` when deciding whether a
requested row was valid, rather than the requested index, and did not guard
widget disposal after the awaited read.

## Change

- New UI-independent `EditLineNavigationGuard` owns one exclusive
  navigation transition at a time and tracks request generations for
  independently triggered asynchronous refreshes.
- Next, Previous and Jump select via the same guarded transition. A pending
  autosave/validation cannot race with a second navigation tap. Relative
  selection is computed after any save-induced cue reordering.
- Jump now validates time and honors the existing navigation-autosave
  preference rather than silently leaving unsaved draft text behind.
- Cue loading validates the *requested* index and updates controllers,
  initial values, subtitle preview and deferred seeks only when mounted and
  the request generation remains current.
- Out-of-range requests and failed collection reads do not create a bogus
  subtitle or overwrite the active selection. In edit/new-cue mode, only a
  request for the next available slot can show an unsaved empty cue.
- The guard invalidates all outstanding requests on route disposal.

The change is scoped to Editor/Edit Line Flutter lifecycle and state. It
does not change Isar or `.msone` schemas, Android SAF, export encoding,
native media decoding, playback engine, themes or desktop UI.

## Regression tests

`test/edit_line_navigation_guard_test.dart` covers:
- Competing async cue reloads completed in reverse order.
- Duplicate taps during a delayed save/route transition.
- Disposal invalidating a pending refresh and blocking new actions.
- Recovery of the navigation lock after an async failure.
- Generation invalidation even when the newer request has not completed.

## Verification

[GitHub Actions Linux run 39812415589](https://github.com/anzilr/SubtitleStudio/actions/runs/39812415589)
finished successfully with **687 Flutter tests passed** and **zero analyzer
issues** (`flutter analyze`: `No issues found`). The full suite gained
five passing regressions over CP90 R8. Windows/macOS file-host checks are
not required for this state-only batch, and no native builds run in CI.

## Remaining and known limitations

- Native Android Back, video seek, system lifecycle and media_kit hot-restart
  issues still require CP93 physical-device acceptance.
- Further CP90 Editor/UI boundary work, CP91 visual checkpoint history,
  CP92 cleanup and CP93 project/platform acceptance remain.
- Appearance and experimental waveform work remain deferred, while the
  separate desktop workspace preview remains isolated.
