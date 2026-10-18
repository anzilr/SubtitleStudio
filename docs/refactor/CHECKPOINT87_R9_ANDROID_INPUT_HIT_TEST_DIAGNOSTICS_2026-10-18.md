# Checkpoint 87 R9 — October 18 Android input-freeze forensics

**Date:** 2026-10-18 18:10 Asia/Riyadh  
**Device:** OnePlus CPH2381, Android 14  
**Status:** Root cause **not yet identified**. New diagnostics delivered for capture; no speculative native fix.

## Oct 18 evidence, separated from retained Oct 17 crash buffer

The newly supplied `cp87_r8_touch.log` is a UTF-16 Windows capture
containing **41,921 lines**. Its crash buffer retains an older
`Fatal signal 11 (SIGSEGV)` at **2026-10-17 00:23:52**, PID 2293:
the previously reported native `libmpv.so` failure after hot restart.
**There is no new SIGSEGV, uncaught Java exception or ANR in the Oct 18 log.**
The Oct 18 process PID is **20660**, and it continues running, rendering
and handling system navigation after the failure.

Key timeline on October 18:
- **18:08:56.381**: `MSone flow: main menu modal barrier removed`.
- **18:08:58.782**: `choice sheet modal barrier removed`.
- **18:09:02.668**: `MsoneSubmissionScreen route pop: didPop=true`.
- **18:09:03.154**: submission page disposed.
- **18:09:03.158**: `submission route overlay removed`, then
  `returned to editor; mounted=true`.
- **18:09:03.159**: `staleLoader=false`; root pointer probe armed.
- **18:09:04.100–18:09:06.626**: 9 root `PointerDown` events reach
  Flutter while the editor's own listener records **zero**.
- **18:09:07.777–07.793**: Android Back triggers asynchronous editor
  PopScope and successful route pop.
- **18:09:07.896**: Home fetches 3 sessions and resolves last edited 1.
- **18:09:08.321**: Editor disposed and media output starts cleanup.
- **18:09:09.609–10.762**: 3 further root `PointerDown` events reach
  Flutter on Home, still reportedly untouchable.
- **18:09:15.300 onward**: foreground resumption triggers more Home
  session loads; process remains alive.

**Strongest inference:** the pointer event reaches Flutter's root
Navigator wrapper but is hit-tested somewhere other than the Editor
and Home render trees, or its gestures do not complete. The root listener
does not establish a global UI stall; the ongoing navigation/Isar work
further argues against a complete isolate deadlock.

**Ruled out for this reproduction:** leftover `IsolatedLoaderController`
(`staleLoader=false`); early popup/choice/form route teardown
(all completed before returning). The affected original 895-line
subtitle session is still in the database.

## R9 evidence-collection implementation

- `lib/screens/msone_input_diagnostics.dart`: on the first 12
  root pointer-downs, call Flutter's supported
  `RendererBinding.hitTestInView` and log up to 24 hit-test path
  entries, including each `RenderObject`'s `DebugCreator` widget type.
  This should expose the actual interceptor (e.g., a route's
  `ModalBarrier`, an `AbsorbPointer`, an invisible overlay, or
  an ordinary input target).
- Log root pointer-up and pointer-cancel so an incomplete platform
  gesture is distinguishable from a misdirected hit test.
- Add in-editor and Home-specific pointer counts to correlate with
  root events. The bounded debug probe captures up to 24 downs
  and stops. No release-mode changes to input dispatch.
- Add widget test for hit-test capture behind a deliberately blocking
  dialog and root pointer up; CI gate required.

This is a **diagnostic checkpoint**. Do not claim that R9
resolved the observed Android input failure until a concrete
hit-test path identifies the culprit and the corresponding
fix is confirmed on-device.

## User device steps

Pull branch, quit existing Flutter process, launch via
`tool/run_android_clean_debug.ps1`, and in another terminal run
`tool/capture_android_back_log.ps1 -Fresh`. `-Fresh` optionally
clears stale *logcat buffers only*, not app data, ensuring the
captured crash buffer cannot be misread as a new native signal.
The option is disabled by default.

Reproduce existing MSone workflow, tap several different UI
targets after Back, then Back to Home and tap again. Stop recording
with Ctrl+C and upload `cp87_r9_touch.log` plus Flutter console.
Look for `MSone input: HITTEST`, `ROOT pointer-up`,
`EDITOR pointer` and `HOME pointer` to identify the target.
Avoid debug hot restart until after evidence capture,
as it has its own libmpv lifecycle issue.

An optional isolation check is to repeat in a session **without
an attached video**, to determine whether the persistent media player
or another app-level overlay is necessary to trigger the freeze.
