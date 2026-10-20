# SubtitleStudio — Refactoring Completion Before Desktop UI

Decision date: October 20, 2026
Active branch: `refactor/riverpod-architecture`
Future desktop workspace: **blocked until core refactoring acceptance**

## Binding project decision

The user has paused additional waveform research/optimization and elected to **complete the remaining SubtitleStudio refactor roadmap first, then design and implement the dedicated desktop UI**. Do not reopen CP86 R12 progressive audio work during the core-refactoring phase. The experiment is preserved on `experiment/cp86-r9-windowed-waveform-preview` at R11 and is **not to be merged now**. The stable branch preserves its previously tested R5–R7 waveform/cache pipeline. Appearance skins and the standalone community Skin Creator site remain frozen/deferred unless necessary for a reproducible regression.

## Archived native waveform evidence

The final physical Android capture `cp86_r11.log` (October 20, app PID 5954) shows 30-second seek extraction at 30:00 in **1,000 ms** (82,680 samples), `R10 PREVIEW_CREATED` at 21:48:01.281, **R11 SPARSE_VIEWPORT_PAINTED** at 21:48:01.316, sampled `lagSamples=0 relativeError=0.0000` against the full waveform and full acquisition **135,329 ms** (`ffmpegMs=129,279 peakMs=4,638`). No fresh native SIGSEGV, app ANR or fatal Flutter exception in this capture. The older `R10 PREVIEW_PAINTED` marker is not emitted with the alternate R11 painter; the R11 marker is the appropriate evidence. Device qualification is limited to one Android MKV and Auto track; it does **not** validate timestamp gaps, codec offsets, explicit tracks or interactive partial waveform editing. Details committed to the experimental [R11 report](https://github.com/anzilr/SubtitleStudio/blob/experiment/cp86-r9-windowed-waveform-preview/docs/refactor/CHECKPOINT86_R11_PROGRESSIVE_COVERAGE_2026-10-20.md).

## Current baseline: completed vs unverified

**Implemented:** Riverpod entrypoints for Home/Editor/Edit Line/Source View/Waveform; shared Isar stores and integration harness; typed project documents/save coordinators; Git-style immutable checkpoint storage, branches/bookmarks and portable `.msone`; deprecated global `DatabaseHelper`, `PreferencesModel`, `CheckpointRepository.fromGlobal()` and legacy project DTO paths removed where previously verified. The Android MSone Back stale-navigation gesture problem was verified fixed in CP87 R13 on CPH2381. Appearance support is 4 skins × Light/Dark/Classic with Carbon Zero default, appearance audit frozen.

**Not accepted yet:** complete Source View/path/grant handling and encoding symmetry; fragmented Editor controller/file access boundaries; large cross-layer UI classes; history visual map/nontechnical wording and compact mobile Edit Line; structured privacy-conscious logs/performance; compatibility shim cleanup; platform smoke acceptance. Native media-kit Flutter hot restart is not recently reverified; do not label it fixed or use hot restart as a routine device testing mechanism.

The earlier sections of `REFACTOR_ROADMAP_V4.md` include historical "immediate next commits" from checkpoint 43 and older CP87 freeze descriptions. They are preserved for traceability and **are not the current active plan**.

## Ordered core completion checkpoints

### CP88 — Source View and file-access ownership [ACTIVE]
- Use `StudioFileIdentity` to distinguish native local paths and Android content-document locators before Source View read/save fallbacks; never call `File(contentUri)` as if it were an actual local file.
- Retain original persisted locators, the existing SAF preference key and current grants. Guard fallback writes against accidental URI/local alias confusion. Cover through targeted Flutter tests.
- Next: a platform-neutral file-access interface for Source View/secondary video/import/export; migrate Android SAF and file-URI cases behind a repository rather than directly in the Riverpod controller. Native Android permission revocation and direct-source URI smoke tests.
- Finish import/export/Source View source identity convergence before declaration of Phase 7 completed.

### CP89 — Encoding and text round-trip
- Audit the **current** unified `SubtitleExtendedEncodingService` and its existing support rather than reimplement outdated CP65 limitations.
- Make raw Source View decode/encode use a shared proven encoding + BOM policy; preserve user edits, newline form, unrepresentable-character errors and selected source encoding without silent fallback. Test UTF-8/16 BOM, Windows code pages, Android SAF and invalid byte sequences.
- Explicit preview/manual override where ambiguous; lossless save/load tests, including non-Latin scripts. Do not change existing saved Isar schema solely to finish encoding.

### CP90 — Editor ownership / mixed UI refactor
- Identify and isolate the largest remaining mixed-responsibility Editor/Edit Line/Source View modules; decouple UI from persistence/media/filesystem operations while preserving existing Riverpod state and checkpoint behavior.
- Prefer injectable services/coordinators, typed outcomes and widget tests. Verify source editing round trips, comment/mark preservation, secondary track fallback, keyboard and Android Back behavior.
- Keep the shared core reusable by both Flutter mobile widgets and the later desktop presentation.

### CP91 — Outstanding roadmap UX needed on mobile
- Deliver the Git-style **visual checkpoint history** with plain-language controls, accessible list alternative and protected refs; preserve `.msone` compatibility and multi-branch correctness.
- Complete compact mobile Edit Line usability and core component consistency only to the extent planned by the already-approved UX roadmap; retain Carbon Zero and other shipped skins.
- Do not start desktop-specific screen layouts here.

### CP92 — Cleanup, regression and performance
- Audit remaining compatibility shims, unused dependencies/imports, dynamic data bridges, duplicate views and static access. Remove only with usage scans/tests and preservation of import/history/data semantics.
- Scope logging by feature, avoid exposing source URIs or personal media filenames, reduce redundant hot-path logs, and benchmark critical import/open/save/restore workflows.
- Update roadmap checkmarks using verified evidence, not only planned work.

### CP93 — Core refactor acceptance and handoff
- Flutter analysis and full unit/widget/Isar integration tests in GitHub Actions (dependency resolution + tests only; **no platform builds in CI**).
- Native builds and smoke tests on Android and desktop operating systems on user/local machines. Preserve fast Back/touch behavior, media lifecycle, file/SAF grants and `.msone` roundtrip.
- Resolve open P0/P1 core defects, publish a migration/compatibility summary, and declare the shared architecture ready.

### Next: Desktop Workspace / UI [ONLY AFTER CP93]
- Start with a desktop layout design and a reusable application shell, not a separate domain/data layer. Keep one shared Riverpod, Isar, project, checkpoint, encoding and file-access core.
- PC single-screen workflow: project navigator/history, video + waveform, cue editor/table, tools/sidebar; keyboard shortcuts, resizable panes and platform file dialogs.
- Do not regress mobile UI; desktop layout and window persistence stay platform-responsive.

## Acceptance discipline

- Implement small, independent changes with focused tests and a checkpoint report; do not combine media-native experiments and architecture refactors in one commit.
- Treat a successful analyzer/test run as **code-level** proof only, not Android/Windows native acceptance.
- The waveform experiment can resume later from its isolated branch after a new explicit prioritization.
