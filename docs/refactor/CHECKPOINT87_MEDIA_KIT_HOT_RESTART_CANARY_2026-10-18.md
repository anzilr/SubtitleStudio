# CP87 — Isolated media_kit hot-restart canary

**Branch:** `experiment/cp87-mediakit-upstream-restart` (do NOT merge without physical device confirmation).

**Observed failure:** Android 14 / OnePlus CPH2381, 2026-10-18
18:17:43+03, PID 24771. Immediately after Flutter hot restart
`NativeReferenceHolder` detects one previous native player reference,
invokes old-handle cleanup, and native Thread-8 crashes with
`SIGSEGV` at PC `0x760a800090`, frame #01 in `libmpv.so` at
`0x407c58`. This is a **second** failure after the separate, earlier
MSone route-return **touch freeze**; hot restart was attempted only to
recover from the input failure. Avoid conflating root causes.

## Hypothesis and upstream evidence

The application resolves the latest published
`media_kit 1.2.6` from pub.dev. It uses a native reference holder that
sends `quit` to previous native handles after hot restart; callbacks
into the old Dart isolate can be stale.

Unreleased upstream `media_kit` commit
`c533e446755f51cf53c7e57aea873f2aa5355f81` contains:
- In `nativeEnsureInitialized`, a call to
  `mpv_set_wakeup_callback(handle, nullptr, nullptr)` **before**
  `mpv_command_string(handle, 'quit')`. Upstream source comment refers
  to older callback trampoline failures.
- In `Initializer.create`, the debug main isolate uses
  `InitializerIsolate` rather than a native `NativeCallable`
  callback that Flutter hot restart may invalidate.

Relevant upstream open issues:
- https://github.com/media-kit/media-kit/issues/1430 (hot restart)
- https://github.com/media-kit/media-kit/issues/1443 (release disposal race)

These modifications are upstream and unproven for SubtitleStudio's
specific device. Upstream issue #1430 remains open; don't claim a fix
based only on a successful Dart CI.

## Experiment boundaries

`pubspec.yaml` in *this branch only* overrides `media_kit` with an
immutable git commit and relative path `media_kit`. The source
version remains `1.2.6`; the lockfile will update when `flutter
pub get` runs locally. CI tests the source's Dart compatibility; it
cannot reproduce an Android libmpv process crash in Ubuntu Flutter tests.

The normal `refactor/riverpod-architecture` branch is untouched. No
user data/Isar schema migration, Flutter UI edits, or changes to
`media_kit_video`, libmpv binaries, or native-event-loop package.
This is a deliberately isolated one-dependency source experiment.

## Device verification

With an existing installed debug application, do **not** clear data
or uninstall unless you have an independently verified backup.

```powershell
git fetch origin
git switch experiment/cp87-mediakit-upstream-restart
flutter pub get
.\tool\run_android_clean_debug.ps1 -Device CPH2381
```

Create a simple editor session with attached video; enter and exit the
MSone submission page. First test normal Back and basic touch response
**without restarting**, because that is the primary user-facing defect.
Then, **only as an optional isolated canary test**, press uppercase
`R` to perform one Flutter hot restart while player is active, capturing
Android main/system/crash Logcat. Do this only after saving edits.
Check whether the old player handle cleanup still causes native SIGSEGV.

If hot restart still crashes, return to known branch and fresh-process
run. If it no longer crashes, test video playback, track switching,
normal player disposal, then Android **profile** and Windows builds.
Do not merge until supported by empirical evidence and independent
verification of the persistent MSone input-freeze bug.
