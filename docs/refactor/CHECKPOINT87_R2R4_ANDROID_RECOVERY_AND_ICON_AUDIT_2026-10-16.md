# SubtitleStudio CP87 R2–R4: Android session recovery and icon contrast audit

**Date:** 2026-10-16
**Branch:** `refactor/riverpod-architecture`
**Flutter gate:** [GitHub Actions 38965180956](https://github.com/anzilr/SubtitleStudio/actions/runs/38965180956) — **SUCCESS, 527 Flutter tests passed, 0 analyzer issues** at code `7ed20ab`. This verifies Dart/Flutter code only, not native Android/Windows acceptance.
**Appearance policy:** Still frozen. Only user-reported contrast failures are corrected.

## Incident diagnosis — primary data was available

Android 14 CPH2381 relaunch log from 23:28 shows the affected
subtitle collection was fetched successfully four times, with **895 lines**.
Loading then failed inside `VideoRepository.loadSavedSecondarySubtitle`
when a saved secondary subtitle path resolved to a missing
`.../code_cache/extracted_subtitle_*.srt`. Stack traces identify the
`_parseSubtitleFile → loadSavedSecondarySubtitle → EditController.initialize`
chain. A different project with 622 lines and no configured secondary track
loaded successfully. The earlier MSone back-navigation freeze itself was
not logged, so its precise cause and any relation to missing secondary
cache data **cannot be proven**.

### R2 — Data-safe recovery

- Optional secondary subtitle read/parse failures are logged and skipped
  without poisoning the primary editor initialization.
- Missing legacy app-owned temporary extracts are cleared from the saved
  secondary preference; user-picked source paths that are currently
  missing remain saved for later relocation/reconnection.
- When the user chooses an embedded track as secondary, extraction writes
  atomically under `getApplicationSupportDirectory()/secondary_subtitles`,
  using a same-directory staging file and flush before rename.
- The new preference is saved **after** the file exists, and the previous
  app-owned extract is deleted only after new persistence succeeds.
- The same write-before-cleanup ordering now also applies when switching to
  an external secondary file or switching back to original text; a failed
  preference write cannot leave a previously referenced extract deleted.
- Automatic cleanup requires the known app support root or matches a
  strictly identified Android private old-cache path. External files
  are never deleted simply because their name starts `extracted_subtitle_`.
- Test coverage includes pure file durability and real-Isar preference
  integration for lost legacy cache, missing user-picked source and
  persisted valid SRT.

The original embedded track's old cache file is already missing and cannot
be reconstructed from the logs. The user can re-extract/reselect that track
after the primary project opens normally. Do not clear the app's data.

## R3 / R3B — Modal icon contrast audit

Affected badges/controls were using a light `colorScheme.primary`,
`secondary` or `tertiary` background with `Colors.white` glyphs or
labels in Carbon Zero Dark/Classic. Each now uses the matching semantic
foreground role (primary → onPrimary, secondary → onSecondary, tertiary →
onTertiary). The changes cover:

- Video Settings: playback speed, custom font, subtitle text/position and
  other primary badge icons;
- Load Secondary Subtitle action cards;
- Save File As / Export Options, Project Settings bookmarked lines, and
  Subtitle Tracks;
- Import Subtitle and Project action badges, checkbox checkmarks and
  segmented selection;
- Merge/Split confirmations, Locate SRT, session selection, subtitle
  effects, and the banner insertion progress indicator.

Tests include theme-mode widget checks and a source-level regression
guard on high-risk accent icon badges. White on black media seek overlays,
legitimate authored subtitle colors, and selected subtitle-content colors
are intentionally untouched.

## R4 — MSone back-navigation defensive fixes

`MsoneSubmissionScreen` previously allowed async file-picker/network
callbacks to call `setState` or show SnackBars after a back-navigation
route pop. The success dialog also popped twice using the inner dialog
context. R4 guards updates against disposed/popped routes, closes the
correct navigator contexts, bounds HTTP submission waits to 45 seconds,
and logs route-pop breadcrumbs. These are **defensive lifecycle fixes**, not
a confirmed root-cause fix for the earlier unlogged freeze. Repeat
Android back testing with logging active before signing off.

## Android retest

1. Install the new debug build without clearing app storage. Reopen the
   affected subtitle session; verify its 895 subtitle lines and edited
   text are visible. The stale secondary overlay may be absent.
2. Re-extract an embedded secondary track, leave the editor, restart the app
   and reopen twice. Verify the secondary track survives process restart.
3. Open MSone submission, use Android system Back from each step and from
   the initial screen, then reenter Editor. Capture freezes/ANRs with
   `adb -s CPH2381 logcat -b main -b system -b crash -v threadtime` and
   `adb -s CPH2381 bugreport` if needed.
4. In Carbon Zero Dark and Classic, test Video Settings, Save File As,
   Load Secondary Subtitle, Project Settings and the additional audited
   selection, import and confirmation sheets at 360dp.
5. Keep CP86 cold waveform and native `libmpv.so` hot-restart qualification
   open independently. Do not claim successful release-device validation
   from Linux Flutter CI alone.

## Next CP87 stages

Typed read/write results and file grant metadata, Source View access migration,
platform bookmark-safe persistence, and Editor lifetime testing. No changes
to Isar collection schemas, data-reset workflows, new themes or desktop
workspace were performed here.

**Final Flutter quality gate:** 527 tests and 0 analyzer issues ([CI](https://github.com/anzilr/SubtitleStudio/actions/runs/38965180956)); root-cause attribution for the unlogged MSone freeze and all physical native QA remain pending.
