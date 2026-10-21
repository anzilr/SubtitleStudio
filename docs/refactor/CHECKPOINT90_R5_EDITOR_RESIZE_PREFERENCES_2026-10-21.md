# SubtitleStudio — CP90 R5: Editor resize preference ownership

Date: October 21, 2026
Branch: `refactor/riverpod-architecture`
Verification: Linux Flutter analyzer/full suite pending

## Problem and refactor

Editor desktop split ratio and mobile video split ratio were debounced by
independent timers in the screen widget. Screen disposal canceled those
timers without persisting their pending values. A rapid drag followed by
Back could therefore revert the last layout the next time the Editor opened.

`EditorResizePreferenceCoordinator` now owns both timers and serializes
writes within each preference channel. The Editor Riverpod controller stores
the most recent drag position immediately, then delegates persistence to
injected repository methods. When the route-scoped controller is disposed,
the coordinator flushes both pending values before closing. The writer
closures capture `VideoRepository` while the provider is active, avoiding
ref/widget/media access during asynchronous route teardown. Save failures
are reported by type and cannot permanently block later drag changes.

The Editor widget retains its same split UI and drag callbacks, but no longer
owns or cancels persistence timers. The `EditLine` screen still has its own
legacy resize timers and requires a separate scoped follow-up; this change
does not claim to fix every layout on every route.

## Regression plan

`test/editor_resize_preference_coordinator_test.dart` covers desktop and
mobile debounce intervals, last-value-wins coalescing, independent channels,
flush-on-dispose, safe repeated flush/late calls, write ordering when the
first save is still pending, and recovery after write failure.

Full Linux Flutter `pub get`, `analyze` and `test` run through GitHub Actions
without platform builds. This checkpoint changes UI state/preferences only,
not Android SAF, local file paths or encoding; the optional Windows/macOS
file-host matrix is intentionally not requested.

## Boundaries / remaining work

- A queued preference write is flushed when the Flutter route is disposed;
  immediate OS process termination cannot guarantee asynchronous disk I/O.
- No Isar schema, `.msone` checkpoint representation, file picker, Source
  View, native media player, waveform experiment or mobile appearance changes.
- Continue CP90 remaining Edit Line/controller boundaries, CP91 mobile
  history UX, CP92 cleanup and CP93 native acceptance. The previously
  reported media_kit hot-restart SIGSEGV remains a distinct issue.
