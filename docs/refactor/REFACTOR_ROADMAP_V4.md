# SubtitleStudio Refactor Roadmap v4

> **ACTIVE PRIORITY RESET — 2026-10-20:** By user decision, **defer further waveform optimization and freeze the CP86 R9–R11 progressive experiment** (do not merge into this branch). Final physical `cp86_r11.log`: 1,000ms 30s seek, R11 sparse canvas paint 35ms after creation, sampled zero-lag, no captured crash; source-specific acceptance only. **Current objective: complete core refactor, then build the desktop UI**, in that order. Start CP88 Source View/file-access unification, then CP89 encoding, CP90 Editor decomposition, CP91 approved outstanding mobile UX, CP92 cleanup/performance and CP93 native/CI acceptance. Only after CP93 begin the PC workspace. This supersedes the historical checkpoint-43 immediate-next-commit sequence and CP86-focused priority notices below. [Current completion plan](REFACTOR_TO_DESKTOP_EXECUTION_2026-10-20.md).


> **CP86 R8 SOURCE RESEARCH — 2026-10-20:** Audited the user-supplied KDE Subtitle Composer archive and pinned Subtitle Edit upstream source `cccac3a`. Subtitle Composer's libavcodec `StreamProcessor` publishes audio frames as they decode, and its zoom worker can display the available *visible interval* before full extraction finishes. Subtitle Edit uses FFmpeg to extract 24-kHz stereo WAV, then compact ~126-peaks/s cache and SIMD min/max generation; neither reference demonstrates materially faster *full* decode on the same Android hardware. Our measured R6 cold-load is 98.47% native FFmpeg. Prioritize an **isolated, flag-gated, seeked 30–60s viewport preview** with absolute PTS, SAF seek/cancel, track-specific cache and device measurements. Only consider a direct native PCM-streaming plugin if viewport extraction is insufficient. No source copied; no runtime changes in this research checkpoint. [Detailed source and experimental plan](CHECKPOINT86_R8_SUBTITLE_COMPOSER_SUBTITLE_EDIT_FAST_WAVEFORM_RESEARCH_2026-10-20.md).


> **CP86 R6 ANDROID PERFORMANCE RESULT + R7 FOLLOW-UP — 2026-10-20:** The CPH2381 source capture `cp86_r6_waveform_perf.log` verifies **137,089 ms cold / 1,953 ms warm**, of which FFmpeg native decoding took **134,990 ms (98.47%)** and peak-buffer conversion **1,881 ms**; zoom metadata took 24 ms. The warm reopen read a validated 41.27 MB V2 compact cache in 1,825 ms. No app SIGSEGV, ANR or fatal framework exception in the capture. Peak-buffer optimization is not the primary path to a two-minute speedup. CP86 R7 introduces per-session decoded-audio-time feedback while full FFmpeg decoding runs, without presenting a misleading percentage. **R7 Flutter CI [39457546723](https://github.com/anzilr/SubtitleStudio/actions/runs/39457546723) passed 546 tests and analysis (one pre-existing informational import lint); native behavior remains unqualified.** Real speed improvements need architecture/profile experiments, including progressive decoding and track/PTS validation. [Detailed CP86 R7 log findings](CHECKPOINT86_R7_NATIVE_DECODE_PROGRESS_2026-10-20.md).


> **CP86 R5/R6 — WAVEFORM PROFILING + PEAK WRITER OPTIMIZATION, OCTOBER 20 2026:** [Combined CI run 39454515948](https://github.com/anzilr/SubtitleStudio/actions/runs/39454515948) **SUCCESS: 543 Flutter tests passed, zero analyzer issues** (head `4ce284d`, code `7e08204` + `874e71a` + epoch-safety correction `c9efe74`). R5 separates FFmpeg extraction timing (`ffmpegMs`), peak reduction (`peakMs`) and peak cache read (`cacheMs`) in the existing waveform processing report. R6 replaces per-sample `ByteData` allocations with a reused 24-KiB buffer while preserving V1/V2 byte layout and FNV checksums; the added golden test validates 60,001 reduced samples across multiple flushes. **This is code-level acceptance, not measured native acceleration.** Android CPH2381 and Windows cold/warm timing, track selection, SAF cache revision, memory, cancellation and playback alignment still need qualification. [R5 report](CHECKPOINT86_R5_ACQUISITION_STAGE_PROFILE_2026-10-20.md) · [R6 report](CHECKPOINT86_R6_PEAK_WRITE_ALLOCATION_OPTIMIZATION_2026-10-20.md). The CP87 R13 Android Back touch fix remains verified and unchanged. `media_kit` Flutter hot restart is a separate deferred native diagnostic, not a regression from this work.


> **LATEST CP87 STATUS — 2026-10-20: ANDROID BACK TOUCH-FREEZE FIX VERIFIED ON DEVICE.** After R12 identified that normal Editor and Home page-route barriers were consuming input, R13 found a stale `Navigator.userGestureInProgress` flag left true after MSone submission Back. A conditional `didStopUserGesture()` after submission-route completion and a settled Editor recovered the input path. In the CPH2381 R13 capture at 18:44:19, `gesture at return=true routeSettled=true` became `remaining=false`; **19 Editor pointer events and one Home event** followed, including reopening the Editor successfully. **R13 CI green: 539 tests, zero analyzer issues**, [run 39449981599](https://github.com/anzilr/SubtitleStudio/actions/runs/39449981599). [Verified R13 report](CHECKPOINT87_R13_STALE_GESTURE_RECOVERY_2026-10-20.md). Earlier R7–R12 touch-freeze notes below are historical and superseded by this finding. **Still open separately:** `media_kit`/`libmpv.so` native Flutter hot-restart SIGSEGV; pinned-upstream canary is not device-qualified.


> **CP87 R10 — NEW 2026-10-18 18:17 NATIVE SIGSEGV CONFIRMED (separate from touch freeze):** Operator invoked Flutter **hot restart** after existing MSone Editor/Home input freeze. On OnePlus CPH2381 Android 14, new PID **24771** found one previous `NativeReferenceHolder` mpv reference at **18:17:43+03**, attempted disposal, then died from **SIGSEGV** in `libmpv.so` Thread-8 (PC `0x760a800090`, frame #01 `0x407c58`). This is **not** the stale Oct 17 crash-buffer record: it is a fresh Oct 18 crash from the user's current console. Stable branch still uses published media_kit **1.2.6**; upstream main contains debug initializer/wakeup callback cleanup changes unpublished to pub.dev. Experimental `experiment/cp87-mediakit-upstream-restart` pins upstream git commit `c533e446755f51cf53c7e57aea873f2aa5355f81` to test without destabilizing this branch. Upstream issues [#1430](https://github.com/media-kit/media-kit/issues/1430) and [#1443](https://github.com/media-kit/media-kit/issues/1443) remain open; **no physical-device native fix has been verified**. [Canary CI 39141372129](https://github.com/anzilr/SubtitleStudio/actions/runs/39141372129): **537 Flutter tests passed**, git dependency resolved; Android native verification pending. The Editor/Home touch-loss bug remains separately open and R9 render hit-test diagnostics are ready for an independent capture.

> **CP87 R9 — OCTOBER 18 ANDROID INPUT FREEZE OPEN:**
> **R9 Flutter CI passed:** [39140091447](https://github.com/anzilr/SubtitleStudio/actions/runs/39140091447) — **537 tests, 0 analyzer issues**, including the modal-barrier hit-test trace test. Android freeze **not yet fixed**. Fresh `cp87_r8_touch.log`
> (PID 20660) shows all R8 menu/sheet/form overlay-removal breadcrumbs,
> `staleLoader=false`, and twelve Flutter root pointer-downs (nine
> in Editor, three in Home) but zero in-editor pointer breadcrumbs.
> Android Back and Home's Isar loads work, so this is not a demonstrated
> isolate deadlock. The only SIGSEGV in the file is an **old Oct 17**
> crash-buffer entry, not a fresh Oct 18 native crash.
> R9 adds a bounded render-layer **hit-test path with DebugCreator widget
> identity**, root UP/CANCEL, and Editor/Home pointer probes. Actual
> touch-intercepting widget still unknown; no fix is claimed.
> [R9 report](CHECKPOINT87_R9_ANDROID_INPUT_HIT_TEST_DIAGNOSTICS_2026-10-18.md).
>
> **CP87 R8 — CROSS-ROUTE TOUCH FREEZE:**
> **Flutter quality gate GREEN:** [CI 38975383284](https://github.com/anzilr/SubtitleStudio/actions/runs/38975383284) — **536 tests passed, 0 analyzer issues** at code commit `6a90cb8`. The new full-popup, full-sheet, form, Editor and Home touch regression passed. Android device freeze still requires verification. On Android CPH2381, after MSone Back, Editor fails to accept taps although `staleLoader=false`, `mounted=true` and a frame rendered; system Back successfully exits Editor, Home loads all 3 sessions but also fails to accept taps. The stale cue-scroll loader hypothesis from R7 is refuted for this reproduction. R8 explicitly synchronizes menu→sheet→form route handoffs against `TransitionRoute.completed`, the documented signal that modal barriers have been removed. A debug-only root hit-test / Navigator probe and popup→sheet→form→Editor→Home touch regression were added. **Candidate mitigation only; device confirmation pending.** [R8 report](CHECKPOINT87_R8_CROSS_ROUTE_TOUCH_FREEZE_2026-10-17.md).

> **CP87 R7 — MSone BACK FREEZE IS THE PRIMARY DEFECT (October 17, 2026):**
> **Flutter quality gate passed:** [CI 38970979346](https://github.com/anzilr/SubtitleStudio/actions/runs/38970979346) — **535 Flutter tests passed, zero analyzer issues**, code `3c2abbb`. Does **not** prove device freeze fixed.
> The user explicitly confirms **the editor became unresponsive immediately
> after Android Back from MSone** and only then initiated Flutter hot restart
> in an attempt to recover. Our previous description of this as a
> hot-restart-only incident was incorrect. Android delivered three additional
> input events at 00:23:42–43 after MSone route pop/dispose but the console
> contains no editor action logs; an ANR has not been captured. At 00:23:52
> the operator-initiated hot restart subsequently caused the separate
> `libmpv.so` native SIGSEGV. These are **two problems** with distinct timing.
> [R7 candidate fix `326ea12`](https://github.com/anzilr/SubtitleStudio/commit/326ea12da5e5c743d36098e79950eddc829de3a0)
> clears potentially stale full-screen cue-scroll `OverlayEntry` before
> and after MSone navigation. It also instruments the first five pointer
> events and records whether a blocking loader was found. This is a
> **hypothesis-driven mitigation**, not a verified on-device freeze fix.
> Flutter analyzer/test gate and physical device retesting are separate.
>
> **CP87 R6 — NATIVE CRASH ISOLATED (October 17, 2026):**
> **Code gate green:** [38969567231](https://github.com/anzilr/SubtitleStudio/actions/runs/38969567231) — **534 tests passed and no analyzer issues**. Native Android hot-restart remains blocked.
> Two complete CPH2381 logs confirm MSone system Back popped and disposed
> its route at 00:23:41, then at 00:23:52 a separately invoked Flutter
> hot restart recovered a stale media_kit native handle and triggered
> **SIGSEGV inside libmpv.so**. The Back route itself did not log a native
> crash, but the user reports that the editor became unresponsive immediately
> after Back and before deciding to hot restart; root cause remains open. Development must now use the
> clean-process debug launcher in `tool/run_android_clean_debug.ps1`
> and keep native mpv FFI callback cleanup as an open platform blocker.
> [R6 report](CHECKPOINT87_R6_NATIVE_HOT_RESTART_DIAGNOSIS_2026-10-17.md).
>
> **CP87 R5 — MSone navigation and confirmed hot-restart crash (October 17, 2026):**
> **Flutter CI succeeded:** [38968179884](https://github.com/anzilr/SubtitleStudio/actions/runs/38968179884) — **533 tests passed, 0 analyzer issues**, at implementation `f121197`. The native hot restart crash is not cleared by this result.
> The CPH2381 full log confirms `MsoneSubmissionScreen route pop: didPop=true`
> *before* the operator triggered `Performing hot restart...`. Then
> `media_kit: NativeReferenceHolder: Disposing` immediately preceded a
> genuine native Android **SIGSEGV in `libmpv.so`**. The log **does not show a
> SIGSEGV caused by the MSone back gesture itself**. This is consistent with
> upstream media_kit hot-restart failures and must be tested separately from
> normal Back navigation on a cold launch.
> The editor caller *did* have an unsafe route transition: it called
> `Navigator.pop(sheetContext)` and immediately called
> `Navigator.push(sheetContext)` on that same outgoing sheet context.
> [CP87 R5 `cc0f30b`](https://github.com/anzilr/SubtitleStudio/commit/cc0f30b83fb07087e598ab55368a68d71ebb5d7e)
> now awaits a typed MSone choice result, then pushes from the mounted editor
> context. It adds back/reentry widget tests for both submission modes and
> picker cancellation. The same log showed eight repeated Flutter
> `ListTile background color or ink splashes may be invisible` assertions.
> The two decorated `CheckboxListTile` processing options in the subtitle
> extraction sheet now have actual `Material` backgrounds and ink surfaces,
> with regression coverage.
> The user-confirmed recovered session also successfully initialized with
> **895 subtitle lines**, despite a missing old optional secondary track.
> Do not use **hot restart (`R`)** as a test of MSone Back until the
> native plugin hot-restart failure is resolved; use a fresh app process for
> baseline tests. The earlier libmpv hot-restart incident remains an
> **open native blocker**, not an asserted resolution.
> [CP87 R5 detailed report](CHECKPOINT87_R5_MSOne_NAVIGATION_AND_NATIVE_CRASH_2026-10-17.md).
>
> **CP87 R2–R4 ANDROID SESSION RECOVERY & CONTRAST AUDIT — October 16, 2026:**
> **Flutter CI passed:** [38965180956](https://github.com/anzilr/SubtitleStudio/actions/runs/38965180956) — **527 tests passed, 0 analyzer issues**, verified at code `7ed20ab`. The latest fix ensures all secondary-selection flows commit the new reference before deleting the previous app-owned file.
> A real CPH2381 relaunch log proved the original subtitle collection still
> held **895 lines**, but an optional embedded secondary track pointed to a
> missing Android `code_cache/extracted_subtitle_*.srt` file. `EditController`
> treated this missing secondary file as fatal, showing an empty EditScreen.
> This is a **loader failure, not evidence of deleted primary edits**.
> [Recovery code `6f0bbdc`](https://github.com/anzilr/SubtitleStudio/commit/6f0bbdcd9b01291eebf95e0fd507265e4681b239)
> now ignores unavailable optional secondary tracks and, for missing legacy
> cache-owned extracts, clears the stale auxiliary preference. New extracts
> are atomically written in durable app support storage; deletion is confined
> to app-owned paths. [Isar integration coverage and scoped cleanup](https://github.com/anzilr/SubtitleStudio/commit/7c42f66a4d0ea0307ea0bacd5f470d665b4cdce8)
> verify recovery without deleting user-picked files.
> [Targeted modal contrast fixes](https://github.com/anzilr/SubtitleStudio/commit/912f7892c90d12616b6a804918d10d21a29e4f25)
> and [wider audit](https://github.com/anzilr/SubtitleStudio/commit/14ab8bd37cdc8137a2be6b014f19cb5470365b4f)
> replace white-on-light-primary icons/labels with paired theme `onPrimary`,
> `onSecondary`, or `onTertiary` colors across Video Settings, Save File As,
> Load Secondary Subtitle, Project Settings, Import, Merge/Split, Locate SRT,
> session picker, banners and other sheets. Intentional media-overlay whites
> remain unchanged. [MSone async/back-navigation safety patch](https://github.com/anzilr/SubtitleStudio/commit/526dcc451dcbfafa88e4398d680bfe03104789b9)
> handles disposed-screen callbacks and adds diagnostic route pop breadcrumbs.
> The **original unlogged MSone freeze has not been root-caused**.
> Flutter verification is code-level only; CPH2381 and Windows native
> acceptance, including prior `libmpv.so` restart crash, remain pending.
> [Detailed R2–R4 report](CHECKPOINT87_R2R4_ANDROID_RECOVERY_AND_ICON_AUDIT_2026-10-16.md).
>
> **CP87 R1 FILE-ACCESS IDENTITY FOUNDATION — October 16, 2026:**
> Technical Checkpoint 87 has begun *without declaring CP86 native acceptance*.
> [Code `50bd1c0`](https://github.com/anzilr/SubtitleStudio/commit/50bd1c041ef0ada113937826d9975073cddc7020)
> introduces `StudioFileIdentity` with native-path, Android SAF document,
> file-URI, network and opaque-URI classifications. Waveform cache/stat logic,
> SAF revision resolution, secondary subtitle read dispatch, and a new typed
> saved-video repository accessor use that identity. Original persisted
> locations and waveform cache hashing remain unchanged. No Isar migration,
> grant escalation, or platform bookmark replacement is attempted.
> An Olam selected-language-tab fix
> [`999f4a1`](https://github.com/anzilr/SubtitleStudio/commit/999f4a167903a008db1a5aa427b05cb768e1b702)
> corrects white-on-white `EN-ML` / `ML-EN` / `ML-ML` selection by using
> dark neutral selected surfaces in achromatic dark/Classic palettes,
> retaining accent-colored tabs elsewhere.
> [CP87 full CI](https://github.com/anzilr/SubtitleStudio/actions/runs/38961927133)
> **passed with 508 Flutter tests and 0 analyzer issues** (code `50bd1c0`),
> covering the dictionary contrast fix and CP87 identity changes together.
> The older [dictionary-only gate](https://github.com/anzilr/SubtitleStudio/actions/runs/38961699279)
> was cancelled after the superseding CI run started. Native Android/Windows QA and the prior
> media-kit/libmpv hot-restart crash remain open. See
> [CP87 R1 report](CHECKPOINT87_FILE_IDENTITY_AND_DICTIONARY_CONTRAST_2026-10-16.md).
> **Appearance development remains frozen** beyond this reproduced tab issue.

> **CP86 R4 USER-REPORTED SUBTITLE CONTROL COLLISION — October 16, 2026:**
> In waveform view the existing subtitle overlays, selected edit region and
> adjustment handles were all blue like audio. Targeted fix
> [3f0346f](https://github.com/anzilr/SubtitleStudio/commit/3f0346f83cf7dcdd5839bdf022de820bfa775744)
> restores **orange** for existing subtitle overlays/edit handles, preserves
> blue for audio, uses **teal** for new-line selection/handles and keeps the
> red playhead. Both overlay and combined painter passes now invalidate on
> color changes; appearance factory and skins remain frozen.
> [Flutter CI](https://github.com/anzilr/SubtitleStudio/actions/runs/38954079893)
> **passed: 492 Flutter tests, 0 analyzer issues** at code `3f0346f`;
> covers color-role and layered repaint regressions.
>
> **NEW ANDROID NATIVE QUALIFICATION EVIDENCE:** CPH2381 Android 14 debug
> release from `703529b` measured cold load **145,942 ms** and warm
> `.pk1` cache loads **1,879 / 1,865 / 1,845 ms**. This is verified cache
> reuse, not an equivalent improvement in cold decode. The same run recorded
> **SIGSEGV (signal 11) in libmpv.so** in Thread-14 immediately following
> Flutter hot restart/native Media Kit reference disposal at 22:13:26 +03:00.
> Native acceptance is **BLOCKED** pending reproduction/callstack diagnosis.
> This is a true Android native crash, not an inferred out-of-memory error
> or the old ListTile Flutter assertion. See the updated CP86 report.
>
> **CP86 R2/R3 ANDROID FEEDBACK — October 16, 2026:**
> Physical CPH2381 debug log exposed **183,327 ms waveform load** for a
> long Android SAF MKV: source acquisition **183,294 ms**, zoom metadata only
> **31 ms**, with 20,637,381 reduced samples. The old compact pipeline
> still wrote 44.1-kHz PCM (roughly 660 MB raw on this file) and unversioned
> SAF inputs were redecoded on each load. R2 switched new compact FFmpeg
> extraction to 2,756-Hz mono and checksummed V2 mean-only peaks (2 bytes per
> sample; legacy V1 cache remains readable), while Android DocumentsProvider
> size+last-modified revision support permits cache reuse when both are valid.
> Source without trustworthy revision metadata stays non-persistent.
> [R2 Flutter gate 38944366683](https://github.com/anzilr/SubtitleStudio/actions/runs/38944366683):
> **478 tests passed, analyzer 0**. This is *not* yet a native performance
> measurement of the new algorithm; first-time extraction still decodes audio.
> Specific reproduced UI bugs override the theme freeze: original role-coded
> waveform action colors (zoom orange, magnet red, confirm green, add teal,
> scroll blue) restored; Olam/Urban dictionary search no longer forces white
> text/icons on Carbon Zero white-primary buttons; Dictionary CheckboxListTiles
> use a Material header instead of a colored DecoratedBox; Import Subtitle
> button icon uses `onPrimary`. R3/R4 UI CI gate:
> [38945025518](https://github.com/anzilr/SubtitleStudio/actions/runs/38945025518):
> **491 Flutter tests passed, 0 analyzer issues** at code `061bae99`.
> [Targeted regression and Android retest report](CHECKPOINT86_R2R3_WAVEFORM_PERFORMANCE_AND_CONTRAST_2026-10-16.md).
> **Appearance remains otherwise paused.** Android/Windows native cache
> freshness, waveform fidelity/PTS, performance, Dictionary exception removal
> and physical theme contrast remain pending device acceptance.

> **CP86 R1 NATIVE WAVEFORM QUALIFICATION IN PROGRESS — October 16, 2026:**
> Code [18ea029](https://github.com/anzilr/SubtitleStudio/commit/18ea02927ed792df3150e4415a8fc34cc64044e6) adds Windows/Linux global FFmpeg stream-map-safe diagnostics,
> fail-closed Android SAF document read-handle resolution, skips potentially
> stale legacy PCM cache reuse for `content://` inputs, and removes transient
> SAF peak caches even after cancellation/failure. Targeted regression tests
> cover revoked/missing SAF grants, Auto/explicit global stream selection,
> and interrupted peak-cache writes. [Full Flutter CI gate](https://github.com/anzilr/SubtitleStudio/actions/runs/38937320025)
> **passed: 474 Flutter tests, 0 analyzer issues** at code `18ea029`; do not
> treat CI as Android/Windows native acceptance.
> [CP86 qualification matrix and commands](CHECKPOINT86_NATIVE_WAVEFORM_QUALIFICATION_2026-10-16.md).
> **APPEARANCE REMAINS FROZEN**; upcoming CP86 device checks are CPH2381
> Android 14 and Windows, followed by typed file/SAF identity and persistence
> ownership only after waveform native behavior is qualified.

> **SKIN-5 FINAL UI COLOR AUDIT / APPEARANCE FREEZE — October 16, 2026:**
> Reviewed ~203 UI-facing Dart files; migrated fixed decorative, primary,
> success, caution and error colors in more than 50 UI source files to the
> selected skin's semantic color roles. Includes Editor/Home, dictionary,
> history, comments, feedback, logging, import/export, dialogs, waveform,
> video controls, utility/settings sheets and progress states. Deliberately
> retained user-authored subtitle colors, video-composited black/white
> contrasts, media artwork, shadows, skin palette definitions and fallback
> paints for context-free waveform test callers. Added a 31-surface static
> regression test preventing fixed branded accents from returning.
> [GitHub Actions 38933989670](https://github.com/anzilr/SubtitleStudio/actions/runs/38933989670):
> **470 Flutter tests passed, 0 analyzer issues** at code `5068731f`.
> [Complete color audit, exceptions and freeze policy](STUDIO_SKIN5_FINAL_UI_COLOR_AUDIT_AND_FREEZE_2026-10-16.md).
> **APPEARANCE WORK PAUSED:** No new skin or broad UI migration work during
> technical refactoring. Fix only reproduced contrast/accessibility/UI
> regressions; real-device 360dp Android, Windows and all 12 skin/mode visual
> acceptance are still separate. No upstream merge or release sign-off.
> **NEXT TECHNICAL CHECKPOINT: CP86** native waveform qualification on Android
> and Windows (large-file compact/tiled peaks, SAF content URI vs path,
> track switching, cancellation/disposal, playback sync and cache integrity),
> followed by typed file identity/persistence, Editor ownership, logging and
> isolated platform toolchain updates. UX history map, compact Edit Line,
> community skin creator and desktop workspace remain deferred.

> **R8 MARKED-LINES + EDITOR FLOATING CONTROL + WAVEFORM TOOLBAR VERIFIED — October 16, 2026:**
> User confirmed the R7 Riverpod build-phase waveform exception is resolved
> on Android. The next 360dp device log showed successful compact waveform
> loading/playback but a separate 23px toolbar overflow. The toolbar's action
> group is now horizontally scrollable and uses skin colors. Marked Lines'
> Show All Comments checkbox now strictly distinguishes marked cues from
> unmarked commented cues, composes with resolved-state filters and survives
> an async preference-load race. Redundant Show label/filter icon removed.
> Marked Lines summary and timestamp headers were made responsive after the
> real 360dp widget test exposed two additional overflows. The Editor floating
> play/pause uses primary/onPrimary in all twelve skin/mode variants, retaining
> the original player callback. [Successful CI 38926044286](https://github.com/anzilr/SubtitleStudio/actions/runs/38926044286):
> **469 Flutter tests passed, zero analyzer issues** at code `b25faf4`.
> [R8 report and current prioritized roadmap](STUDIO_R8_MARKED_LINES_FAB_WAVEFORM_UI_2026-10-16.md).
> **NEXT:** real Android R8 checkbox/theme/toolbar smoke verification, native
> CP86 waveform track/SAF/cancellation/performance qualification, Windows and
> historical Isar migration QA. Then finish SKIN-5/DESIGN-2 screen audits,
> UX history language/version map and compact Edit Line; SKIN-6/DESIGN-3
> accessibility, community imports/creator and later desktop workspace remain.
> Legacy numbered phases and older three-skin or CP85 notes below are retained
> as historical plans; current built-in catalogue is **four skins × three
> modes**, and R7's specific Android crash is user-confirmed resolved.

> **WAVEFORM R7 RIVERPOD LIFECYCLE VERIFIED — October 16, 2026:**
> Android reported `Tried to modify a provider while the widget tree was
> building` at `WaveformController._setState`, after R6 compact waveform
> processing succeeded. Fixed the direct `didUpdateWidget` playback and
> subtitle repaint provider mutations, coalesced playback sync after frame,
> and introduced a guarded deferred state write for unexpected build-phase
> audio callbacks. Playback time and auto-scroll now update atomically;
> a single zoom-level waveform no longer divides by zero. Both added widget
> lifecycle tests and existing load/cancellation tests are green.
> [GitHub CI 38921649751](https://github.com/anzilr/SubtitleStudio/actions/runs/38921649751):
> **452 tests passed, zero analyzer issues** at code `b10b06f`.
> [R7 incident analysis and Android retest checklist](STUDIO_WAVEFORM_R7_RIVERPOD_LIFECYCLE_2026-10-16.md).
> **NEXT:** real CPH2381 Android debug test for waveform open, live
> playback sync, editing, re-render, split resize and multiple skin modes;
> capture full exception stack if it recurs. No Android native acceptance
> or release sign-off yet.

> **WAVEFORM R6 ANDROID CRASH CONTAINMENT — October 16, 2026:**
> The Android 14/360dp device log exposed a definite 3.8dp vertical overflow
> caused by fixed 180dp waveform content in a 177.2dp split pane; the video
> collapsed to zero height. The same run read 330,198,104 samples (~660MB)
> from a legacy PCM cache before disconnecting, but the exact native cause
> of connection loss was not captured. The Editor now reserves sufficient
> leading pane height while waveform is shown and uses a bounded adaptive
> video/waveform composition; tiny viewports never overflow.
> Android now defaults to compact/tiled waveform processing, and matching
> existing PCM caches can be streamed into the peak-cache format without
> a full PCM allocation or another FFmpeg decode. Other platforms retain
> their prior default. [CI 38918789679](https://github.com/anzilr/SubtitleStudio/actions/runs/38918789679):
> **450 Flutter tests passed, zero analyzer issues** at code `72261563`.
> [R6 diagnostic report and Android retest instructions](STUDIO_WAVEFORM_R6_ANDROID_CRASH_CONTAINMENT_2026-10-16.md).
> **NEXT:** real-device Android verification of waveform on the existing
> large-media session, split dragging, show/hide, zoom and cache lifecycle;
> inspect crash/ANR logcat if the device connection still drops. The code
> is CI-verified, not native accepted; no release sign-off.

> **SKIN-4 R5 CARBON ZERO VISUAL CONSISTENCY VERIFIED — October 16, 2026:**
> Editor appbar waveform icon and all five Home FAB action icons/labels now
> follow live on-appbar/on-primary contrast, including Carbon Zero Light,
> Dark and Classic. Marked Lines replaces hard-coded blue/green/red decoration
> with semantic roles, and its Project Settings entry opens at full modal
> height. Go To Line no longer forces a blue slider, no longer waits for
> diagnostic logging to open, and fits a 360dp portrait viewport. Common
> red danger and amber warning color roles apply to every built-in skin and
> deletion/reset/clear operations, while Carbon Zero's ordinary decoration
> stays achromatic. [Successful CI 38915923306](https://github.com/anzilr/SubtitleStudio/actions/runs/38915923306):
> **448 Flutter tests passed, 0 analyzer issues** at code `5e0c155`.
> [R5 report and device checklist](STUDIO_SKIN4_R5_ANDROID_CONTRAST_2026-10-16.md).
> **NEXT:** repeat real Android visuals and workflow on CPH2381 (360dp),
> check marked-lines nested modal dismissal, destructive confirmations, and
> waveform/FAB controls. Flutter CI is not native-device acceptance; Windows
> and historical Isar acceptance remain separate. No upstream or release
> branch modified.

> **SKIN-4 R4 CARBON ZERO + RAW SOURCE VERIFIED — October 16, 2026:**
> Replaced embedded and standalone Source View's per-cue GUI fields with a
> single raw SRT text editor (colors only; editing/save reconciliation remains
> validated). Four built-in skins now include the signature grayscale-only
> **Carbon Zero** (Light/Dark/Classic) as the default for unset preferences;
> all explicitly saved skins remain respected. Home/Editor/Edit Line Settings
> opens fullscreen and its Appearance section starts collapsed. Narrow
> positioning-sheet overflows reported on Android have been addressed with a
> scrollable content surface and viewport spacing. [GitHub CI 38910767459](https://github.com/anzilr/SubtitleStudio/actions/runs/38910767459)
> verified **444 Flutter tests passed, 0 analyzer issues**, code checkpoint
> `dd4d53aa`. [R4 report](STUDIO_SKIN4_R4_CARBON_ZERO_RAW_SOURCE_2026-10-16.md).
> **NEXT:** debug/profile Android native acceptance of Source View,
> Settings, all 12 appearance combinations, keyboard-constrained positioning,
> and the still-unlocated ListTile ink assertion in user logs. Windows and
> historical Isar upgrade acceptance remain separate; no release sign-off yet.

> **SKIN-4 R3-B LIVE ACTIVATION VERIFIED — October 16, 2026:** Saved
> skin ID and Light/Dark/Classic now drive the live MaterialApp through the
> injectable skin catalog and the same StudioThemeFactory used by previews
> and future community definitions. Source View (embedded and standalone),
> MSone Submission, Screen Help, Edit Line confirmation sheets and waveform
> toolbar received semantic component cleanup. Standalone Source View gained
> stable route-owned Riverpod overrides to prevent reinitialization when the
> appearance changes. [Final CI 38903429526](https://github.com/anzilr/SubtitleStudio/actions/runs/38903429526)
> verified **440 Flutter tests passed, 0 analyzer issues** at code
> `ff2b2f1`. [R3-B report](STUDIO_SKIN4_R3B_LIVE_ACTIVATION_2026-10-16.md).
> **Next: Android/Windows native appearance acceptance** with the
> [nine-mode testing checklist](STUDIO_SKIN4_R3B_NATIVE_ACCEPTANCE_2026-10-16.md).
> This code gate is **not** real-device verification. Remaining SKIN-5
> screenwide component clean-up, SKIN-6 accessibility, community importer/
> website and independent CP86 waveform qualification remain open.

> **SKIN-4 R3-B PART 1 VERIFIED — October 16, 2026:** Confirmation,
> index-selection and selected-time shift sheets now use the unified
> semantic component contract. Batch delete Enter handling is guarded;
> single-delete content scrolls in constrained sheet height. The Project
> Settings root surface/header uses design tokens. [Successful CI
> 38900494194](https://github.com/anzilr/SubtitleStudio/actions/runs/38900494194)
> verified **434 Flutter tests passed, 0 analyzer issues** against
> `7fa7f002`. [P1 report](STUDIO_SKIN4_R3B_P1_SELECTION_SHEETS_2026-10-16.md).
> **R3-B still open:** remaining Editor/Edit Line toolbar, selection and
> playback-overlay contrasts; full edit-state regressions; safe global
> theme factory activation. Android/Windows native acceptance and CP86
> waveform qualification remain separate.

> **SKIN-4 R3-A COMPLETE — October 16, 2026:** Editor/Editing popup menus
> use one semantic `StudioMenuItemContent` (preserving original action
> values); subtitle cards now inherit readable semantic text, selection and
> highlight colors. Formatting popup/confirmation, unsaved changes sheet and
> Edit Line app bar/dictionary foregrounds have migrated to shared appearance
> roles. [Successful CI run 38894453717](https://github.com/anzilr/SubtitleStudio/actions/runs/38894453717):
> **429 tests passed, 0 analyzer issues** against code `a4ab417`.
> [R3-A report](STUDIO_SKIN4_R3A_EDITOR_CONTRAST_2026-10-16.md).
> **Still gated:** app-wide `StudioThemeFactory` activation requires
> remaining confirmation sheet/toolbar/control contrast audits and Editor
> lifetime tests (R3-B). Live skin selection still previews/saves only; native
> Android/Windows acceptance and CP86 waveform work remain separate.

> **DESIGN-1 R4 VERIFIED — October 16, 2026:** Uniform theme defaults
> for modal sheets, dialogs, popup/context menus, dropdown menus, sliders,
> segmented buttons and filled/elevated/outlined/text/icon buttons now share
> one `StudioComponentThemes` implementation in both legacy `AppThemes` and
> all nine skin combinations. Initial subtitle action bottom-sheet pilot uses
> semantic colors. [GitHub Actions 38892274970](https://github.com/anzilr/SubtitleStudio/actions/runs/38892274970):
> **424 tests passed; zero analyzer issues** (verified code `1b850a6`).
> [Canonical component specification](STUDIO_COMPONENT_SYSTEM_2026-10-16.md).
> **Not yet migrated:** numerous feature-local sheet/dialog/popup overrides.
> DESIGN-2 screen migration and DESIGN-3 real-device visual/a11y review must
> precede a claim of app-wide consistency; contrast-critical controls gate
> SKIN-4 R3 palette activation. CP86 waveform work is unchanged.

> **Unified component design requirement — October 16, 2026:** All
> modal bottom sheets, dialogs, dropdowns, popup/context menus, sliders,
> primary/secondary/destructive buttons and selection controls must follow
> a **single reusable design system** across Carbon & Jade, Copper Cinema,
> Aster Violet (each Light/Dark/Classic) and future community skins.
> [Component contract and source audit](STUDIO_COMPONENT_SYSTEM_2026-10-16.md).
> DESIGN-0 inventory → DESIGN-1 shared component themes → DESIGN-2 migrate
> one-off callers → DESIGN-3 visual/accessibility acceptance. Shared
> `StudioComponentThemes.apply` now centralizes Material default styles for
> both existing `AppThemes` and `StudioThemeFactory`, with a subtitle-action
> sheet pilot. Legacy overrides still exist and **full rollout is NOT complete**.
> Treat contrast-critical DESIGN-2 as a **SKIN-4 R3 prerequisite** before
> enabling new skins throughout live Editor; complete app-wide consistency and
> Android/Windows validation through SKIN-5/6. Preserve open-source skin file
> constraint: skin authors change palette data, **not** widget geometry/code.

> **SKIN-4 R2 PILOT COMPLETE — October 16, 2026:** Semantic, focus-aware
> neutral cue fields now replace previously saturated primary-colored
> Original/Edited boxes, with contrasting subtitle text, metadata and action
> icons. The shared time input uses field/error/focus tokens and preserves
> existing text/time controllers, undo and callbacks. A reusable historical
> `OptimizedTextField` uses the same tokens. [Successful SKIN-4 R2 CI
> 38889494374](https://github.com/anzilr/SubtitleStudio/actions/runs/38889494374)
> verified **422 tests passed and zero analyzer issues** against code
> `535eb07`. [Implementation/audit report](STUDIO_SKIN4_CUE_FIELD_PILOT_2026-10-16.md).
> **R3 not done:** live MaterialApp still deliberately uses legacy
> `AppThemes` while other Editor/menu/waveform toolbar colors are audited.
> Next: migrate remaining contrast-sensitive controls and safely install the
> skin factory, then Android/Windows real-device acceptance. The original
> CP86 waveform native qualification track remains independent.

> **SKIN-3 R1 COMPLETE — October 16, 2026:** An Appearance section
> in Settings now offers independent saved skin and Light/Dark/Classic choices,
> previews all three built-in skins (nine swatches), and supports injectable
> community definitions in **My skins**. A scoped Edit Line preview shows
> the selected combination without touching the parent Editor's route/theme.
> Toolbar theme cycling uses typed appearances with a clear tooltip.
> [Verified CI 38872349945](https://github.com/anzilr/SubtitleStudio/actions/runs/38872349945):
> **418 tests passed; Flutter analyze succeeded**; tested code `06eb584`.
> [SKIN-3 report](STUDIO_SKIN3_APPEARANCE_SETTINGS_2026-10-16.md).
> Live Editor palettes are intentionally **still legacy**; saving a skin
> currently changes its Settings preview only. SKIN-4 must migrate the
> Original/Edited/Time fields to neutral, readable semantic components **before**
> enabling the new palette factory globally, with Android/Windows acceptance.
> Native old-database migration acceptance and CP86 waveform testing remain
> independent release work.

> **SKIN-2 R2 COMPLETE — October 16, 2026:** Separately persisted
> namespaced `Preferences.skinId` and existing `themeMode` are now backed by
> the pinned, regenerated Isar model and an injectable Riverpod theme controller.
> Independent choices survive changes to custom app fonts and late startup
> hydration. Rapid mode/skin writes are serialized; legacy saved
> `light/dark/classic` records remain compatible. [GitHub quality gate
> 38870812828](https://github.com/anzilr/SubtitleStudio/actions/runs/38870812828):
> **411 tests passing; zero analyzer issues**, code `86a4166`.
> [SKIN-2 report](STUDIO_SKIN2_PERSISTENCE_2026-10-16.md).
> **Important:** `ThemeState.themeData` deliberately still renders old
> AppThemes for now; selected new palettes are **not yet activated** in Editor
> until SKIN-4 repairs white-on-primary Edit Line fields. SKIN-3 adds Appearance
> Settings and independent controls. Physical testing of upgraded legacy
> on-disk Isar files and actual Android/Windows editing remains pending.
> CP86 waveform qualification remains a separate original technical milestone.

> **SKIN-EXT-1 COMPLETE — October 16, 2026:** The open-source community
> skin foundation is implemented and verified: namespaced skin IDs, a registry
> for built-in and user-defined palettes, a shared `ThemeData` factory,
> portable colors-only JSON v1 codec, contrast checks and public JSON Schema.
> [Successful Actions run 38868963345](https://github.com/anzilr/SubtitleStudio/actions/runs/38868963345):
> **400 tests passed, 0 analyzer issues** against code commit `26a2ece`.
> [Community skin format/roadmap](COMMUNITY_SKIN_FORMAT_V1.md).
> **Future only:** native installation/export UI (SKIN-EXT-2) and the open-source
> client-side Skin Creator website (SKIN-EXT-3). No app setting was switched,
> no imported files are installed and no project/media/Isar schema changed.
> SKIN-2 should persist the namespaced string ID and current appearance mode
> separately; CP86 waveform stays the original next technical checkpoint.

> **Open-source community skin architecture — October 16, 2026:**
> User-created skins are a required future feature, including a web-based Skin
> Creator and importable `.sskin.json` files. The theme factory must remain
> **data-driven**, not permanently tied to the three built-in enum values.
> SKIN-EXT-1 introduces namespaced `StudioSkinId`, an immutable catalog of
> `StudioSkinDefinition` data, generic palette rendering, strict colors-only
> v1 JSON serialization/validation and a public [JSON Schema](../../schemas/subtitlestudio-skin-v1.schema.json).
> [Format and future milestones](COMMUNITY_SKIN_FORMAT_V1.md):
> **SKIN-EXT-2** native import/export/install; **SKIN-EXT-3** open-source,
> client-side web creator; optional advanced customization later.
> Neither the website nor app installer is currently implemented. Keep
> SKIN-2's persisted skin preference a **namespaced string ID**, not an enum.
> Preserve built-in color modes, editor lifecycle, local data and CP86 waveform
> plans. Community skin files must not contain executable code, CSS, assets or
> external network references.

> **SKIN-1 R2 COMPLETE — October 16, 2026:** The approved nine-appearance
> design system is implemented behind an **opt-in theme factory**: 3 skin
> palettes × Light / Dark / Classic, semantic editing/input contrast tokens,
> and a reusable read-only 9-preview gallery. [Successful CI run
> 38867646977](https://github.com/anzilr/SubtitleStudio/actions/runs/38867646977)
> verified **392 passing tests and zero analyzer issues** against code
> `fa6aa09`. See the [SKIN-1 report](STUDIO_SKIN1_THEME_FOUNDATION_2026-10-16.md).
> **Not activated in MainApp**; old saved modes, controller lifecycle,
> Editor/Edit Line input fields, Isar schema, player and waveform are unchanged.
> Next SKIN checkpoint: SKIN-2 isolated appearance preference persistence and
> controller migration, with generated-Isar compatibility testing and custom
> font/legacy preference retention. The original technical CP86 waveform
> qualification remains independent.

> **Approved — SubtitleStudio three-skin appearance system (October 16, 2026):**
> **Carbon & Jade**, **Copper Cinema**, and **Aster Violet**, with independent
> **Light / Dark / Classic** modes in every skin (**nine appearances**).
> Persist the skin and appearance mode **separately**; changing either must
> preserve the other and preserve the user's custom font and unsaved edits.
> First visual preview: **Carbon & Jade / Dark**. Proposed new-install default:
> Carbon & Jade / Dark; keep existing users' explicitly saved mode untouched.
> Classic is a genuinely separate near-black appearance, **not**
> `ThemeMode.system` masquerading as Classic.
> See the [approved implementation plan](STUDIO_SKINS_IMPLEMENTATION_PLAN_2026-10-16.md)
> and [9-palette reference](STUDIO_PALETTE_DECISION_2026-10-16.md).
> Execution sequence SKIN-0 (documented) → SKIN-1 tokens/resolver → SKIN-2
> independently persisted preferences/migration → SKIN-3 Appearance Settings →
> SKIN-4 Edit Line high-contrast text fields → SKIN-5 UI rollout → SKIN-6 QA.
> **Production UI, Isar model and theme controller remain unchanged** until
> implementation work. Do not repurpose **Checkpoint 86**, which remains the
> original waveform/native qualification milestone. User confirmed **CP85 R6
> Android stability gate completed**; last separate CI evidence is CP85 R5.

> **October 16, 2026 — CP85 R5 Android theme regressions addressed in code:**
> [CI run 38861456875](https://github.com/anzilr/SubtitleStudio/actions/runs/38861456875):
> **386 tests passing; no analyzer issues.** Stable Editor/Edit Line
> Riverpod scopes and guarded route arguments address the `Loading...`
> reset and deactivated-ref crashes. Light surfaces are now white, with
> neutral Studio palette and unified Project Settings accents.
> **Real-device confirmation still required.** Other screens' hard-coded
> rainbow accents remain a planned per-screen UX cleanup, not yet complete.
> See [CP85 R5 Android theme-switch report](CP85_R5_THEME_SWITCH_AND_PALETTE_2026-10-16.md).

> **UX-1 foundation verified — October 16, 2026:** Studio semantic
> light/dark/Classic tokens, shared Material components and the first
> Project Settings encoding-selector visual pilot are committed.
> [GitHub quality gate 38809722745](https://github.com/anzilr/SubtitleStudio/actions/runs/38809722745)
> passed Flutter analysis and all committed tests. **Real Android/Windows
> visual review is still pending.** See
> [UX-1 implementation report](STUDIO_DESIGN_FOUNDATION_2026-10-16.md).
> The next scheduled UX work is user-friendly history terminology, followed
> by the graphical version map; keep native waveform qualification separate.

> **UX additions — October 16, 2026:** Four requested design workstreams have been added to the active roadmap:
> **visual checkpoint history**, **plain-language history terminology**,
> **a unified SubtitleStudio-specific color/design system**, and
> **a compact, productive mobile Edit Line layout**.
> See the dedicated implementation specification:
> [SubtitleStudio UX roadmap (October 16, 2026)](SUBTITLESTUDIO_UX_ROADMAP_2026-10-16.md).
> These are **planned features, not yet implemented**. Keep Checkpoint 85
> Android verification and native waveform qualification ahead of risky UI
> rewrites. Older sections below document earlier audit snapshots; their
> Checkpoint 43/45 statuses are historical, not the current branch baseline.

> **October 15, 2026 — Checkpoint 84 R1 verified.**
> [Verified code commit](https://github.com/anzilr/SubtitleStudio/commit/135caea87db1b64eebdca1bb798461701b0f265b)
> · [Successful GitHub Actions](https://github.com/anzilr/SubtitleStudio/actions/runs/38760499546):
> **369 passing tests, zero Flutter analyzer issues** (+9 tests).
>
> The experimental MS_ONE_WAVEFORM_TRACK_SYNC=true path connects
> Media Kit audio-track changes to the Checkpoint 83 libmpv ff-index
> resolver and verified ffmpeg:stream:N loading. It clears the previous
> waveform before metadata resolution, cancels stale requests, handles
> explicit Auto mode rather than reusing saved track preferences, and
> shows a visible error if the selected stream cannot be resolved.
> The editor's responsive layouts, waveform toggle, regeneration,
> media replacement, hiding and disposal all participate in
> cancellation/invalidation. Effective audioTrackId is retained on
> WaveformReady through copyWith.
>
> See [Checkpoint 84 report](CHECKPOINT84_EXPERIMENTAL_TRACK_AWARE_WAVEFORM.md).
> The default eager waveform and prior player behavior are unchanged.
> **Still required:** Android/Windows media-track tests, FFmpegKit
> cancellation and SAF tests, high-DPI layered/tiled rendering profiling,
> and player-specific mpv property verification. Do not promote this
> experimental flag to default or modify upstream/main/release tags.
> Isar schema and the deferred desktop workspace are unchanged.
>
> **Additional waveform reference, October 14, 2026: Subtitle Edit source audit.**
> Alongside KDE Subtitle Composer, use the current Subtitle Edit Avalonia/C#
> waveform implementation and its regression/benchmark tests. See
> [Subtitle Edit waveform source study](SUBTITLEEDIT_WAVEFORM_SOURCE_AUDIT_2026-10-14.md).
> Key priorities: compact peak caches with atomic promotion and bounded header
> validation; timestamp-gap-preserving audio extraction; static/dynamic render
> layer separation and per-device-pixel extrema; shot/frame snapping with
> screen-pixel tolerances; and regression/benchmarks for cache corruption,
> long audio, high-DPI scrolling and stale source switching.
> Prefer implementing **Checkpoint 79 experimental metadata-only zoom levels**
> before changing user-facing waveform appearance. Checkpoint 80 can replace
> raw full-track PCM buffering with streaming peak reduction/caching. Real
> Android/Windows profiling remains required. Preserve signed extrema and
> the current mobile workflow; keep desktop layout deferred.
>
> **New roadmap requirement — Expanded SRT text encodings (requested 2026-10-12):**
> Reference implementation research: [KDE Subtitle Composer and Subtitle Edit
> study](SRT_ENCODING_REFERENCE_RESEARCH_2026-10-12.md). The study links exact
> detection, source-encoding preservation, manually selected encoding/preview,
> BOM and regression-test implementations. Use their proven UX/behavior patterns
> to guide an independently implemented shared Flutter encoding service.
> **Source references:** https://invent.kde.org/multimedia/subtitlecomposer.git
> and https://github.com/SubtitleEdit/subtitleedit.git.
> Add reliable encoding selection/detection for **both reading/parsing and
> writing/compiling SRT**. Initial candidate coverage: UTF-8 (with/without
> BOM), UTF-16 LE/BE (with/without BOM where safely identifiable), ASCII,
> ISO-8859-1, Windows-1252, and regional legacy encodings such as
> Windows-1256 (Arabic), Windows-1251 (Cyrillic), Shift_JIS, GB18030,
> Big5, and EUC-KR where supported by the platform codec. Validate actual
> requirements and codec availability before committing the final list.
> Encoding support must be **symmetric on import/export**; never silently
> relabel or export as UTF-8 when the user selected another charset. Preserve
> original encoding where possible, expose an explicit override/preview for
> ambiguous bytes (Latin-1 can decode arbitrary bytes), detect BOM correctly,
> handle unrepresentable characters explicitly (warn, refuse, or offer UTF-8),
> cover Android/iOS/Windows/macOS/Linux and SAF paths, and test multilingual
> parse→compile→parse round trips. Avoid breaking existing .msone metadata or
> on-disk projects. This is a **future implementation milestone**, not part of
> Checkpoint 65's persistence changes. Current limitations: the decoder tries
> Latin-1 before Windows-1252, and the SRT compiler only maps UTF-8,
> ISO-8859-1 and ASCII explicitly (otherwise falls back to UTF-8).
> on `refactor/riverpod-architecture`. See
> [Checkpoint 59 history integrity](CHECKPOINT59_HISTORY_SAFETY.md),
> [Checkpoint 60 mutation migration](CHECKPOINT60_LIVE_MUTATION_MIGRATION.md),
> [Checkpoint 61 import/metadata safety](CHECKPOINT61_COMMENT_IMPORT_AND_METADATA_SAFETY.md),
> [Checkpoint 62 batch edit migration](CHECKPOINT62_BATCH_MUTATION_AND_DESKTOP_REUSE.md),
> [Checkpoint 63 Save As/waveform safety](CHECKPOINT63_SAVE_LOCATION_AND_WAVEFORM_SAFETY.md),
> [Checkpoint 64 legacy writer audit](CHECKPOINT64_LEGACY_WRITE_AUDIT.md),
> [Checkpoint 65 mutation boundaries](CHECKPOINT65_LEGACY_MUTATION_BOUNDARIES.md),
> [Checkpoint 66 reference foundation](CHECKPOINT66_REFERENCE_FOUNDATION.md),
> [Checkpoint 67 ref migration plan](CHECKPOINT67_REFERENCE_MIGRATION_AND_SUBTITLECOMPOSER.md),
> [Checkpoint 68 portable .msone references](CHECKPOINT68_PORTABLE_HISTORY_REFERENCES.md),
> [Checkpoint 69 persisted Isar references](CHECKPOINT69_PERSISTENT_HISTORY_REFS.md),
> [Checkpoint 70 named refs and branch switching](CHECKPOINT70_NAMED_BRANCHES_AND_BOOKMARKS.md),
> [attached KDE waveform and encoding study](SUBTITLECOMPOSER_WAVEFORM_AND_ENCODING_SOURCE_AUDIT.md), and
> [desktop reuse audit](DESKTOP_WORKSPACE_REUSE_AUDIT_2026-10-12.md).
> Next phases: finish raw/sessionless persistence migration, then persisted
> HEAD/branch/bookmark references, history graph UI and archived-format fixtures.
> Desktop UI redesign must be isolated from the existing mobile widget layout.


Date: 2026-10-03
Branch: `refactor/riverpod-architecture`
Original audit head: `cff387f69257e37bb3b6ef26111b2683a57bf510`
Current verified checkpoint: `c0c95ead5f513cbb47f0f625f441110b5cd95304` (checkpoint 45)
Current verification: `flutter analyze` = 0 issues; `flutter test -j 1` = 138 passed
Five-platform build gate: `53422ce` (Android, Windows, Linux, macOS, iOS all green)

## 1. Current progress at checkpoint 43

Completed since the original v4 audit:

- Phase 0 verification is complete.
- Phase 1 real-Isar test infrastructure is complete and now covers preferences, video preferences, checkpoints, subtitle repositories, Edit Line persistence, sessions, project metadata, subtitle imports, and project import checkpoint remapping.
- Phase 2 preference-store consolidation is complete. Production singleton Preferences creation/update flows now go through `PreferencesStore`; `PreferencesModel` is removed.
- Phase 3 global database retirement is complete. `DatabaseHelper`, `database_instance.dart`, and `CheckpointRepository.fromGlobal()` are removed.
- Feature-level global Isar usage in subtitle effects and hearing-impaired cleanup is removed.
- Subtitle sync, banners, CRUD, split/merge, import, and last-edited-session persistence are repository-driven.
- Effect checkpoints and Edit/Edit-Line checkpoints now preserve true pre-operation state and have regression coverage.
- Session deletion now cascades checkpoint/video-preference cleanup without deleting unrelated sessions.
- The typed project pipeline is complete from codec/builder through save, preview, session selection, and import persistence.
- `ProjectDocument.toLegacyMap()` is removed; dynamic maps remain only at JSON serialization boundaries or unrelated file-selection metadata.
- `ProjectManager` is removed. Project save construction/persistence now lives in injected `ProjectSaveCoordinator`; presentation interaction lives in `ProjectSaveFlow`/widgets.
- `CheckpointStore` now owns raw checkpoint/collection Isar persistence. `CheckpointManager` contains no direct Isar query/write calls and its obsolete commented legacy methods are removed.
- Exported checkpoint IDs are preserved and remapped to fresh Isar IDs during project import.
- Checkpoint 45 is green with zero analyzer issues and 138 passing tests.

Remaining work is concentrated in Phases 4-12 below. In particular, Phase 4 still needs `ProjectManager` orchestration/UI decomposition even though project data typing is complete.

## 9. Why roadmap v4 replaces v3

Roadmap v3 correctly shifted SubtitleStudio from a file-by-file BLoC replacement toward dependency boundaries. Since then, the codebase has materially changed:

- Riverpod now owns Home, Editor, Edit Line, Source View, and Waveform state.
- route-scoped Riverpod dependencies are explicit and regression-tested.
- the Android startup logger failure is fixed and logging failures are non-fatal.
- project documents have a validated codec and builder.
- subtitle imports have typed results, encoding decoding, and an injected persistence boundary.
- project settings, marked lines, secondary subtitles, AI explanation, and Olam preference calls were moved behind repositories.
- checkpoint reconstruction, policy, and timeline traversal have been extracted into pure tested helpers.
- CheckpointManager now receives Isar through injection rather than importing the global database directly.
- project comment import has a typed extraction plan and injected persistence repository.
- all five target platforms completed one deliberate build gate successfully.

The remaining work is therefore no longer primarily "replace BLoC with Riverpod".

The primary goals are now:

1. eliminate the last global/static persistence bridges;
2. consolidate duplicated preference persistence;
3. replace project/import compatibility maps with typed models end-to-end;
4. add real Isar integration tests;
5. shrink mixed-responsibility controllers/services only after their boundaries are proven;
6. perform a measured performance/logging pass;
7. remove migration shims and dead legacy infrastructure.

## 2. Current measured baseline

Repository snapshot at audit head:

- 426 tracked files;
- 278 Dart files total;
- 252 non-generated Dart files under `lib/`;
- 25 Dart test files;
- no committed test currently initializes or exercises Isar;
- one main route-scoping widget regression suite;
- current head is 4 commits ahead of the last green analyzer/test checkpoint.

Largest active non-generated files include:

- `msone_submission_screen.dart`: ~1,616 lines;
- `subtitle_effects_sheet.dart`: ~1,455 lines;
- `subtitle_extract_options_sheet.dart`: ~1,481 lines;
- `marked_lines_sheet.dart`: ~1,390 lines;
- `help_catalog.dart`: ~1,325 lines;
- `ffmpeg_helper.dart`: ~1,326 lines;
- `dictionary_search_widget.dart`: ~1,258 lines;
- `malayalam_normalization_sheet.dart`: ~1,188 lines;
- `olam_dictionary_widget.dart`: ~1,185 lines;
- `ai_explanation_sheet.dart`: ~1,181 lines;
- `checkpoint_sheet.dart`: ~1,108 lines;
- `edit_controller.dart`: ~1,097 lines;
- `edit_line_repository.dart`: ~958 lines;
- `database_helper.dart`: ~896 lines;
- `checkpoint_manager.dart`: ~900 lines;
- `edit_line_controller.dart`: ~851 lines.

Line count is not itself the priority metric. Files are ranked by responsibility mixing, global state, persistence ownership, platform branching, hot-path rebuild frequency, and testability.

## 3. Structurally healthy areas

### Riverpod state ownership
Home, Editor, Edit Line, Source View, and Waveform are no longer driven by BLoC/Cubit. Editor/Edit Line/Source View use route-specific configuration providers and explicitly declare scoped provider dependencies.

### Core Isar injection
A root `isarProvider` exists and is overridden at application bootstrap. Major new repositories use injected Isar rather than importing the database singleton.

### Import architecture
The subtitle import pipeline now has `SubtitleImportResult`, `SubtitleEncodingDecoder`, an injected `SubtitleImportRepository`, and parser/cleanup tests.

### Project documents
The project path now has `ProjectDocumentCodec`, `ProjectDocumentBuilder`, `ProjectFileService`, a typed `ProjectDocument` wrapper, and structural regression tests.

### Checkpoints
Pure components now exist for state copying/delta application, snapshot/retention policy, and ancestor/delta/branch traversal. CheckpointManager now owns an injected Isar instance.

### Cross-platform baseline
A deliberate build gate successfully built Android, Windows, Linux, macOS, and iOS. Routine CI remains analyzer + tests only.

## 4. Critical findings

### P0 — Verify current head before more structural changes
The last successful analyzer/test checkpoint is `049a8db`. The audit head `cff387f` is four commits ahead and contains additional checkpoint/project injection work. Run one analyzer/test checkpoint before the next behavioral refactor. Do not run platform builds.

### P0 — No Isar integration tests exist
All 25 current test files avoid Isar. This leaves checkpoint persistence, project import, subtitle import persistence, repository mutations, preference singleton behavior, and session cascades unverified against the actual database engine.

Add a reusable temporary Isar harness and integration coverage before deeper persistence refactors.

### P0 — Preference persistence is duplicated across repositories
Multiple feature repositories independently implement find/create/update logic for `Preferences` and `VideoPreferences`. The legacy `PreferencesModel` duplicates it again.

Because `Preferences.id` uses `Isar.autoIncrement`, independent concurrent "find first -> create" paths do not structurally guarantee a singleton.

Introduce:
- `PreferencesStore`;
- `VideoPreferencesStore`;
- atomic create/update behavior;
- typed feature repositories on top of those stores.

Do not replace typed feature repositories with a generic string-key API.

### P0 — Residual global/static persistence is now small enough to eliminate
Remaining notable legacy/global dependencies include:
- `database_helper.dart`;
- `preferences_model.dart`;
- `subtitle_effect_operations.dart`;
- `hearing_impaired_cleanup_service.dart`;
- waveform audio/zoom paths using static `PreferencesModel`;
- `FilePickerSAF`;
- `FirstTimeInstructions`;
- `AiExplanationButton`;
- the temporary `CheckpointRepository.fromGlobal()` bridge.

Target: remove feature-level global Isar and static PreferencesModel usage, then retire DatabaseHelper and PreferencesModel.

### P0 — Project typing stops too early
The codec validates a `ProjectDocument`, but downstream import/save paths convert back to maps.

Current map-heavy areas include:
- `ProjectDocument.toLegacyMap()`;
- `ImportProjectSheet`;
- `SessionSelectionSheet`;
- `SessionProjectImportRepository`;
- `ProjectDocumentBuilder`;
- `ProjectManager`.

Introduce typed project DTOs for session, collection, line, checkpoint, delta, and metadata. Keep maps only inside JSON serialization.

### P1 — Checkpoint architecture is improved but still too broad
`CheckpointManager` remains ~900 lines and still mixes persistence queries/writes with creation, restore, branching, and operation-specific orchestration.

After integration tests:
- add `CheckpointStore` for CRUD/query;
- reduce manager/service to orchestration;
- retain pure reducer/policy/timeline helpers.

### P1 — Waveform still contains migration-era architecture
Waveform is Riverpod-managed but still exposes BLoC-style `dispatch(WaveformEvent)`.

Lower layers still bypass injection:
- `AudioProcessor` -> static PreferencesModel cache;
- `ZoomBufferGenerator` -> static waveform preferences;
- zoom preferences use `Map<String, dynamic>`.

Add typed cache/config repositories and gradually replace event dispatch with explicit Notifier methods. Keep frame-frequency state narrowly scoped.

### P1 — ProjectManager remains a static orchestration god utility
It coordinates document construction, checkpoint fetching, Android/iOS/desktop save behavior, update-existing-file behavior, and UI session-selection display.

Target:
- injected project save coordinator;
- project file service for platform I/O;
- UI owns dialogs/navigation;
- remove `showSessionSelectionSheet` from the service layer.

### P1 — Source View duplicates file-access and encoding infrastructure
Source View owns direct File access, MethodChannel SAF reads, SharedPreferences SAF metadata, encoding fallback, and save fallbacks.

Add `SourceFileAccessRepository`, reuse `SubtitleEncodingDecoder`, and keep the controller focused on editable content/state.

### P1 — Editor controllers/repositories remain broad
`EditController` ~1,097 lines; `EditLineController` ~851 lines; `SubtitleRepository` ~634 lines; `EditLineRepository` ~958 lines.

Comments indicating "legacy UI already performed database mutation" show remaining double ownership. The target is controller -> repository mutation -> returned domain data -> state update, with no UI persistence followed by local replacement.

Do not split solely by line count; remove dual ownership first.

### P1 — DatabaseHelper is a retirement target
It remains ~896 lines, still global, and covers unrelated sessions/subtitles/dictionary/application-data domains. No new code should use it.

### P1 — PreferencesModel is a retirement target
Most UI callers are migrated. Remaining consumers are concentrated enough to remove after shared preference stores exist.

### P1 — High-risk mixed UI surfaces
Highest priority for later decomposition:
1. subtitle extraction;
2. subtitle effects;
3. marked lines/comments;
4. dictionary search;
5. AI explanation;
6. Olam dictionary;
7. Malayalam normalization;
8. search/replace;
9. subtitle sync;
10. MSone submission.

Large static-content files such as `help_catalog.dart` are lower priority.

### P1 — Logging is excessively noisy in hot/platform paths
Approximate raw print concentrations:
- `ffmpeg_helper.dart`: ~130;
- `fullscreen_controls.dart`: ~63;
- `subtitle_extract_options_sheet.dart`: ~65;
- AudioProcessor: ~30+;
- project path helpers: ~23;
- intent/hotkey paths: ~20–25.

Move to structured AppLogger categories, operation IDs, safe path metadata, and debug-only native command verbosity.

### P2 — Async lifecycle/fixed-delay debt
Classify each delay: keep real retry/backoff/animation behavior, replace readiness guesses with completion signals.

Review Home navigation, first-time instructions, waveform rendering, FFmpeg retries, and extraction verification.

### P2 — Platform file identity remains fragmented
Paths, Android content URIs, temporary cache paths, macOS bookmarks, and display names are represented by loosely related strings.

Introduce typed file identity/access metadata and migrate import/project/video/secondary/source-view flows gradually.

### P2 — Compatibility shims need deletion criteria
Examples:
- `screen_repository.dart`;
- `CheckpointRepository.fromGlobal()`;
- project legacy maps;
- Waveform event classes;
- DatabaseHelper;
- PreferencesModel;
- duplicate banner sheet variants.

## 5. Revised execution plan

### Phase 0 — Verify current head
Run analyzer + tests only and fix any post-checkpoint injection errors.

### Phase 1 — Add Isar integration-test harness
Add temporary Isar harness and tests for:
- Preferences singleton/concurrent creation;
- VideoPreferences uniqueness per collection;
- checkpoint snapshot/delta/restore/branch/cleanup;
- SubtitleRepository mutations;
- EditLineRepository save/new/delete;
- SessionRepository deletion/summaries;
- ProjectRepository rename/path;
- SubtitleImportRepository persistence.

### Phase 2 — Consolidate preference stores
Add `PreferencesStore` and `VideoPreferencesStore`; migrate all feature repositories; remove remaining static callers; delete `PreferencesModel`.

### Phase 3 — Eliminate global database access
Migrate SubtitleEffectOperations and HearingImpairedCleanupService; migrate DatabaseHelper consumers; remove fromGlobal bridge; retire DatabaseHelper.

### Phase 4 — Finish typed project pipeline
Add typed DTOs; make codec/builder/session import typed; remove legacy maps; replace static ProjectManager with injected coordinator; move session-selection UI out of ProjectManager.

### Phase 5 — Finish checkpoint storage split
After integration tests, add CheckpointStore, move Isar query/write code out of manager, retain pure helpers, delete global bridge.

### Phase 6 — Waveform cleanup
Typed waveform cache/config, injected AudioProcessor/ZoomBufferGenerator dependencies, typed zoom preferences, explicit controller methods, cancellation/stale-result tests.

### Phase 7 — File-access unification
Typed file identity/access model; migrate Source View, secondary subtitles/video, projects, import/export, and FilePickerSAF preference handling.

### Phase 8 — Editor ownership cleanup
Remove UI-persistence + local-state replacement paths, eliminate unnecessary DB refreshes, add integration tests, then split controllers by feature responsibility.

### Phase 9 — Mixed UI decomposition
Refactor the high-risk widgets in the priority order above. Each gets typed state, coordinator/controller, repository/service, presentation-only widget, and tests.

### Phase 10 — Logging/performance pass
Measure startup, Home load, import, Editor/Edit Line initialization, project save/import, checkpoint restore, waveform generation, large-file scrolling/search, and extraction before optimizing.

### Phase 11 — Dead-code/compatibility cleanup
Remove shims only after usage scans and tests.

### Phase 12 — Platform modernization
Keep Android Gradle/AGP/Kotlin, Windows/Linux native configuration, macOS deployment/bookmarks, and iOS build work isolated from architecture refactors.

## 6. CI strategy

Routine:
- `flutter analyze`;
- `flutter test`.

Cadence:
- after meaningful structural batches;
- approximately every 8–10 commits;
- immediately after high-risk persistence changes.

Five-platform gate:
- before major integration PR;
- after native/toolchain changes;
- not for normal Dart refactors.

## 7. Immediate next commit sequence

1. verify current `cff387f` head with analyzer/tests;
2. add reusable Isar test harness;
3. add Preferences/VideoPreferences singleton tests;
4. add checkpoint persistence/restore integration tests;
5. introduce shared PreferencesStore + VideoPreferencesStore;
6. migrate waveform cache/config off PreferencesModel;
7. migrate AI button/tutorial/file-picker static preferences;
8. migrate SubtitleEffectOperations/HearingImpairedCleanupService off global Isar;
9. remove final `CheckpointRepository.fromGlobal()` caller;
10. run analyzer/tests checkpoint;
11. begin typed project DTO migration.

## 8. Refactor invariants

1. No Isar schema redesign unless a concrete requirement demands it.
2. No new global Isar access.
3. No new static PreferencesModel usage.
4. No new DatabaseHelper usage.
5. No new `CheckpointRepository.fromGlobal()` usage.
6. No new cross-layer dynamic maps when typed models are feasible.
7. No persistence inside presentation widgets.
8. No platform-storage branching inside presentation widgets.
9. High-frequency player/render state stays narrowly scoped.
10. One structural responsibility per commit.
11. Behavior fixes receive regression coverage where practical.
12. Analyzer/tests run at deliberate checkpoints.
13. Platform builds remain separate.
14. Compatibility shims require a deletion condition.
15. New persistence code must have Isar integration coverage.


## 10. UX additions and execution order — October 16, 2026

**New workstreams added to the roadmap:**

1. **Real graphical edit history** (P1 UX). Build a lane-based version map and
   readable timeline using the existing immutable graph/references and guarded
   checkout commands; support mobile first and large histories, with distinct
   current/saved/pinned/alternate states, node details and accessible list mode.
2. **Nontechnical history language** (P1 UX). Default to *Current version*,
   *Version*, *Editing path*, *Pin version* and
   *Continue editing from this version*. Explain alternate paths and retention
   honestly in confirmations. Keep `HEAD`, branch reference names and
   checkpoint IDs only in internal state, developer/advanced details and
   project exports. Never label history references as backup files.
3. **SubtitleStudio design system** (P1 UX, required foundation for later UX).
   Adopt a distinct frame/cue identity and semantic light/dark palette,
   typography, spacing, standardized action buttons, sheets, forms, cards,
   navigation and status components. Migrate screens incrementally with
   snapshot, contrast, accessibility, RTL and multilingual regression checks;
   respect saved theme/custom-font preferences.
4. **Compact Edit Line screen** (P1 UX, after design tokens). Pilot a portrait-
   first layout: short header/save, optional collapsible video, accessible
   paired timing controls, source text, flexible editable target, keyboard-
   aware formatting strip and Prev/Play/Next navigation. Keep mark/comment,
   dictionaries, sync, shortcuts, translation/edit mode, save protection and
   full-screen player behavior.

**Proposed order:** CP85 mobile stability verification → UX baseline audit
→ shared visual tokens/components → history copy → history graph GUI →
opt-in mobile Edit Line pilot → migrate remaining screens → performance/
accessibility gate → future desktop workspace. Continue native waveform and
encoding validation in their own workstreams; do not combine large visual
changes with native media rework in the same commit.

**Definition of done:** each stage has analyzer and focused widget/unit/
integration tests, screen reader/text-scale/keyboard checks, real Android
smoke tests and history/data-integrity invariants where relevant.
Do not run all five platform builds on routine changes.

Detailed specs, proposed palette, user label mapping, mobile wireframe,
component reuse boundaries, acceptance criteria and rollout gates:
[SubtitleStudio UX roadmap (2026-10-16)](SUBTITLESTUDIO_UX_ROADMAP_2026-10-16.md).
