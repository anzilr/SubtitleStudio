# CP87 R6 — Native Android hot-restart crash: confirmed independent of MSone route pop

**Date:** 2026-10-17 00:24 Asia/Riyadh  
**Flutter CI:** [38969567231](https://github.com/anzilr/SubtitleStudio/actions/runs/38969567231) — **SUCCESS: 534 Flutter tests, 0 analyzer issues** for code `082134e`. Native hot-restart bug NOT fixed.  
**Device:** CPH2381 OnePlus Android 14, arm64  
**Affected package versions:** media_kit 1.2.6, media_kit_video 2.0.1,
media_kit_native_event_loop 1.0.9, media_kit_libs_video 1.0.7
(from `pubspec.lock`).

## Grounded timeline from both 2026-10-17 device logs

- 00:23:07 `EditController.initialize` loads 895 primary subtitle lines.
- 00:23:41.480 `MsoneSubmissionScreen route pop: didPop=true`.
- 00:23:41.910 `MsoneSubmissionScreen disposed after route pop`.
- 00:23:42.918, 00:23:43.362, 00:23:43.765 device delivered further tap events.
- Debug console operator initiated `Performing hot restart...`.
- 00:23:52.530 `NativeReferenceHolder: Located`; at 52.538
  `Found 1 reference(s); Disposing` old libmpv player reference.
- 00:23:52.544 Android records **Fatal signal 11 (SIGSEGV)**
  in native libmpv Thread-8, PID 2293, PC 0x0000007614500090.
  Frame #00 points to an invalid `[anon:dart-code]` callback and
  frames #01–#09 are in `libmpv.so`.
- 00:23:53.812 Android debugger emits a full tombstone; ActivityManager
  kills the process. Native crash is proven by independent
  `cp87_msone_back.log` (UTF-16 LE from Windows PowerShell), not only
  by Flutter's `Lost connection to device`.

The **normal Back path is not shown generating a native crash**, but the
user confirms the returned editor was already frozen and unresponsive.
They invoked Flutter hot restart **because of that freeze**. Therefore
we must treat the **Back-return freeze as the primary incident**. The
subsequent libmpv SIGSEGV occurred only during the attempted restart.
The native tombstone does not explain why the editor initially froze.

## Root-cause hypothesis (not yet a patch)

Media_kit retains native mpv handles across a Flutter hot restart in its
`NativeReferenceHolder`. On the next isolate initialize, media_kit recovers
an old pointer and attempts to send a quit command; the old mpv thread
may invoke a freed Dart FFI callback. This failure closely matches
upstream [media-kit #1430](https://github.com/media-kit/media-kit/issues/1430),
[#1340](https://github.com/media-kit/media-kit/issues/1340),
[#1397](https://github.com/media-kit/media-kit/issues/1397),
and the related production disposal race
[#1443](https://github.com/media-kit/media-kit/issues/1443).
This is native/FFI lifecycle code in a third-party dependency. Do not
claim the MSone route or the Material sheet patches fixed it.
Do not suppress SIGSEGV by skipping libmpv cleanup: that can strand a
native handle or cause a later use-after-free.

## Safe developer workflow

Exit the existing flutter run debugger with `q`, then run from repository root:

```powershell
.\tool\run_android_clean_debug.ps1 -Device CPH2381
```

In another PowerShell terminal capture:

```powershell
.\tool\capture_android_back_log.ps1 -Device CPH2381 -Output cp87_android_back.log
```

No install/uninstall/pm clear is used; user Isar data is preserved.
Do not use uppercase `R` (hot restart) while a live mpv player
exists. Hot reload (`r`) and a full native process relaunch are
different development workflows.

## Acceptance matrix / next diagnostic action

1. Launch a fresh process, open the editor with video attached,
   enter MSone Existing Translator, press Android Back, and try to
   scroll/tap the editor **without hot restarting**.
2. Repeat Fresher and Back from just the choice sheet.
3. Check `MSone flow: returned to editor` and
   `MSone flow: editor rendered a frame after Back` diagnostics.
   If the editor is genuinely unresponsive without hot restart, capture
   input-dispatch ANR, Flutter error and UI behavior separately.
4. When stable, qualify media_kit hot restart in an isolated experimental
   branch and a standalone player reproducer. Validate normal player
   disposal in profile/release too (upstream #1443).
5. This native issue remains **open**. The 533 Flutter tests in CP87 R5
   cannot exercise the Android mpv FFI callback lifetime.

## R7 correction and mitigation, after direct user clarification

The user explicitly corrected our sequence interpretation: the editor froze
first; the manually initiated hot restart was a **recovery attempt**. We were
wrong to frame the normal Back path as unproblematic merely because the
route popped and disposed. Logcat contains continued Android input delivery
at 00:23:42.918, 00:23:43.362 and 00:23:43.765 after the 00:23:41.910
MSone disposal, but the Flutter console contains no correlated editor-side
interaction. There is no independently recorded ANR in that brief period.

A candidate blocking input path exists in
`lib/widgets/isolated_loader.dart`: `IsolatedLoaderController.show`
inserts a full-screen, hit-testable `OverlayEntry` into the Navigator overlay,
which is not scoped to the editor route. R7 removes a stale entry before and
on return from the MSone route, and logs whether it was present. The next
reproduction must check `EditScreen MSone: resumed editor;
staleLoader=<true|false>` and the following first five editor pointer logs.
If staleLoader is false and events still fail, further investigate
Navigator barriers, route focus, editor isolate stalls and native playback.
**R7 is not an on-device confirmed fix.**
