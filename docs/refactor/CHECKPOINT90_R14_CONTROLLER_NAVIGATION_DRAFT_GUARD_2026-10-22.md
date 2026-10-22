# SubtitleStudio — CP90 R14: Controller navigation/draft lifecycle audit

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Problem

R13 prevented direct controller navigation when an unsaved draft already
existed and rejected out-of-order Isar reads when a newer selection was
accepted. It did not protect a *new edit made while a navigation read
was in flight*: the check occurred before the `await`, so a late fetched
subtitle could replace text or timing changed while the user was typing.
The controller also duplicated the generation logic already exercised in
the Edit Line route's `EditLineNavigationGuard`.

## Changes

- Replace `_navigationRequestEpoch` in the Riverpod Edit Line controller
  with a controller-owned instance of the tested
  `EditLineNavigationGuard`. The widget keeps its existing independent
  route-scoped guard.
- Actual source, translated-text or start/end-time changes invalidate
  pending controller Isar navigation and reset the loading flag, without
  discarding the newly edited text or time validation.
- A no-op text update leaves the pending request intact.
- A successfully committed cue, an external widget cue selection, or a
  newer navigation request invalidates older pending controller loads.
- Dispose the controller's guard with its existing stream and timer
  resources so no late request can mutate an obsolete Riverpod route.
- Preserve direct Save's detached checkpoint service, the source/edited
  null-versus-empty distinction, ordered project rows, session state,
  current mobile layout, Isar schema and `.msone` data compatibility.

## Regression coverage

Five tests extend `test/edit_line_controller_persistence_test.dart`:
1. A translated-text draft written during a delayed navigation wins.
2. Newly typed source text similarly prevents old fetched cue overwrite.
3. Timing edits retain validation errors and block navigation with a draft.
4. A no-op translation update does not spuriously cancel navigation.
5. Of two overlapping controller navigation reads, the latest wins.

Tests use isolated production-schema Isar databases and scoped Riverpod
controllers. Existing checkpoint, encoding, waveform, UI, export and
subtitle tests remain in the full suite.

## Verification

The final [Linux Flutter-only CI run #39822724754](https://github.com/anzilr/SubtitleStudio/actions/runs/39822724754)
completed successfully with **718 Flutter tests passing** and
`flutter analyze` reporting **No issues found**. This includes the five
new Isar/Riverpod race tests and the existing regression suite. The
verified source commit is
[`67285d9`](https://github.com/anzilr/SubtitleStudio/commit/67285d975a2f4fb81834422bfc6198e2bd05fff6).
No native application builds or platform-specific host matrices ran.

## Remaining

Finish a short CP90 handoff audit of controller ownership boundaries,
then CP91 visual, Git-style checkpoint history and compact mobile Edit
Line UX; CP92 code cleanup/performance; CP93 real-device acceptance and
portable project compatibility. The previously reported native
`media_kit` hot-restart crash was reported resolved on device and is
not an active blocker.
