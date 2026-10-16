# Checkpoint 87 R8 — Cross-route touch freeze after MSone

**2026-10-17 — Device:** CPH2381 Android 14. **Branch:** `refactor/riverpod-architecture`.

## User-observed sequence, confirmed against the new Flutter log

1. Open editor, 895 subtitle lines load from Isar and MKV video initializes.
2. Main menu → Submit to MSone → Existing Translator.
3. Android Back pops MSone route: `didPop=true`.
4. `MSone flow: returned to editor; mounted=true`.
5. `EditScreen MSone: resumed editor; staleLoader=false session=1`.
6. `MSone flow: editor rendered a frame after Back`.
7. User reports taps completely unresponsive; no matching five editor pointer logs.
8. Android Back triggers `EditScreen lifecycle: pop didPop=false`, then request/pop `didPop=true`.
9. Home fetches all **three sessions** successfully at 01:12:58, yet user reports Home still unresponsive to touch.
10. Editor disposes and the media_kit video output is cleaned up. No native SIGSEGV, ANR, or Flutter framework exception was present in this log.

**Consequence:** Full Dart UI-thread deadlock is unlikely; route transitions and database loading continued. R7's stale `IsolatedLoaderController` is not responsible for this reproduction (`staleLoader=false`). A root Navigator overlay/modal barrier intercepting pointer hit-tests is a plausible explanation, **not yet proven**.

## Candidate remedy

Flutter's `Navigator.push`/`showMenu` result futures resolve as a pop begins, *before* their departing OverlayEntries are removed. `TransitionRoute.completed` is the documented post-removal signal: https://api.flutter.dev/flutter/widgets/TransitionRoute/completed.html

The MSone route pipeline is popup menu → selection bottom sheet → submission page → Editor → Home. R8 captures the main popup route using a Builder inside the MSone popup entry and awaits its `completed` after menu selection. It captures the sheet's `ModalRoute` and awaits `completed` before pushing the form. After form Back, it awaits `MaterialPageRoute.completed` before resuming Editor and accepting input. This prevents accidentally overlapping exits that retain hit-testable modal barriers.

## Diagnostics and tests

- Debug-only `MaterialApp.builder` Listener above Navigator logs 12 post-MSONE pointer-down events, even if a Navigator barrier consumes inner taps. No release-mode Listener.
- Debug-only `NavigatorObserver` identifies unexpected routes when return-to-Home occurs.
- Editor's existing first five pointer probes remain for side-by-side comparison.
- The added `msone_popup_chain_overlay_regression_test.dart` goes through the real popup menu, real choice sheet, fake submission form, taps Editor after Back, exits to Home, and taps Home. Other existing navigation and loader-overlay tests remain.

The investigation remains open until a physical CPH2381 confirms Editor and Home touch inputs work. The independent `libmpv.so` fatal native signal observed after *manual hot restart* also remains open.

## Device qualification

```powershell
git pull --ff-only origin refactor/riverpod-architecture
.\tool\run_android_clean_debug.ps1 -Device CPH2381
```

If it freezes again, **do not hot restart**. Record Flutter console and Logcat while tapping both screens and using Android Back. Look for `MSone flow: main menu modal barrier removed`, `choice sheet modal barrier removed`, `submission route overlay removed`, `MSone input: ROOT pointer-down`, and `EditScreen MSone: editor received pointer`. The absence/presence of each will separate Navigator barriers, platform input dispatch and editor widget interception.

## Automated verification completed

**[CI 38975383284 — SUCCESS](https://github.com/anzilr/SubtitleStudio/actions/runs/38975383284)** at `6a90cb8801d327f394f8e776500605d943ff417a`:

- **536 Flutter tests passed, 0 analyzer issues.**
- New `msone_popup_chain_overlay_regression_test.dart`: passed, including actual popup menu selection, choice sheet, form Back, editor tap, Home Back, Home tap, and explicit modal-overlay removal at each step.
- Original editor route-navigation tests and existing 535-regression baseline passed.
- This is **automated verification only**. Android CPH2381 touch-freeze issue remains **OPEN** until physical-device retest confirms both Editor and Home are responsive.
