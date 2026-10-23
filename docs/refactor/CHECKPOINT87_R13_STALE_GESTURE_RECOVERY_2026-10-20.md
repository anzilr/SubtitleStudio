# CP87 R13 — Conditional stale gesture recovery (Oct 20 2026)

## Android acceptance — PASSED (2026-10-20 18:44 Asia/Riyadh)

Physical device: OnePlus CPH2381, Android 14.
Capture: `cp87_r13_gesture_recovery.log`.
Branch: `refactor/riverpod-architecture`, implementation commit `ab34ec6de5e5343fc31e2203277fbd1c1c6f39c4`, CI gate `39449981599` (539 Flutter tests, zero analyzer issues).

**Root cause confirmed:** `Navigator.userGestureInProgress` remained `true` after the MSone submission route had been popped, disposed, and its transition completed. Flutter 3.47.5 excludes its page-content subtree from hit-testing while a user gesture is in progress, leaving that page's modal barrier as the hit target. The conditional R13 recovery called `NavigatorState.didStopUserGesture()` only after the Editor route was current with its animation fully completed. This reset the stuck flag.

### Direct Logcat evidence

- 18:44:15.026 — main popup menu modal barrier reported removed.
- 18:44:16.438 — choice sheet modal barrier removed.
- 18:44:18.806 — submission screen route popped.
- 18:44:19.349 — submission screen disposed.
- 18:44:19.358 — submission route's overlay finished removing.
- **18:44:19.359** — `MSone flow: navigator gesture at return=true routeSettled=true`.
- **18:44:19.362** — `MSone flow: recovered completed Android Back gesture; remaining=false`.
- 18:44:19.371 — Navigator trace reports `gestureInProgress=false` and two expected routes: Home and current Editor, with no popped routes still mounted.
- 18:44:19.802 onward — Editor receives 12 initial pointer events; hit-test paths reach `InkWell`/Editor content rather than a `ModalBarrier`.
- 18:44:32.676 — Editor route popped; `gestureInProgress=false`.
- 18:44:33.928 — Home receives pointer event; its hit test reaches the session card and session selection navigates to Editor again.
- 18:44:35.332 onward — the reopened Editor receives further pointer events.
- Across the captured post-return probe: **19 Editor pointer events**, **one Home pointer event**, **20 root pointer-down events**.
- No `SIGSEGV`, `Fatal signal`, or app ANR recorded in this capture.

**Acceptance:** CP87's MSone Back → Editor/Home touch-loss regression is **FIXED / DEVICE VERIFIED** for this reproduction on CPH2381. Automated tests plus the physical-device evidence confirm the mechanism and targeted mitigation. Wider-device Android compatibility is not yet established.

**Separate open issue:** Flutter hot restart after native media-kit player initialization can still trigger a `libmpv.so` SIGSEGV; this test did not hot restart. Do not conflate this native hot-restart issue with the now-resolved Back/touch-freeze incident. The experimental pinned-upstream media_kit branch still requires native Android qualification.


R12 physical Android log confirms the Editor's own settled page barrier receives all taps after MSone submission Back; after Editor exits, Home's own page barrier receives taps instead. Both page content overlay entries are mounted. No MSone route remains. No new native crash.

In Flutter 3.47.5, _ModalScopeState wraps page content in IgnorePointer while navigator.userGestureInProgress is true (or route animation is reversing). A platform predictive-back cancellation may leave the gesture flag true after the MSone page has completed. R12 does not itself log that flag, so this remains a hypothesis.

R13 checks navigator.userGestureInProgress after submissionRoute.completed and calls navigator.didStopUserGesture() ONLY when the prior Editor route is current with a completed animation. Debug route descriptions now report gestureInProgress. New Flutter regression starts a gesture without stopping it, pops the submission page, then verifies Editor and Home taps work.

No manual overlay removal, no native package or database modifications. The independent media_kit hot-restart SIGSEGV remains open.

Device gate: run clean debug on CPH2381; capture cp87_r13_gesture_recovery.log; Home -> Editor -> Submit to MSone -> Existing Translator -> Android Back -> tap editor -> Back -> tap Home. Find 'MSone flow: navigator gesture at return=', 'recovered completed Android Back gesture', 'MSone input: EDITOR pointer'. Do not hot restart.
