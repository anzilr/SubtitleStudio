# CP87 R10 — Confirmed new hot-restart SIGSEGV and upstream source canary

**Date:** October 18, 2026, 18:17:43 Asia/Riyadh  
**Android:** OnePlus CPH2381 (Android 14 / arm64)  
**App:** `org.malayalamsubtitles.studio` / build 3.0.0+30

## Updated incident timeline and classification

The user confirms a repeat of the previously known failure following
an operator-initiated hot restart. The **new** console contains:

```
Restarted application in 3,314ms.
media_kit: NativeReferenceHolder: Located ...
media_kit: NativeReferenceHolder: Found 1 reference(s).
media_kit: NativeReferenceHolder: Disposing:
F/libc (24771): Fatal signal 11 (SIGSEGV), SEGV_MAPERR,
  fault addr 0x760a800090, tid 25498 Thread-8
#00 0x760a800090 <unknown>
#01 0x407c58 libmpv.so
#02 0x404be8 libmpv.so
```

This new PID **24771** tombstone is timestamped
**2026-10-18 18:17:43.377+03** and must not be confused with
the **2026-10-17 00:23:52** stale crash-buffer tombstone from the
earlier `cp87_r8_touch.log` file.

**Primary user-facing incident:** after MSone submission Back,
Editor input fails; Home also fails to accept taps after another
Android Back. The Oct 18 R8 trace proved root Flutter `PointerDown`
events (nine in Editor, three in Home), no inner Editor hit,
`staleLoader=false`, and all R8 modal barriers removed. R9
hit-test-path diagnostics on normal debug builds remain needed to
identify the actual input hit-test interceptor or incomplete pointer
gesture. The UI freeze occurs **before** hot restart.

**Secondary incident:** Flutter hot restart with an active/uncleaned
libmpv Player invalidates the old Dart isolate while native mpv
references persist. The next isolate's `NativeReferenceHolder`
attempts cleanup through `libmpv.so`, causing native SIGSEGV.
This native failure is reproduced in the user's Oct 18 console and
is independent of the initial input freeze.

## Upstream research

SubtitleStudio resolves `media_kit 1.2.6` via `pubspec.lock`.
The upstream GitHub `main` branch's
`media_kit/lib/src/player/native/player/real.dart` explicitly clears
`mpv_set_wakeup_callback` before sending `quit` to orphaned
references on hot restart. Its
`media_kit/lib/src/player/native/core/initializer.dart` switches
debug main-isolate callback notification to an isolate-based
initializer. These changes are not in the published 1.2.6 package,
but even upstream still tracks an open hot-restart issue, so no fix
can be claimed from source inspection alone.

- https://github.com/media-kit/media-kit/issues/1430
- https://github.com/media-kit/media-kit/issues/1443
- https://github.com/media-kit/media-kit/blob/main/media_kit/lib/src/player/native/player/real.dart

## Safely isolated experiment

Experimental branch:
`experiment/cp87-mediakit-upstream-restart`, created from
`refactor/riverpod-architecture` at `865e418`, pins exact upstream
source commit `c533e446755f51cf53c7e57aea873f2aa5355f81`
as a git dependency override. CI checks Dart compatibility and unit
tests but **not Android arm64 native process lifetimes**. No stable
dependency or native package is replaced in this branch.

Do not merge experimental changes until a CPH2381 hot-restart
reproducer, normal Editor/Home navigation, subtitle and video playback,
Android profile, and Windows smoke tests succeed. The separate
input-freeze fix remains a higher-priority requirement.

## Safe ongoing development

Avoid uppercase R with an active video `Player` on the stable
media_kit dependency. Restart the Android process using
`tool/run_android_clean_debug.ps1 -Device CPH2381`, which force-stops
the package without clearing app data. Save edited subtitles before
starting/restarting a test process. To capture a fresh-only tombstone,
use `tool/capture_android_back_log.ps1 -Fresh` in another terminal;
this clears Logcat buffers only, not the application database.
