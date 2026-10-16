# SubtitleStudio CP87 R5 — MSone Back, extraction assertion, and Android native hot restart

**Date:** 2026-10-17 (Asia/Riyadh)  
**Branch:** `refactor/riverpod-architecture`  
**Android device:** CPH2381 / OnePlus / Android 14  
**Incident log:** user-provided `Pasted text(20261016-210407).txt` (980 lines)  
**Source implementation:** [commit `cc0f30b`](https://github.com/anzilr/SubtitleStudio/commit/cc0f30b83fb07087e598ab55368a68d71ebb5d7e)  
**Regression tests:** `test/msone_submission_flow_navigation_test.dart`,
`test/extraction_checkbox_material_contract_test.dart`

## Timeline and root-cause separation

At 00:01:34, Isar loaded 895 primary subtitle lines. A missing secondary
track logged a warning but **did not abort the editor**; initialization
completed, proving CP87 R2 works on the Android device.

At 00:02:24, the framework repeatedly threw a fatal-class
`ListTile background color or ink splashes may be invisible` assertion.
The decorated parent color (alpha=0.05) and border match the two
`CheckboxListTile` processing options in `subtitle_extract_options_sheet.dart`.

After embedded-track FFmpeg extraction and the MSone interaction, the
log captured `MsoneSubmissionScreen route pop: didPop=true` followed by
additional regular input messages. **Only after the operator then manually
initiated `Performing hot restart...`** did media_kit report
`NativeReferenceHolder: Disposing` and Android report a
`SIGSEGV (11)` with a `libmpv.so` backtrace. This confirms a
native crash following debug hot restart; it does **not** demonstrate
that the MSone Back action directly invoked the crashing native code.

Independent upstream references:
- media-kit/media-kit issue #1430: 2026 Android hot-restart crashes with
  `NativeReferenceHolder: Disposing`.
- issue #1340 and #1397: Flutter/media-kit hot-restart lifecycle issues.
- issue #1443: a different reported native player-disposal race.

## Implemented

1. Removed the unsafe modal transition in `screen_edit.dart` where the
   application immediately called `Navigator.push(context)` with a
   sheet `BuildContext` that had just been popped.
2. New `showMsoneSubmissionFlow` waits for the selection-sheet result
   (`'main'`, `'fresher'`, or cancellation), checks that the editor
   context is still mounted, then pushes via that parent context.
   The modal card design, choices, and submission page are preserved.
3. Dedicated widget tests exercise MSone main/fresher selection, Android
   system Back, repeated open/back, and Back-to-cancel from the picker.
4. Both subtitle extraction processing `CheckboxListTile` parents now
   use `Material(color:, shape:, clipBehavior:)` instead of a decorated
   opaque `Container`, so Flutter can paint tile ink/background
   properly; a source contract test checks both sites.
5. A disposal breadcrumb in MSone Submission helps distinguish a route
   that was popped from one actually torn down.
6. No Isar schema changes, data resets, theme expansion or media_kit
   upgrades were made during this checkpoint.

## Required separate native QA gates

**MSone Back test — no Flutter hot restart**
1. Close the running app process and relaunch fresh using
   `flutter run --debug -d CPH2381` or a newly installed debug APK.
2. Enter the editor, pick MSone Existing Translator, press device Back.
   Repeat for Fresher and for Back while only the choice sheet is open.
3. Confirm the editor is still responsive and the MSone disposal breadcrumb
   appears. If it hangs *without any hot restart*, capture Logcat and
   an Android bugreport or ANR trace.

**Native media_kit hot-restart reproduction — independent test**
1. Open a media-backed editor in debug mode, then press `R` for hot restart
   with video active. Record Android crash buffer and FFmpeg/media-kit
   logs (this is expected to remain a known open blocker).
2. Repeat after backing all the way out of the editor, ensuring player
   disposal, before pressing `R`. Compare outcomes.
3. Repeat normal Back in an Android profile or release build to separate
   debug-isolate hot-restart behavior from user navigation.
4. Do not claim production crash regression fixed without successful
   native validation. No Dart-only patch can be assumed to repair the
   upstream native callback/lifetime failure.

**Do not** run `adb shell pm clear`, uninstall, or clear application data:
the recovered project and checkpoint history remain valuable.

## R5 supplemental Material isolation

A closer match to the user's repeated `ListTile` assertion is the
`contentPadding: EdgeInsets.zero` of the Karaoke Effect `RadioListTile`
controls, inside a decorated panel using precisely the reported ~5%-opaque
`onSurface` color and 12%-opaque border. The Karaoke/Typewriter color-picker
`ListTile` controls and both recommended-position banner
`CheckboxListTile` controls also used decorated ancestors without a local
Material. This checkpoint now gives all those tiles an immediate transparent
`Material` ancestor so ink is painted above their decorated panels.
A widget regression renders the Karaoke radio controls under Carbon Zero Dark
and Classic to catch the actual framework assertion, rather than relying
only on source-level tests.
