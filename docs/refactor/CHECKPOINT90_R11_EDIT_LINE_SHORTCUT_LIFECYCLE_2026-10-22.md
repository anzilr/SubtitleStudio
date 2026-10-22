# SubtitleStudio — CP90 R11: Edit Line desktop shortcut lifecycle

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Issue

Edit Line starts registering desktop keyboard shortcuts asynchronously
after initial hydration. Previously a fast Back/navigation disposal could
unregister Edit Line shortcuts before the earlier asynchronous registration
finished, leaving callbacks referencing the disposed screen. The Home
shortcut handoff also had no mounted/lifecycle check after awaiting its
unregister step.

## Implementation

- Introduced `EditLineShortcutLifecycle`, a pure Dart coordinator with
  ordered preparation, registration and terminal close/unregistration.
- If Back closes the route during Home cleanup, Edit Line shortcuts are
  not installed. If the route closes during registration, teardown waits
  for the registration to finish before removing the route's shortcuts.
- Route-owned callback wrappers check `mounted` and the lifecycle's
  `isActive` flag so stale shared shortcut handlers cannot access
  disposed widget state.
- Partial-registration errors are reported, but teardown still releases
  route-specific shortcuts. Cleanup is idempotent.
- Existing parent Editor shared-shortcut ownership, UI layout, Isar/`.msone`
  format, native file access, and `media_kit` implementation remain
  unchanged.

## Test scope

Six new tests exercise closure during Home handoff, disposal during
registration, never-opened routes, partial failures, guarded callbacks,
and repeated activation.

## Verification

CP90 R10's earlier analyzer failed before tests because the video
visibility button still used the old, parameterless readiness helper.
The follow-up repair updates that call site and invalidates old hidden
player seeks. The combined R10/R11 Linux Flutter gate covers both code
changes and their tests. Record exact results only after the run completes. Do not run
Windows/macOS-specific checks or native platform builds.

## Updated native stability status

On October 22 the user reported the previous `media_kit` hot-restart
crash no longer exists. Treat it as resolved by user observation;
continue normal playback and route-lifecycle smoke acceptance in CP93
without listing this crash as a current blocker.

## Final verified result

The final combined [R10/R11 Linux CI run 39816216928](https://github.com/anzilr/SubtitleStudio/actions/runs/39816216928)
passed **701 Flutter tests** and **zero analyzer issues**. This verifies
the six new desktop shortcut lifecycle cases, the eight R10 media request
regressions, and all pre-existing suite tests.

An intermediate analyzer failure was caused by R10's old video-visibility
seek-helper call, corrected in
[`5a7d251`](https://github.com/anzilr/SubtitleStudio/commit/5a7d25148d64923841be1092bd9590cb1d850a9b).
The successful gate is the authoritative acceptance result. GitHub
Actions ran dependency resolution, analysis, and Flutter tests only.

## Remaining

Finish remaining CP90 Editor/service ownership audit, then CP91 checkpoint
history and compact Edit Line UX, CP92 cleanup and CP93 native acceptance;
integrate the existing desktop preview with the accepted shared core.
