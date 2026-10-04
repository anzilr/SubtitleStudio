# SubtitleStudio Refactor Roadmap v3

Date: 2026-09-28
Branch: `refactor/riverpod-architecture`
Audit baseline: `a9892e258f18dbf30a60809f93b4176a9af90995`

## 1. Why v3 exists

Roadmap v2 correctly changed the migration from file-by-file cleanup to dependency-first refactoring. Since then, several of its highest-risk items have been completed:

- Editor initialization is controller-owned.
- Edit Line initialization is controller-owned.
- route-scoped Riverpod dependencies are explicit and regression-tested.
- Source View route scope has regression coverage.
- VideoRepository is canonical; the old screen repository is now a compatibility shim.
- migrated Editor/Edit Line repositories use an injected checkpoint boundary.
- analyzer/tests were green at checkpoint 18.

The current problem is therefore no longer mainly state-management replacement. The next stage is **boundary completion**: removing static/global persistence and platform I/O from UI/orchestration code, adding regression coverage around persistence-heavy features, then simplifying very large UI surfaces.

The Isar schema redesign remains out of scope.

---

## 2. Current codebase snapshot

At this baseline the repository contains:

- 404 tracked files;
- 257 Dart files including generated code;
- 17 committed Dart test files;
- a generated Isar model file of roughly 479 KB;
- multiple active non-generated Dart files above 40–60 KB.

Largest active non-generated surfaces include:

- `lib/screens/msone_submission_screen.dart` ~60 KB;
- `lib/widgets/subtitle_effects_sheet.dart` ~58 KB;
- `lib/widgets/subtitle_extract_options_sheet.dart` ~55 KB;
- `lib/widgets/marked_lines_sheet.dart` ~53 KB;
- `lib/widgets/malayalam_normalization_sheet.dart` ~53 KB;
- `lib/screens/edit_line/parts/edit_line_layout.dart` ~52 KB;
- video settings/fullscreen controls ~45–46 KB each;
- `lib/utils/ffmpeg_helper.dart` ~45 KB;
- `lib/widgets/checkpoint_sheet.dart` ~43 KB;
- search/AI/sync/dictionary sheets ~40 KB each;
- `lib/services/checkpoint_manager.dart` ~38 KB;
- `lib/screens/edit/edit_controller.dart` ~33 KB;
- `lib/screens/screen_edit.dart` ~33 KB;
- `lib/database/database_helper.dart` ~32 KB;
- `lib/screens/edit_line/repositories/edit_line_repository.dart` ~30 KB;
- `lib/utils/subtitle_processor.dart` ~28 KB;
- `lib/utils/app_logger.dart` ~28 KB.

File size alone is not the priority signal. Responsibility mixing, global state, platform branching, persistence ownership, and rebuild frequency are the priority signals.

---

## 3. Microscopic findings at current head

### P0 — Checkpoint boundary exists but is not complete

`CheckpointRepository` currently wraps only:

- initial snapshot creation;
- edit checkpoint creation;
- generic checkpoint creation.

It still delegates to static `CheckpointManager`, which still owns persistence and policy together.

Direct `CheckpointManager` calls remain in UI/orchestration code. `checkpoint_sheet.dart` directly loads history, restores checkpoints, creates manual checkpoints, and creates snapshots through the static manager.

Immediate target:

- expand the injectable checkpoint boundary to cover UI-required operations;
- migrate checkpoint UI to Riverpod/injected repository;
- only then split `CheckpointManager` into storage and reconstruction/policy layers.

### P0 — ProjectManager is still a cross-layer god service

`ProjectManager` currently mixes:

- JSON serialization/versioning;
- checkpoint serialization;
- direct global Isar access;
- Android SAF;
- iOS file picker;
- desktop file writes;
- UI snackbars/dialogs via `BuildContext`;
- session project-path persistence;
- project import UI coordination.

This prevents reliable project round-trip testing and keeps platform/UI details inside persistence logic.

Target split:

1. `ProjectDocumentCodec` — typed encode/decode/version validation;
2. `ProjectRepository` — session/checkpoint persistence;
3. `ProjectFileService` — SAF/path/bookmark read/write;
4. UI coordinator/widget — dialogs/snackbars/navigation only.

### P0 — Subtitle import is still map- and context-driven

`subtitle_processor.dart` is ~772 lines and still exposes nullable `Map` results while mixing:

- encoding read/detection;
- SRT parsing;
- cleanup transforms;
- overlap merge;
- database import orchestration;
- context-aware and context-free duplicate entry points.

A canonical pure parser already exists elsewhere. New work must move toward typed import results and one parse pipeline.

### P1 — Persistence migration is incomplete

Good injected repositories now exist for major migrated screens, but legacy static/global persistence remains.

Important remaining concentrations:

- `database_helper.dart`: broad legacy CRUD/domain helper;
- `preferences_model.dart`: ~773-line static preference surface with direct Isar access;
- `checkpoint_manager.dart`: static global checkpoint persistence/policy;
- `project_manager.dart`: direct global Isar + checkpoint manager;
- project settings / comments / marked-lines UI still use legacy persistence/static preferences.

Rule from this point: **no new UI-to-Isar, UI-to-DatabaseHelper, UI-to-PreferencesModel, or UI-to-CheckpointManager dependency.**

### P1 — EditLineRepository remains too broad

`EditLineRepository` is ~958 lines and currently owns:

- subtitle-line persistence;
- collection persistence;
- mark/comment/resolved operations;
- subtitle generation;
- preferences loading/saving;
- video-path preference operations;
- color history;
- SRT export/write behavior.

This is a repository boundary, so it is safer than UI persistence, but it is still too many domains.

Target decomposition after regression coverage:

- `EditLineRepository` — subtitle/collection mutations;
- `EditLinePreferencesRepository` — preferences;
- canonical `VideoRepository` — video identity/path;
- export/file service — file writes.

### P1 — SubtitleRepository still combines persistence and transformations

`SubtitleRepository` is ~634 lines and combines:

- Isar persistence;
- line mutation;
- session metadata;
- source-view conversion/sync;
- checkpoint coordination;
- subtitle rendering model generation.

It should eventually keep persistence-facing operations while pure conversion/generation moves to stateless services.

Do not split this aggressively until Editor repository tests exist.

### P1 — High-risk UI files still contain domain state

Examples from current inspection:

- `checkpoint_sheet.dart`: ~1,107 lines and direct static checkpoint calls;
- `marked_lines_sheet.dart`: ~1,385 lines, many local `setState` mutations, direct preference access;
- `project_settings_sheet.dart`: direct Isar + `PreferencesModel`;
- `import_comments_sheet.dart`: direct Isar/file I/O;
- extraction/import sheets: platform/file orchestration remains mixed with presentation.

These should be converted feature-by-feature, not split merely by line count.

### P1 — File/platform decisions remain distributed

Android SAF, iOS picker, desktop paths, macOS security-scoped behavior, and raw `dart:io` still appear across multiple utilities and UI flows.

The canonical file abstraction must preserve two distinct concepts:

- **display identity**: name/path shown to the user;
- **durable access identity**: SAF URI / bookmark / platform token needed to reopen it.

A plain string path is insufficient across all platforms.

### P1 — Testing is still light relative to persistence risk

Current 17 test files cover useful parser/state/model logic and route scoping, but the highest-risk persistence paths still lack direct regression coverage.

Highest priority tests:

- checkpoint snapshot/delta/restore/branching;
- project document round trip/version rejection;
- import -> Session + SubtitleCollection persistence;
- Editor repository mutations;
- Edit Line repository mutations;
- preferences round trips;
- file identity/SAF metadata preservation;
- Home -> import -> Editor widget navigation;
- async disposal while import/editor initialization is active.

### P2 — Static preferences remain an architecture choke point

`PreferencesModel` still contains many unrelated preference domains. Existing feature repositories should absorb callers before the static model is dismantled.

Migration order:

1. project settings;
2. marked lines;
3. AI/dictionary settings;
4. remaining Editor/Edit Line preferences;
5. tutorial/settings leftovers.

### P2 — Logging is safer but still noisy

The startup logger failure is fixed and formatting is non-fatal, but high-volume raw diagnostics remain in platform/FFmpeg/UI paths.

Target:

- structured debug logs;
- no subtitle text logging by default;
- redact paths/URIs where useful;
- operation IDs for import/export/project/FFmpeg tasks;
- timing instrumentation around startup, import, Editor initialization, waveform generation, and project restore.

### P2 — Player/waveform architecture should remain performance-first

Do not move every playback value into Riverpod.

Keep high-frequency values in narrow streams/listenables/controllers. Riverpod should own durable/semantic state such as selected media identity, layout choice, subtitle document state, and persisted preferences.

Waveform's BLoC-style event hierarchy can be removed later by adding explicit Notifier methods incrementally.

### P3 — Platform modernization remains deliberately isolated

Do not mix platform toolchain upgrades with persistence/state refactors.

Android:
- isolate dev/profile application ID from production;
- later upgrade Gradle/AGP/Kotlin together;
- validate native media packaging/R8 in a dedicated build gate.

macOS:
- reconcile deployment target settings;
- validate bookmarks/media/file writes.

Windows:
- review compiler exception flags;
- validate hotkeys/media/file writes.

Linux/iOS:
- deliberate smoke/build gates before integration.

---

## 4. Revised execution roadmap

### Phase A — Boundary completion (now)

1. Expand `CheckpointRepository` to cover history/read/restore/manual checkpoint calls.
2. Migrate `CheckpointSheet` from static `CheckpointManager` to injected Riverpod repository.
3. Migrate project checkpoint reads through the same boundary.
4. Add checkpoint repository/algorithm regression tests.
5. Introduce typed project document codec.
6. Separate ProjectManager UI from serialization/persistence.
7. Introduce typed subtitle import result.
8. Route import persistence through an injected repository/service.

Exit criterion: migrated UI has no direct static checkpoint/project/database calls.

### Phase B — Persistence consolidation

1. Migrate project settings off global Isar/`PreferencesModel`.
2. Migrate import-comments persistence.
3. Migrate marked-lines preference access.
4. Move remaining `DatabaseHelper` consumers behind feature repositories.
5. Move remaining global `isar` consumers behind providers/repositories.
6. Split `PreferencesModel` by domain only after callers have moved.
7. Remove global database access when usage reaches zero.

Exit criterion: only bootstrap/repositories know Isar.

### Phase C — Canonical import/parser pipeline

1. Define `SubtitleImportRequest` and `SubtitleImportResult`.
2. Define encoding decoder service.
3. Use canonical pure `SubtitleParser`.
4. Make cleanup/merge transforms pure composable functions.
5. Separate persistence from parse/transform.
6. Route file metadata/SAF identity explicitly.
7. Remove duplicate context-aware/context-free import functions.
8. retire legacy SRT parser/processor paths after usage scan.

Exit criterion: one parser path per format and no loosely typed import maps at new boundaries.

### Phase D — Feature decomposition

Order by responsibility/risk:

1. checkpoint UI;
2. subtitle extraction;
3. project settings;
4. marked lines;
5. import comments;
6. subtitle effects;
7. Malayalam normalization;
8. search/replace + sync;
9. dictionaries;
10. AI explanation;
11. MSone submission.

Each feature should have:

- typed state;
- controller/coordinator for async/domain flow;
- repository/service for I/O;
- presentation-only widgets;
- regression coverage before removing compatibility code.

### Phase E — Editor repository simplification

After tests exist:

1. move pure subtitle rendering conversion out of `SubtitleRepository`;
2. move source-view conversion/reconciliation to a dedicated service;
3. narrow EditLineRepository to subtitle mutation;
4. reuse canonical video/preferences/export services;
5. remove refresh-from-DB calls where successful repository mutations already return enough data to update state.

### Phase F — Performance pass

Measure before changing:

- app startup;
- Home sessions load;
- import parse + persistence;
- Editor initialization;
- opening Edit Line;
- waveform generation;
- checkpoint restore;
- project import/restore;
- scrolling a large subtitle file.

Then:

- narrow Riverpod `.select` boundaries;
- remove duplicate stream/listener registration;
- remove unnecessary database refreshes;
- keep player/playhead updates out of broad app state;
- replace fixed timing delays with completion/readiness signals.

### Phase G — Logging/privacy/diagnostics

- remove raw noisy printing from hot paths;
- structured error categories;
- operation IDs;
- safe path/URI metadata;
- performance timing;
- user-exportable diagnostics without subtitle-content leakage.

### Phase H — Dead-code cleanup

Only after usage scans/tests:

- compatibility repository export shim;
- obsolete file-picker/permission utilities;
- old parser/import functions;
- unused duplicate/new-suffixed widgets;
- stale BLoC/Cubit comments/types;
- global database singleton.

### Phase I — Platform modernization

Separate commits and dedicated build gates:

- Android dev applicationId suffix;
- Gradle/AGP/Kotlin upgrade;
- Android release shrink/native media test;
- Windows flags/build;
- Linux build;
- macOS deployment target/bookmarks/media;
- iOS build/file/media.

### Phase J — Integration gate

Required before PR:

- analyzer clean;
- all unit/widget tests green;
- repository/checkpoint/project/import regression suites;
- Android smoke;
- Windows smoke;
- Linux build;
- macOS build;
- iOS build;
- real SRT/VTT/ASS import/export tests;
- .msone old/current project compatibility;
- large subtitle performance run;
- final schema/platform-permission diff review.

---

## 5. New mandatory regression suites

### Checkpoints
- initial snapshot idempotency;
- edit/add/delete deltas;
- forced snapshot;
- restore exact target state;
- undo then new edit removes future branch;
- max-checkpoint cleanup;
- malformed/missing checkpoint handling.

### Project documents
- current-version encode/decode round trip;
- comments/resolved/marks preserved;
- checkpoints preserved;
- unknown future version rejected safely;
- malformed JSON rejected safely;
- legacy version fixture compatibility;
- project path update persistence.

### Import
- UTF-8/BOM;
- Windows-1252/Latin-1 fallback;
- SRT/VTT/ASS/SSA;
- malformed cue recovery;
- empty file;
- hearing-impaired cleanup;
- overlap merge;
- SAF URI identity;
- import persistence rollback/failure behavior.

### Repositories
- Editor add/edit/delete/batch-delete;
- comments/marks/resolved;
- last-edited index/session;
- Edit Line save/new/delete;
- preferences;
- video path + secondary subtitle identity.

### Navigation
- Home -> import -> Editor;
- recent session -> Editor;
- Editor -> Edit Line -> back;
- two independently scoped Editor configs;
- route disposal during async initialize/import.

---

## 6. Refactor invariants

1. No Isar schema redesign in this phase.
2. No new global Isar access.
3. No new UI dependency on `DatabaseHelper`, `PreferencesModel`, `CheckpointManager`, or `ProjectManager` persistence internals.
4. UI does not choose SAF vs desktop path vs bookmark.
5. New cross-layer results are typed, not `Map<String, dynamic>`.
6. Pure parsing/transforms stay free of `BuildContext`.
7. High-frequency playback state stays narrowly scoped.
8. One structural responsibility per commit.
9. Behavior fixes get regression tests where practical.
10. CI runs only at deliberate checkpoints, not every commit.
11. Compatibility shims are removed only after a usage scan and tests.
12. Platform toolchain upgrades remain isolated from architecture changes.

---

## 7. Immediate commit sequence from this baseline

1. expand checkpoint repository API for history/restore/manual operations;
2. migrate CheckpointSheet to Riverpod repository injection;
3. migrate project checkpoint reads to the checkpoint boundary;
4. add checkpoint algorithm/repository tests;
5. introduce project document codec + typed model;
6. split project file I/O from UI orchestration;
7. introduce typed subtitle import result;
8. add import persistence seam;
9. migrate one direct-preferences UI feature (project settings first);
10. run the next analyzer/test checkpoint.

This sequence removes cross-layer coupling before another large round of UI splitting.
