# CP87 R13 — Conditional stale gesture recovery (Oct 20 2026)

R12 physical Android log confirms the Editor's own settled page barrier receives all taps after MSone submission Back; after Editor exits, Home's own page barrier receives taps instead. Both page content overlay entries are mounted. No MSone route remains. No new native crash.

In Flutter 3.47.5, _ModalScopeState wraps page content in IgnorePointer while navigator.userGestureInProgress is true (or route animation is reversing). A platform predictive-back cancellation may leave the gesture flag true after the MSone page has completed. R12 does not itself log that flag, so this remains a hypothesis.

R13 checks navigator.userGestureInProgress after submissionRoute.completed and calls navigator.didStopUserGesture() ONLY when the prior Editor route is current with a completed animation. Debug route descriptions now report gestureInProgress. New Flutter regression starts a gesture without stopping it, pops the submission page, then verifies Editor and Home taps work.

No manual overlay removal, no native package or database modifications. The independent media_kit hot-restart SIGSEGV remains open.

Device gate: run clean debug on CPH2381; capture cp87_r13_gesture_recovery.log; Home -> Editor -> Submit to MSone -> Existing Translator -> Android Back -> tap editor -> Back -> tap Home. Find 'MSone flow: navigator gesture at return=', 'recovered completed Android Back gesture', 'MSone input: EDITOR pointer'. Do not hot restart.
