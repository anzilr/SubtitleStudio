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

CP90 R10's prior Linux job remained queued without receiving a runner.
The batched R11 Linux Flutter gate will cover both R10 and R11 test
changes. Record exact results only after the run completes. Do not run
Windows/macOS-specific checks or native platform builds.

## Updated native stability status

On October 22 the user reported the previous `media_kit` hot-restart
crash no longer exists. Treat it as resolved by user observation;
continue normal playback and route-lifecycle smoke acceptance in CP93
without listing this crash as a current blocker.

## Remaining

Finish remaining CP90 Editor/service ownership audit, then CP91 checkpoint
history and compact Edit Line UX, CP92 cleanup and CP93 native acceptance;
integrate the existing desktop preview with the accepted shared core.
