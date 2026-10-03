# SubtitleStudio Refactor Roadmap v4

Date: 2026-10-03
Branch: `refactor/riverpod-architecture`
Original audit head: `cff387f69257e37bb3b6ef26111b2683a57bf510`
Current verified checkpoint: `04a1d2b9b03522519fa2dce1f5c9439e87bd5a59` (checkpoint 43)
Current verification: `flutter analyze` = 0 issues; `flutter test -j 1` = 136 passed
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
- Exported checkpoint IDs are preserved and remapped to fresh Isar IDs during project import.
- Checkpoint 43 is green with zero analyzer issues and 136 passing tests.

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
