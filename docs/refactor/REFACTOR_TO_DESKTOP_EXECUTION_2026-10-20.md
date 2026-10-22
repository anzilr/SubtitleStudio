# SubtitleStudio — Parallel Desktop Preview and Core Refactoring

Decision date: October 20, 2026
Active branch: `refactor/riverpod-architecture`
Desktop workspace: **UI preview in parallel now; production integration after CP93 shared-core acceptance**

## Binding project decision

The user has paused additional waveform research/optimization and now approved **starting desktop presentation design in parallel with the remaining SubtitleStudio refactoring**. The desktop layout preview may proceed independently, but production data/media/Isar integration waits for the relevant shared service contracts and final CP93 acceptance. Do not reopen CP86 R12 progressive audio work during the core-refactoring phase. The experiment is preserved on `experiment/cp86-r9-windowed-waveform-preview` at R11 and is **not to be merged now**. The stable branch preserves its previously tested R5–R7 waveform/cache pipeline. Appearance skins and the standalone community Skin Creator site remain frozen/deferred unless necessary for a reproducible regression.

## Desktop workspace parallel preview — approved October 20, 2026

- **Shared core track:** `refactor/riverpod-architecture` continues CP88–CP93. This branch owns file/SAF, subtitle encoding, Riverpod controllers, Isar/project/checkpoint compatibility, and native QA.
- **Presentation track:** [`feature/desktop-workspace-preview`](https://github.com/anzilr/SubtitleStudio/tree/feature/desktop-workspace-preview) prototypes a single-screen desktop shell (project rail/sidebar, video pane, waveform strip, subtitle table and line inspector). It launches independently via `flutter run -d windows -t lib/main_desktop_preview.dart`. Content is labeled demo-only, and the preview cannot read or write user data.
- Implement desktop resizing, window breakpoints, keyboard-friendly cue selection and visual polish now. Do **not** fork business logic, create separate Isar schemas or media engines, merge incomplete desktop APIs into mobile, or advertise the preview as a production editor.
- Once CP88 file-access, CP90 editor and CP91 checkpoint UI contracts settle, connect desktop panels to the existing shared Riverpod/repository services through adapters and test each integration individually.
- Reconcile/rebase the desktop branch from the core branch at controlled checkpoints, not across half-completed migrations. Local Windows builds and smoke testing belong to the user/developer machine. GitHub CI runs only `flutter pub get`, `flutter analyze` and `flutter test`.
- **Release gate unchanged:** CP93 must pass before production desktop editing is declared complete; this gate does not forbid early design and isolated layout implementation.

## Archived native waveform evidence

The final physical Android capture `cp86_r11.log` (October 20, app PID 5954) shows 30-second seek extraction at 30:00 in **1,000 ms** (82,680 samples), `R10 PREVIEW_CREATED` at 21:48:01.281, **R11 SPARSE_VIEWPORT_PAINTED** at 21:48:01.316, sampled `lagSamples=0 relativeError=0.0000` against the full waveform and full acquisition **135,329 ms** (`ffmpegMs=129,279 peakMs=4,638`). No fresh native SIGSEGV, app ANR or fatal Flutter exception in this capture. The older `R10 PREVIEW_PAINTED` marker is not emitted with the alternate R11 painter; the R11 marker is the appropriate evidence. Device qualification is limited to one Android MKV and Auto track; it does **not** validate timestamp gaps, codec offsets, explicit tracks or interactive partial waveform editing. Details committed to the experimental [R11 report](https://github.com/anzilr/SubtitleStudio/blob/experiment/cp86-r9-windowed-waveform-preview/docs/refactor/CHECKPOINT86_R11_PROGRESSIVE_COVERAGE_2026-10-20.md).

## Current baseline: completed vs unverified

**Implemented:** Riverpod entrypoints for Home/Editor/Edit Line/Source View/Waveform; shared Isar stores and integration harness; typed project documents/save coordinators; Git-style immutable checkpoint storage, branches/bookmarks and portable `.msone`; deprecated global `DatabaseHelper`, `PreferencesModel`, `CheckpointRepository.fromGlobal()` and legacy project DTO paths removed where previously verified. The Android MSone Back stale-navigation gesture problem was verified fixed in CP87 R13 on CPH2381. Appearance support is 4 skins × Light/Dark/Classic with Carbon Zero default, appearance audit frozen.

**Not accepted yet:** complete Source View/path/grant handling and encoding symmetry; fragmented Editor controller/file access boundaries; large cross-layer UI classes; history visual map/nontechnical wording and compact mobile Edit Line; structured privacy-conscious logs/performance; compatibility shim cleanup; platform smoke acceptance. Native media-kit Flutter hot restart is not recently reverified; do not label it fixed or use hot restart as a routine device testing mechanism.

The earlier sections of `REFACTOR_ROADMAP_V4.md` include historical "immediate next commits" from checkpoint 43 and older CP87 freeze descriptions. They are preserved for traceability and **are not the current active plan**.

## Ordered core completion checkpoints

### CP88 — Source View and file-access ownership [ACTIVE]

**CP88 R9 cross-platform CI / file-URI compatibility (October 21, 2026):**
Source View now decodes native `file://` locations at the I/O boundary,
including percent-escaped Windows/POSIX paths, without modifying persisted
identity or confusing SAF grants. Secondary subtitle file-URI conversion is
injected/testable for Windows and POSIX. CI now exercises the full Flutter
suite on Linux and focused file/encoding tests on actual Windows and macOS
runners; iOS policy is verified through simulated adapters (not an iPhone
runtime). No platform app builds run in Actions.
[R9 report](CHECKPOINT88_R9_CROSS_PLATFORM_FILE_URI_GATE_2026-10-21.md).
**Final Flutter CI: [Linux 614, Windows 71, macOS 71 tests passed; all analyzers clean](https://github.com/anzilr/SubtitleStudio/actions/runs/39631680679).**
**Native Android/Windows/macOS/iOS acceptance still required.**


**CP88 R8 project-settings media picker migration (October 21, 2026):**
Audited legacy path-only picker users. Project Settings' fallback video
selection now uses URI-only access (avoids loading an entire video into
memory) and secondary subtitle selection persists the real Android SAF URI,
never its synthetic display hint. URI-only video selections are typed and
validated; subtitle extraction requires an `accessLocator`. `.msone` project
and comment imports already use picked Android document bytes and preserve
their existing behavior. Details and pending native scenarios:
[R8 report](CHECKPOINT88_R8_PROJECT_SETTINGS_MEDIA_PICKERS_2026-10-21.md).
**Final R8 Flutter-only CI: [604 tests, zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39629226171).**
**Android and Windows real picker/grant acceptance remains outstanding.**


**CP88 R7 canonical import/Source View access (October 21, 2026):** New injectable [SubtitleImportFileReader](CHECKPOINT88_R7_IMPORT_AND_SOURCE_VIEW_2026-10-21.md) routes direct and selected `content://` sources through SAF and `file://`/native desktop sources through their proper adapters without confusing display hints and real locators. Home Source View now opens selected Android documents using their original URI. Original `filePath` display/persistence hints and `originalFileUri` remain compatible. [Final Flutter CI: 600 tests, analyzer no issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39621384992). **CP88 R8 remaining:** audit/deprecate remaining path-only Android picker API, project/comments picker and video document flows; native Android SAF and Windows validation is outstanding.


**CP88 R6 typed picker identity (October 21, 2026):** `StudioPickedFileReference` separates authoritative `accessLocator` (content URI/native path) from display-only `displayPath`; the old picker map retains `displayPath`, `safUri`, and `bytes` while adding `accessLocator` for migrated consumers. Raw SAF/local-path logging is redacted. [R6 report](CHECKPOINT88_R6_PICKER_IDENTITY_2026-10-21.md) · [Final Flutter CI: 592 tests, analyzer no issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39617810442). **Not yet a full migration:** the legacy string-returning Android `pickFile` call still provides a normalized display path; CP88 R7 must audit/migrate its consumers before changing that API. Native Android SAF / desktop verification is pending.


**CP88 R5 project-update boundary (October 21, 2026):** Existing `.msone` updates now delegate to the injectable, typed [ProjectDocumentUpdateService](CHECKPOINT88_R5_PROJECT_UPDATE_2026-10-21.md): Android document write vs real native file, converted `file://` URIs, rejection of remote/opaque destinations, and no silent creation of a missing original. Real desktop temporary-file and fake-platform regressions. [Final CI: 587 tests passed, zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39615780906). **Native Android SAF and Windows acceptance still pending**. CP88 next: picker/import and video locator semantics, especially separating SAF display paths from actual access identity; CP89 encoding remains next major refactor.


**CP88 R4 code-level acceptance (2026-10-20):** A typed, injectable [SecondarySubtitleDocumentReader](CHECKPOINT88_R4_SECONDARY_FILE_ACCESS_2026-10-20.md) now routes native files, `file://` URIs and Android SAF documents without `File(contentUri)`; opaque provider document IDs are identified by recognizable SRT/WebVTT/ASS signatures. Isar-backed tests cover revoked grant fallback and restoring the saved secondary URI. [Flutter CI: 579 tests, zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39490395278). **Native SAF and Windows acceptance remains pending.** Next CP88 R5: audit video/project/import/export locators and finalize shared access adapter contract before CP89.


**CP88 R3 code-level acceptance (2026-10-20):** The controller's persisted SAF locator operations now belong to an injectable `SourceViewSafGrantRepository`. Legacy `saf_uri_<filePath>` preference identity remains unchanged; explicit valid selections override stale values, mismatched direct-document references are pruned, and the actual SharedPreferences adapter is regression tested. [Flutter-only gate: 569 tests, analyzer no issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39484474034). This is **not native SAF acceptance**. [Checkpoint report](CHECKPOINT88_R3_SAF_GRANT_REPOSITORY_2026-10-20.md).

- Use `StudioFileIdentity` to distinguish native local paths and Android content-document locators before Source View read/save fallbacks; never call `File(contentUri)` as if it were an actual local file.
- Retain original persisted locators, the existing SAF preference key and current grants. Guard fallback writes against accidental URI/local alias confusion. Cover through targeted Flutter tests.
- Next: a platform-neutral file-access interface for Source View/secondary video/import/export; migrate Android SAF and file-URI cases behind a repository rather than directly in the Riverpod controller. Native Android permission revocation and direct-source URI smoke tests.
- Finish import/export/Source View source identity convergence before declaration of Phase 7 completed.

### CP89 — Encoding and text round-trip

**CP89 R3 (October 21, 2026):** Preserve empty subtitle cues, intentionally
blank text lines and whitespace when opening/importing SRT through the shared
parser, structured Isar import and Editor raw-source Save. Optional
hearing-impaired cleanup retains preexisting blank cues. The rules use valid
cue headers to identify boundaries and remove only one structural separator;
raw Source View retains byte-exact newline style. Added unit, Isar and Source
View regressions. [R3 report](CHECKPOINT89_R3_BLANK_CUE_IMPORT_2026-10-21.md).
**Verification:** [Linux 635 tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39644802316),
[Windows 104 targeted tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39644802337).
The R3 macOS runner was canceled while queued; it is not counted as passed.
Native smoke acceptance remains separate. CP90 R1 later passed the macOS
targeted regression suite on the same branch.

**CP89 R2 (October 21, 2026):** Editor export now honors explicitly blank
edited cues instead of restoring the original text, and desktop file export
validates a shared encoded byte result before touching the destination.
Unit, temporary-file and Isar integration tests cover edit/clear, UTF BOMs,
Windows-1252, and incompatible charset failures. This change is
platform-sensitive: Linux full suite plus focused Windows/macOS Flutter checks
are required, without application builds. [Checkpoint report](CHECKPOINT89_R2_EDITED_EXPORT_ROUNDTRIP_2026-10-21.md).
**Verification:** [Linux 624 tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39640233941),
[Windows and macOS each 80 tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39640233399).
Native acceptance and import → editor line-ending retention remain pending.

**CP89 R1 (October 21, 2026):** Raw Source View now uses the shared strict
byte codec for reading and saving, preserves UTF BOMs and original newlines,
and offers an explicit legacy charset chooser. Android Home no longer
pre-decodes SAF bytes as UTF-8/Latin-1. Save As checks representability before
creating a document. Source View controller round-trip tests cover Unicode,
Windows code pages and lossless failure handling.
[Checkpoint report](CHECKPOINT89_R1_SOURCE_VIEW_ENCODING_2026-10-21.md).
**Verification:** [Linux 620 tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39637089640),
[Windows 77 tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39637089737);
macOS job queued at report update and not yet accepted. Windows/macOS Flutter checks now run
only on a separate, explicitly changed platform-sensitive checkpoint marker;
the routine Linux full-suite gate remains unchanged. Native iOS testing is
still required.

- Audit the **current** unified `SubtitleExtendedEncodingService` and its existing support rather than reimplement outdated CP65 limitations.
- Make raw Source View decode/encode use a shared proven encoding + BOM policy; preserve user edits, newline form, unrepresentable-character errors and selected source encoding without silent fallback. Test UTF-8/16 BOM, Windows code pages, Android SAF and invalid byte sequences.
- Explicit preview/manual override where ambiguous; lossless save/load tests, including non-Latin scripts. Do not change existing saved Isar schema solely to finish encoding.

### CP90 — Editor ownership / mixed UI refactor

**CP90 R1 (October 21, 2026):** Edit Line's large mixed UI/save method has
been reduced to confirmation, feedback and metadata update. The new injectable
`EditLineFileSaveService` prepares strictly validated encoded SRT bytes and
routes existing writes through the shared Source View file-access adapter;
Save As delegates to an isolated platform picker. Original Android document
URIs never silently fall back to synthetic display paths when access is
revoked. Manual Save and navigation autosave permit deliberately blank edited
text, retaining the previous edited value in the checkpoint before-state.
[R1 report](CHECKPOINT90_R1_EDIT_LINE_FILE_SAVE_SERVICE_2026-10-21.md).
**Code-level verification:** [Linux full Flutter suite: 642 tests and clean
analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39648844537),
[Windows and macOS targeted host suites: 111 tests each and clean
analyzers](https://github.com/anzilr/SubtitleStudio/actions/runs/39648844324).
Native Android/iOS/desktop file-provider smoke tests remain outstanding.

**CP90 R2 (October 21, 2026):** The main Editor's direct Save action now
delegates charset-validated SRT compilation and existing-file writes to an
injectable `EditorDirectSaveService`. The service reuses the established
file-access adapter, never substitutes the display path for an authoritative
Android document URI, resolves and releases native macOS security-scoped
bookmarks, and returns a typed result to the Editor. Unsupported encodings
abort without modifying a file; unavailable permissions still invoke the
existing Save As interaction. Legacy path migration remains in the owning
repository only after a successful write. No storage schema, project-history
or mobile layout changes.
[R2 report](CHECKPOINT90_R2_EDITOR_DIRECT_SAVE_SERVICE_2026-10-21.md).
**Automated acceptance:** [Linux full suite, 650 tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39651652550);
[Windows and macOS, 119 targeted tests each / clean analyzers](https://github.com/anzilr/SubtitleStudio/actions/runs/39651652728).
Native file-provider acceptance remains separate.

**CP90 R3 (October 21, 2026):** Save As now prepares an injectable
`EditorExportPlan` containing the requested filename and strictly encoded
SRT bytes before requesting file access. The export sheet receives the latest
Editor/Source View subtitle lines instead of an embedded Isar snapshot;
Android SAF and iOS pickers consume the same bytes. Desktop export validates
local folders and filename segments, blocks accidental overwrites after a
rename collision, and provides a real parent folder rather than pre-filling
the output folder with the source filename or an SAF display hint. Canceling
folder selection no longer crashes the sheet. Existing visuals and project
serialization are unchanged.
[R3 report](CHECKPOINT90_R3_EDITOR_EXPORT_SERVICE_2026-10-21.md).
**Automated verification:** [Linux full suite, 661 tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39654883752);
[Windows and macOS 130 targeted tests each / clean analyzers](https://github.com/anzilr/SubtitleStudio/actions/runs/39654883751).
Native acceptance is separate.

**CP90 R4 (October 21, 2026):** The Editor now carries an explicit secondary
subtitle source (`none`, `originalText` or `external`) instead of guessing from
the first cue's text. The original-text overlay regenerates after primary
subtitle refreshes and local changes even if hidden, while external tracks
remain untouched even if they share the first cue's text. The shared pure
projection preserves blank primary cues, whitespace and line-break semantics;
both Editor secondary-load entrypoints communicate the selected source rather
than inferring it from parsed content. This does not alter the mobile layout,
Isar checkpoint schema or native media player. [R4 report](CHECKPOINT90_R4_SECONDARY_SOURCE_2026-10-21.md).
**Verification:** [Linux 666 Flutter tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39657803545). This is not a
platform file-access change, so Windows/macOS file matrix is not requested.

**CP90 R5 (October 21, 2026):** The main Editor now delegates desktop/mobile
split-ratio debouncing to `EditorResizePreferenceCoordinator`. Riverpod state
reflects drag changes immediately; ordered preference writes preserve the
latest values, and route disposal flushes pending values instead of silently
canceling timers. Failures do not poison later saves. The UI layout and
native media lifecycle are unchanged; Edit Line's separate legacy timers
remain for a scoped follow-up.
[R5 report](CHECKPOINT90_R5_EDITOR_RESIZE_PREFERENCES_2026-10-21.md).
**Verification:** [Linux 671 Flutter tests / clean analyzer](https://github.com/anzilr/SubtitleStudio/actions/runs/39659967724); platform file
matrix not applicable to this UI-preference-only change.

**CP90 R6 (October 21, 2026):** Edit Line now shares the controller-owned
resize preference coordinator. Its previous widget timers canceled pending
desktop/mobile ratio writes during route exit; the scoped Riverpod controller
instead captures a repository writer while active and flushes the latest drag
values on disposal. The UI retains desktop local updates and mobile
no-rebuild dragging; the Edit Line desktop ratio is stored separately from
the main Editor's ratio. Isar-backed controller regression tests verify
immediate state and persisted final values. Two existing analyzer diagnostics
were also removed. No file access, Isar schema or native-media changes.
[R6 report](CHECKPOINT90_R6_EDIT_LINE_RESIZE_PREFERENCES_2026-10-21.md).
**Verification:** [Linux 672 tests / zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39664510820);
Windows/macOS file-host matrix not applicable.


**CP90 R7 (October 22, 2026):** Edit Line manual Save and navigation
autosave now delegate to a shared, injectable `EditLineDraftSaveService`.
It prepares detached before/after cue copies, preserves intentional blank
edited text, original-versus-edit mode, timing, comments, marks and resolution
metadata, and asks the existing Isar/checkpoint transaction to commit.
Rejected writes no longer update the UI's active cue, local collection or
subtitle preview. Session last-edited index bookkeeping is noncritical
after a successful checkpoint. Five service tests and one Isar checkpoint
integration test were added.
[R7 report](CHECKPOINT90_R7_EDIT_LINE_DRAFT_SAVE_2026-10-22.md).
**Verification:** [Linux 678 Flutter tests / zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39807708108).
The Windows/macOS file-host matrix was not triggered because file access,
project format and native media are unchanged.

**CP90 R8 (October 22, 2026):** Repository commits now return the actual
selected cue and complete sorted line order from the atomic Isar/checkpoint
transaction after timing edits and insertion. Edit Line refreshes selection,
in-memory subtitle rows, video projection, and Save-to-file data using that
result. Next/Previous selects the neighbor *after* autosave. Legacy boolean
save interfaces remain unchanged, and identical text/time collision cases
are covered in Isar integration tests.
[R8 report](CHECKPOINT90_R8_CUE_REORDER_SELECTION_2026-10-22.md).
**Verification:** [Linux 682 tests / zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39810301827).

**CP90 R9 (October 22, 2026):** The Edit Line route now uses a
`EditLineNavigationGuard` to serialize relative and jump navigation and
invalidate stale asynchronous cue loads on newer refresh or route disposal.
Jump to Line honors pending autosave and time validation. Cue refresh
reads the requested index instead of the initial route index, preventing
incorrect new-cue placeholders when the project changes. Deferred video
seeks are invalidated with the matching load token. No native media or
persistent-data format changes.
[R9 report](CHECKPOINT90_R9_EDIT_LINE_NAVIGATION_LIFECYCLE_2026-10-22.md).
**Verification:** [Linux 687 tests / zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39812415589).

**CP90 R10 (October 22, 2026):** Edit Line video readiness/selection is now
guarded by explicit request tokens. Pending player-ready seeks, media state
synchronization and picker callbacks are ignored after newer selections,
Unload or route disposal; initial ready-state seeking works even before the
VideoPlayerWidget key attaches. Persisted video path Save/Unload requests
are serialized with a repository captured while Riverpod is active, so a
delayed path Save cannot resurrect a subsequently unloaded video.
[R10 report](CHECKPOINT90_R10_EDIT_LINE_MEDIA_LIFECYCLE_2026-10-22.md).
**Verification:** [Linux 701 Flutter tests / zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39816216928) (combined CP90 R10/R11 gate).

**CP90 R11 (October 22, 2026):** Edit Line shortcut registration and route
teardown use a small asynchronous lifecycle coordinator. A route closed
during the Home-shortcut handoff cannot later install Edit Line shortcuts.
Teardown waits for partial in-flight registration before cleanup; callbacks
also check route ownership before running. Shared parent Editor shortcuts
retain their existing ownership. Six regression tests cover registration
races, disposal, repeated activation and cleanup failures.
[R11 report](CHECKPOINT90_R11_EDIT_LINE_SHORTCUT_LIFECYCLE_2026-10-22.md).
**Verification:** [Linux 701 Flutter tests / zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39816216928) (combined CP90 R10/R11 gate).

**Media stability update (user report, October 22, 2026):** the previously
observed native `media_kit` hot-restart crash no longer occurs on the user's
device. Do not carry it as a currently reproducible blocker. CP93 still
includes ordinary playback/background/navigation smoke tests.

**CP90 R12 (October 22, 2026):** The Edit Line widget and Riverpod
controller now share a detached selected-cue projection after successful
database saves, navigations and new-cue drafting. The projection copies all
committed rows plus the source collection's ID, charset, original locator,
file path and macOS bookmark; intentional blank and multiline edited text
remain distinct. The controller's unsaved-change baseline is reset only
after committed persistence. Previous Riverpod state snapshots aren't mutated
in place. Six new regression tests cover reorder, metadata, blank cues,
new slots and validation state.
[R12 report](CHECKPOINT90_R12_EDIT_LINE_RIVERPOD_SELECTION_2026-10-22.md).
**Verification:** [Linux 707 Flutter tests / zero analyzer issues](https://github.com/anzilr/SubtitleStudio/actions/runs/39818721441).

**CP90 R13 (October 22, 2026):** The controller's legacy boolean
`saveSubtitle()` now delegates to the same transactional draft service
used by manual Save and navigation autosave. It publishes the actual
post-sort cue, preserves intentional blank edits and cue metadata, handles
new-cue insertion, validates timestamp ranges, and avoids no-op checkpoint
creation. Direct controller `navigateToLine()` now blocks dirty draft loss,
reloads the entire committed Isar collection and discards asynchronous
results superseded by a later selection. Six Isar/Riverpod integration
tests cover these paths.
[R13 report](CHECKPOINT90_R13_CONTROLLER_SAVE_NAVIGATION_2026-10-22.md).
**Verification:** Full Linux Flutter analyzer/tests pending.

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

### Production Desktop Workspace Integration / UI [AFTER CP93]
- The presentation shell may be designed and previewed now on the isolated branch. After CP93, connect it to the shared Riverpod, Isar, project, checkpoint, encoding and file-access core without duplicating domain logic.
- PC single-screen workflow: project navigator/history, video + waveform, cue editor/table, tools/sidebar; keyboard shortcuts, resizable panes and platform file dialogs.
- Do not regress mobile UI; desktop layout and window persistence stay platform-responsive.

## Acceptance discipline

- Implement small, independent changes with focused tests and a checkpoint report; do not combine media-native experiments and architecture refactors in one commit.
- Treat a successful analyzer/test run as **code-level** proof only, not Android/Windows native acceptance.
- The waveform experiment can resume later from its isolated branch after a new explicit prioritization.
