# SubtitleStudio Refactor Roadmap v2

Date: 2026-09-28  
Branch: `refactor/riverpod-architecture`  
Audit baseline: `32188ede40d0946532b0c9244cd25836a497dfa5`

## 1. Purpose

This roadmap replaces the earlier mostly file-by-file migration plan with a dependency-first plan.

The refactor has already moved important application state to Riverpod, but the current codebase still contains legacy persistence, duplicated initialization, duplicated platform/file abstractions, and large stateful UI surfaces. Further splitting without first converging these boundaries would move complexity rather than remove it.

The goals are:

1. preserve current behavior and all existing project/subtitle data;
2. make Riverpod the single owner of application/domain state;
3. make repositories/services the only persistence and platform-I/O boundaries;
4. remove duplicate initialization and duplicate implementations;
5. keep high-frequency playback rendering narrow and performant;
6. improve regression coverage before deleting compatibility shims;
7. keep Android, iOS, macOS, Windows, and Linux viable throughout the migration.

The Isar schema redesign remains explicitly out of scope for this roadmap.

---

## 2. Current repository snapshot

At the audit baseline:

- the refactor branch is 433 commits ahead of `development` and 434 ahead of `main`;
- 213 files differ from the integration/release baseline;
- `lib/` contains 238 non-generated Dart files;
- non-generated Dart under `lib/` is approximately 3.29 MB;
- there are 17 committed Dart test files;
- the current CI checkpoint runs analyzer + tests only, intentionally avoiding platform builds during active migration.

Checkpoint 17 is green:

- `flutter analyze`: no issues;
- `flutter test`: passing;
- scoped Riverpod regression tests are passing.

### Largest active code surfaces

Large files are not automatically refactor targets. The risk comes from responsibility count, state ownership, persistence, or high-frequency rebuild behavior.

High-risk large surfaces include:

- `lib/screens/screen_edit.dart` + its `part` files;
- `lib/screens/edit/edit_controller.dart`;
- `lib/screens/screen_edit_line.dart` + its `part` files;
- `lib/screens/edit_line/edit_line_controller.dart`;
- `lib/widgets/subtitle_extract_options_sheet.dart`;
- `lib/services/checkpoint_manager.dart`;
- `lib/database/database_helper.dart`;
- `lib/database/models/preferences_model.dart`;
- `lib/utils/project_manager.dart`;
- `lib/utils/subtitle_processor.dart`;
- video player/fullscreen controls;
- waveform rendering/interactions.

Large but mostly static/data-oriented files such as the help catalog are lower priority.

---

## 3. What is already in good shape

The migration has established several useful architectural islands:

- root Isar dependency injection through `isarProvider`;
- Riverpod controllers for Home, Editor, Edit Line, Source View, Waveform, Theme, and AI explanation;
- repository layers around Home, Editor, Edit Line, Waveform, Theme, AI preferences, and several dictionary flows;
- route-scoped configuration providers for Editor/Edit Line/Source View;
- explicit scoped-provider dependencies after the checkpoint-17 fix;
- subtitle parser regression tests covering SRT/VTT/ASS behavior;
- state tests for Editor range/copy behavior;
- source-view reconciliation tests;
- session sorting/activity tests;
- subtitle timeline indexing tests;
- a compatibility shim for `screens/edit/models/subtitle_entry.dart` that exports the canonical model.

These should be preserved and expanded rather than replaced.

---

## 4. Microscopic audit findings

### P0 — Runtime correctness / duplicate initialization

#### Editor initializes twice

`EditScreenHost` initializes `EditController`, but once the host opens the legacy `EditScreen`, the legacy screen performs another initialization sequence:

- reads subtitle lines again;
- reads the subtitle collection again;
- triggers initial checkpoint creation again;
- synchronizes resize state again;
- runs additional video/subtitle setup.

This creates redundant I/O and makes initialization ownership ambiguous.

#### Edit Line initializes twice

`EditSubtitleScreenHost` initializes `EditLineController`, then the legacy `EditSubtitleScreen.initState` runs `_initializeAsyncData()`, loading preferences and subtitle data again.

This is one of the highest-priority migration defects because it affects correctness, startup latency, and future state consistency.

#### Initialization state inconsistency

`EditState.initial()` sets `isInitialized=false`, but successful `EditController.initialize()` currently creates a replacement state without setting `isInitialized=true`.

The host currently relies mainly on `isLoading`, masking this inconsistency.

---

### P1 — Persistence boundary is only partially migrated

The new controllers generally avoid direct Isar access, but legacy persistence remains concentrated in a few large global/static layers.

#### Global Isar singleton remains

`lib/database/database_instance.dart` exposes:

```dart
late Isar isar;
```

This is still consumed by legacy utilities/services.

#### DatabaseHelper remains a god repository

`lib/database/database_helper.dart` is roughly 893 lines and still owns unrelated responsibilities:

- session CRUD;
- subtitle collection CRUD;
- line add/delete/split/merge;
- mark/comment/resolved state;
- theme/settings;
- dictionary operations;
- destructive app-data cleanup.

New code should not add any dependency on this class.

#### PreferencesModel remains a static god repository

`lib/database/models/preferences_model.dart` is roughly 773 lines and mixes:

- editor preferences;
- edit-line preferences;
- video preferences;
- subtitle rendering preferences;
- AI settings;
- checkpoint settings;
- dictionary settings;
- tutorial state;
- waveform caches and zoom settings;
- session sort settings.

Many feature-specific repositories already wrap portions of it, but several widgets still call `PreferencesModel` directly.

#### CheckpointManager remains static and directly coupled to global Isar

`lib/services/checkpoint_manager.dart` is roughly 1,017 lines and directly performs Isar transactions while also containing checkpoint policy, branching, snapshot/delta algorithms, undo/redo reconstruction, and cleanup.

This should become injected repository + domain service code before further checkpoint feature changes.

#### ProjectManager bypasses the repository boundary

`ProjectManager` still depends on:

- the global Isar instance;
- `CheckpointManager`;
- file picking/writing;
- UI `BuildContext`;
- project JSON serialization;
- session metadata persistence.

It needs separation into serialization, persistence, and UI orchestration.

---

### P1 — Duplicate repository implementation

There are two implementations of the same `VideoRepository` API:

- `lib/screens/edit/repositories/screen_repository.dart`;
- `lib/screens/edit/repositories/video_repository.dart`.

They expose the same 18 repository methods.

The currently used `screen_repository.dart` is the more complete implementation because it additionally handles:

- macOS security-scoped bookmark resolution/storage;
- Android SAF secondary-subtitle reads.

The duplicate must be converged to one canonical `video_repository.dart`.

---

### P1 — UI still owns persistence/processing

Direct persistence or legacy static-service access is still present in UI/operation code, including:

- create subtitle sheet -> `DatabaseHelper`;
- subtitle import/extract -> `subtitle_processor`;
- subtitle operations/banner/sync -> legacy DB/checkpoint paths;
- checkpoint sheet -> `CheckpointManager`;
- project settings -> global Isar / preferences;
- import comments -> direct Isar;
- marked lines / AI explanation / Olam / secondary subtitles -> direct `PreferencesModel`.

The target is UI -> controller -> repository/service, never UI -> Isar/static database helper.

---

### P2 — File/platform abstraction duplication

There are overlapping stacks:

- `file_picker_utils_saf.dart`;
- `file_picker_utils.dart`;
- `platform_file_handler.dart`;
- `saf_file_handler.dart`;
- `platform_check.dart`;
- `startup_permission_manager.dart`;
- direct `dart:io` access in multiple UI files.

The current Home screen explicitly says startup storage permission handling is no longer needed because Android uses SAF, but the old permission infrastructure and dependency remain in the tree.

Target architecture:

- one platform-neutral file service API;
- Android SAF adapter;
- desktop/iOS file adapter;
- macOS bookmark adapter;
- no storage-permission workflow for SAF-based Android operations;
- no file-path/URI guessing in widgets.

---

### P2 — Subtitle parsing/import pipeline duplication

There are several overlapping paths:

- `utils/subtitle_parser.dart`: modern pure parser for SRT/VTT/ASS;
- `utils/srt_parser.dart`: older context/database-coupled SRT parser;
- `utils/subtitle_processor.dart`: parsing + cleanup + metadata + database import;
- `utils/srt_compiler.dart`: output;
- Source View contains additional parsing logic.

This creates inconsistent accepted input and error behavior.

The modern pure `SubtitleParser` should become the canonical parser. Import persistence should be separated from parsing.

---

### P2 — Legacy state mirrors remain after Riverpod migration

The main Editor and Edit Line still keep many local fields that mirror Riverpod state.

Examples include:

- loaded subtitle/collection data;
- video visibility/path;
- resize ratios;
- secondary subtitles;
- edit-line text/time/preferences;
- validation flags.

This means state can be mutated in two places and then manually synchronized.

The next stage is not to move every ephemeral UI variable into Riverpod. The correct split is:

**Riverpod/domain state**
- persisted subtitle data;
- selection/range state;
- loaded video identity;
- persisted preferences;
- save/validation status;
- source-view document state.

**Local widget state**
- focus nodes;
- text editing controllers;
- animation controllers;
- scroll controllers;
- hover state;
- temporary drag state;
- high-frequency player paint state.

---

### P2 — Waveform still carries BLoC-style event indirection

The waveform is now backed by a Riverpod `Notifier`, but it still exposes a large `dispatch(WaveformEvent)` API and an event hierarchy.

This is not incorrect, but it preserves BLoC ceremony without BLoC benefits.

Do not rewrite this immediately. First stabilize the Editor state boundary; then replace events with explicit controller methods incrementally.

---

### P2 — Excessive diagnostic printing

High-volume debug output remains concentrated in:

- `ffmpeg_helper.dart`;
- subtitle extraction;
- fullscreen/video controls;
- hotkey manager;
- intent/SAF/file handlers;
- project settings;
- Editor responsive layout.

Some logging is useful, but raw `print`/large stack traces in hot paths make performance investigation harder and can leak file-system details into logs.

Use structured `AppLogger` calls with debug-level suppression and safe metadata.

---

### P3 — Test coverage does not match persistence risk

Current tests are useful but mostly pure-state/parser tests.

Missing high-value coverage includes:

- subtitle import -> persisted Session + SubtitleCollection;
- import via content/SAF metadata;
- Editor controller repository initialization;
- Edit Line controller persistence/navigation;
- checkpoint create/undo/redo/branch cleanup;
- project .msone serialize/import round-trip;
- project compatibility versions;
- preference repository read/write;
- video repository path/secondary subtitle behavior;
- Source View scoped-provider regression;
- Home -> import -> Editor widget navigation;
- failure/recovery paths for missing/corrupt files.

The persistence layers should not be aggressively refactored until these tests exist.

---

### P3 — Platform/build debt

#### Android

Current Android build is functional, but Flutter warns that these versions will soon be unsupported:

- Gradle 8.14;
- AGP 8.13.0;
- Kotlin 2.2.20.

NDK has already been aligned to 28.2.13676358.

Do not perform the Gradle/AGP/Kotlin major upgrade during active state/persistence refactoring. Schedule it as an isolated platform change with a dedicated build gate.

Development/profile builds also currently share the production application ID. This caused signature mismatch/uninstall behavior during device testing. Add a development application ID suffix in the platform-hardening phase.

#### macOS

The Podfile declares:

- `platform :osx, '11.0'`

but then forces every pod target to:

- `MACOSX_DEPLOYMENT_TARGET = '10.14'`.

This contradiction must be resolved before the final cross-platform gate.

#### Windows

The project simultaneously enables `/EHsc` and defines `_HAS_EXCEPTIONS=0`. This deserves an isolated Windows build review.

#### Android release shrinking

The ProGuard file includes several extremely broad keep rules, including broad Flutter and public-static-method preservation. These may significantly reduce the benefit of R8/shrinking. Do not tighten these rules until a release build smoke test exists.

---

## 5. New ordered roadmap

### Phase 0 — Stability baseline

Status: **in progress / mostly complete**

- [x] Analyzer clean.
- [x] Tests green.
- [x] Fix AppLogger startup regex crash.
- [x] Make logger formatting failure non-fatal.
- [x] Fix route-scoped Riverpod dependencies.
- [x] Add Editor/Edit Line nested-scope regression tests.
- [x] Align Android NDK with JNI requirement.
- [ ] Add Source View nested-scope regression test.
- [ ] Confirm Android: launch -> import SRT -> Editor.
- [ ] Confirm Android: open recent session -> Editor.
- [ ] Confirm Android: Editor -> Edit Line -> back.
- [ ] Confirm Windows smoke build/run at next deliberate local checkpoint.

Exit criterion: no known navigation/startup blocker.

---

### Phase 1 — Single initialization/state ownership

Priority: **P0**

#### Main Editor

- [ ] Mark successful `EditController.initialize()` state as initialized.
- [ ] Stop legacy `EditScreen` from re-fetching subtitle lines/collection.
- [ ] Stop duplicate initial-checkpoint creation.
- [ ] Hydrate the compatibility UI from already-loaded Riverpod state.
- [ ] Replace the Editor `FutureBuilder` bootstrap with controller state.
- [ ] Remove initialization-only compatibility methods once unused.
- [ ] Keep scroll/focus/player handles local.

#### Edit Line

- [ ] Stop legacy `EditSubtitleScreen` from reloading subtitle + preferences after `EditLineController.initialize()`.
- [ ] Hydrate text/time controllers once from Riverpod state.
- [ ] Remove duplicated validation/preference mirrors incrementally.
- [ ] Make save/navigation read controller state rather than stale local copies.

Exit criterion: each route performs one persistence initialization pass.

---

### Phase 2 — Persistence convergence

Priority: **P0/P1**

- [ ] Canonicalize the duplicate `VideoRepository`.
- [ ] Introduce injected checkpoint repository.
- [ ] Split checkpoint storage from checkpoint reconstruction policy.
- [ ] Route Editor/Edit Line/operations through checkpoint repository/service.
- [ ] Introduce import persistence repository/service.
- [ ] Remove new usage of `DatabaseHelper`.
- [ ] Migrate existing `DatabaseHelper` consumers by domain.
- [ ] Replace direct `PreferencesModel` calls with feature repositories.
- [ ] Remove direct global `isar` access outside bootstrap/repositories.
- [ ] Eventually remove `database_instance.dart` global access.

Exit criterion: widgets/controllers do not import Isar, `DatabaseHelper`, or `PreferencesModel`.

---

### Phase 3 — Parser and import pipeline

Priority: **P1**

- [ ] Make pure `SubtitleParser` canonical.
- [ ] Add explicit encoding decoder service.
- [ ] Separate parse/normalize from persistence.
- [ ] Make import return a typed result instead of `Map`.
- [ ] Move hearing-impaired cleanup/overlap merge into composable transforms.
- [ ] Reuse canonical parser in Source View where appropriate.
- [ ] Remove legacy `utils/srt_parser.dart` after usage is eliminated.
- [ ] Reduce `subtitle_processor.dart` to orchestration, then replace it.

Exit criterion: one parsing implementation per subtitle format.

---

### Phase 4 — File and platform I/O convergence

Priority: **P1**

- [ ] Define one file-service contract and typed file reference.
- [ ] Preserve both display path and durable URI/bookmark where needed.
- [ ] Migrate subtitle import/export.
- [ ] Migrate video selection.
- [ ] Migrate project save/import.
- [ ] Migrate secondary subtitles/comments/dictionaries.
- [ ] Remove obsolete `file_picker_utils.dart`.
- [ ] Remove obsolete storage-permission startup flow when usage scan is clean.
- [ ] Remove direct file-system work from UI widgets.

Exit criterion: widgets never decide SAF vs path vs bookmark themselves.

---

### Phase 5 — Project/checkpoint reliability

Priority: **P1**

Before structural changes, add:

- [ ] checkpoint initial snapshot test;
- [ ] edit/delete/add undo/redo tests;
- [ ] branch-after-undo test;
- [ ] cleanup/max-checkpoint tests;
- [ ] .msone export/import round-trip test;
- [ ] selected-session/checkpoint restoration tests;
- [ ] version compatibility tests.

Then:

- [ ] split `ProjectManager` into serializer, repository, and UI coordinator;
- [ ] remove `BuildContext` from project domain/persistence code;
- [ ] make project writes atomic where platform APIs allow it.

---

### Phase 6 — Feature-sheet decomposition

Priority: **P2**

Refactor by responsibility, not arbitrary line count.

Order:

1. subtitle extraction;
2. marked lines;
3. subtitle effects;
4. Malayalam normalization;
5. search/replace + sync;
6. dictionaries;
7. checkpoint UI;
8. project settings;
9. AI explanation;
10. MSone submission.

For each feature:

- controller/state for domain/async state;
- service/repository for I/O;
- small widgets for presentation;
- no database/file calls from build methods or button handlers.

---

### Phase 7 — Editor and player performance

Priority: **P1/P2**

- [ ] Remove remaining mutable subtitle-list mutations in widgets.
- [ ] Use Riverpod `.select` at narrow rebuild boundaries.
- [ ] Avoid rebuilding editor chrome on playback-position updates.
- [ ] Keep playhead position in player/waveform-specific listenables.
- [ ] Remove debug stack traces from active-subtitle callbacks.
- [ ] Audit video stream subscriptions for duplicate listeners.
- [ ] Consolidate subtitle timeline indexing.
- [ ] Remove refresh-from-database callbacks where controller mutations already update state.
- [ ] Profile large subtitle documents and long videos.

Waveform follow-up:

- [ ] replace event-dispatch API with explicit Notifier methods incrementally;
- [ ] keep painter/playhead data outside broad app-state rebuilds.

---

### Phase 8 — Logging, privacy, and diagnostics

Priority: **P2**

- [ ] Replace high-volume raw `print` calls with structured logger methods.
- [ ] Keep file paths redacted where practical.
- [ ] Avoid logging subtitle content unless explicitly requested in debug tooling.
- [ ] Add operation IDs/context to import/export/FFmpeg failures.
- [ ] Keep logging non-fatal by construction.
- [ ] Add a lightweight performance timing helper around import, Editor initialization, waveform generation, and project restore.

---

### Phase 9 — Platform modernization

Priority: **P2 after architecture stabilization**

Android:
- [ ] isolate debug/profile application ID from production;
- [ ] upgrade Gradle/AGP/Kotlin together in a dedicated change;
- [ ] review R8 rules with release smoke build;
- [ ] validate media_kit/FFmpeg native packaging.

Windows:
- [ ] resolve exception-flag contradiction;
- [ ] smoke test media/hotkeys/file I/O.

Linux:
- [ ] smoke build/run;
- [ ] validate hotkey-manager override.

macOS:
- [ ] resolve deployment-target mismatch;
- [ ] validate bookmarks/file access/media.

iOS:
- [ ] build gate;
- [ ] file save/import test;
- [ ] media playback test.

---

### Phase 10 — Dead-code and compatibility cleanup

Only after usage scans + tests:

- [ ] remove duplicate `screen_repository.dart` after canonical VideoRepository migration;
- [ ] remove compatibility export paths no longer imported;
- [ ] remove obsolete permission/file-picker utilities;
- [ ] evaluate/remove `banner_configuration_sheet_new.dart` if unused;
- [ ] remove old parser/import paths;
- [ ] remove stale comments mentioning BLoC/Cubit/SharedPreferences where behavior changed;
- [ ] normalize file/folder naming.

---

### Phase 11 — Integration gate

- [ ] `flutter analyze` with warnings treated deliberately;
- [ ] full unit/widget regression suite;
- [ ] Android build + smoke;
- [ ] Windows build + smoke;
- [ ] Linux build;
- [ ] macOS build;
- [ ] iOS build;
- [ ] import/export/project/checkpoint compatibility test with real files;
- [ ] large subtitle performance test;
- [ ] final diff review for schema/assets/platform permissions;
- [ ] PR from refactor branch to upstream integration branch.

---

## 6. Required regression suites to add

### Import pipeline
- SRT UTF-8;
- BOM;
- Latin-1/Windows-1252;
- malformed cue recovery;
- VTT;
- ASS/SSA;
- SAF metadata persistence;
- empty file;
- duplicate/invalid indexes;
- overlap merge;
- hearing-impaired cleanup.

### Repository integrity
- create/delete session;
- add/edit/delete/split/merge line;
- mark/comment/resolved;
- selected batch deletion;
- preference round-trips;
- video preference round-trips.

### Navigation/state
- Home -> import -> Editor;
- Home -> recent -> Editor;
- Editor -> Edit Line -> Editor;
- route-scoped provider isolation for two simultaneous/nested configurations;
- navigation disposal during async work.

### Project/checkpoint
- snapshot + delta;
- undo/redo;
- branching;
- max-checkpoint cleanup;
- project round-trip;
- corrupt project rejection;
- old project compatibility.

---

## 7. Refactor rules from this point forward

1. No Isar schema redesign on this branch phase.
2. No new direct global `isar` access.
3. No new direct `DatabaseHelper` or `PreferencesModel` usage.
4. UI must not gain new persistence/file-system logic.
5. One responsibility per structural commit.
6. Move/rename separately from behavior changes when practical.
7. Keep Android/iOS/macOS/Windows/Linux code paths intact.
8. Do not upgrade Gradle/AGP/Kotlin in the same commits as Riverpod/persistence work.
9. Run GitHub Actions only at deliberate checkpoints, roughly every 10 commits or after a major milestone.
10. Prefer typed result objects over loosely typed `Map<String, dynamic>` at new boundaries.
11. Prefer immutable state and repository-owned transactions.
12. Do not put high-frequency playhead updates into broad application providers.
13. Delete compatibility shims only after usage scan + tests.
14. Every bug discovered during device testing should receive a regression test when practical.

---

## 8. Immediate execution order

The next commits should be:

1. **Editor initialization ownership**
   - set `isInitialized=true`;
   - hydrate legacy Editor from Riverpod state;
   - remove duplicate line/collection/checkpoint initialization.

2. **Edit Line initialization ownership**
   - hydrate controllers/local UI from Riverpod-loaded state;
   - remove duplicate persistence loads.

3. **Canonical VideoRepository**
   - retain SAF + macOS bookmark behavior;
   - update imports;
   - delete duplicate implementation.

4. **Source View scope regression test**.

5. **Checkpoint repository seam**
   - introduce injected persistence without changing checkpoint algorithm.

6. **Import persistence seam**
   - begin removing `DatabaseHelper` from `subtitle_processor.dart`.

This order improves correctness and performance first, then removes legacy architecture beneath the UI.
