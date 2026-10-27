# SubtitleStudio — DS7 R19 file and feature parity audit

Date: 2026-10-27  
Scope: mobile editor/home versus **live Studio Dock desktop**. Source-level
inspection plus existing test inventory; **not** a native Windows/Android
acceptance run. This report supersedes the broad “wired” wording for file
operations in `STUDIO_DOCK_DESKTOP_MOBILE_PARITY_MATRIX_2026-10-24.md`.

## Immediate findings and severity

| Priority | Finding | Evidence / required action |
| --- | --- | --- |
| **P0 — source overwrite** | Desktop's import picker accepts `.vtt`, `.ass`, `.ssa` and stores each import's original path as the writable source. `Save subtitle file` subsequently runs an **SRT-only** compiler against that path. Styles, cue settings, and document structure are not preserved, and the original non-SRT source can be overwritten with SRT data. | `studio_dock_desktop_home.dart` `_importFile`; `studio_dock_project_actions.dart` `importFile`; `studio_dock_file_actions.dart` `saveExisting`; `editor_direct_save_service.dart`. **Before shipping**, block direct Save to non-SRT sources and require an explicit SRT conversion/Save As that cannot overwrite the original. Full lossless VTT/ASS/SSA editing stays in the separate future-format roadmap. |
| **P1 — `.msone` import parity** | Mobile previews package details, asks **replace existing** or **import as new**, offers original/existing/new SRT association, and prompts for subtitles-only recovery if history is incompatible. Desktop imports as new automatically using the package's old source path, without preview, replacement, relink or history-recovery choices. | `import_project_sheet.dart`, `session_selection_sheet.dart`, `session_project_import_repository.dart` vs. `studio_dock_project_actions.dart` `_importProject`. Reuse the import-choice service and add the desktop dialogs, with an unchanged-source guarantee on Cancel. |
| **P1 — SRT open/import options** | Mobile provides encoding override and text preview, optional hearing-impaired cleanup, optional overlap merge, and optional `.msone` save during import. Desktop does immediate auto-decoded import after file selection, with none of these pre-import choices. | `subtitle_import_options_sheet.dart`, `subtitle_processor.dart` vs. `studio_dock_project_actions.dart` `importFile`. Shared import plan with desktop-native dialogs recommended. |
| **P1 — save semantics differ** | Desktop **Save As** writes an SRT **and relinks** future Save to the new source. Mobile **Save As** opens the export sheet and **does not relink** the original source. Both are valid operations but the same name has different side effects. | `studio_dock_file_actions.dart` `prepareSaveAs`/`writeToPath`; `screens/edit/parts/edit_project_actions.dart` `_handleSaveFileAs`; `export_file_widget.dart`. Set and document a consistent Save As vs Export contract across platforms. |
| **P2 — video subtitle extraction** | Mobile home exposes “Extract” with video/track processing options; no equivalent action is wired in Studio Dock desktop Home. | `screens/home/parts/home_navigation_actions.dart` `_handleExtract` vs. `studio_dock_desktop_home.dart`. Verify desktop FFmpeg capability, then expose the shared extraction workflow. |

**Important distinction:** `.vtt` and `.ass` import *parsing* exists, but
lossless import/edit/save/export support **does not**. Current project model
stores subtitle lines, not a VTT document's NOTE/STYLE/REGION/cue settings or
ASS/SSA script/styling/events. This is explicitly future work in
`SUBTITLE_FORMAT_EXPANSION_AND_SUBTITLE_EDIT_PARITY_BACKLOG_2026-10-27.md`.
The P0 protective fix should precede any general multi-format rollout.

## Detailed parity ledger

| Workflow/capability | Mobile | Studio Dock desktop | Audit status |
| --- | --- | --- | --- |
| Open existing internal session | Home recent/session list | Explorer/home session catalog; recent project preference | **Wired**, native reopen needed |
| Restore last edited subtitle | Session `lastEditedIndex` | `studio_dock_session_view.dart` `_rememberCue` and `initialSelectedCueId` wired | **Wired**; rapid-close write/native reopen regression test needed |
| Open `.srt` | Dedicated SRT import sheet | Generic native file picker/quick import | **Partial** — desktop skips import options |
| Explicit encoding override / preview at import | Encoding selector + decoded preview | Auto-detect only | **Missing on desktop** |
| Remove HI at import | Toggle before import | Later Tools cleanup available | **Missing on desktop at import** |
| Merge overlaps at import | Toggle before import | No equivalent import toggle found | **Missing on desktop at import** |
| Optionally save project on SRT import | Save project file toggle/path flow | Separate Save Project action *after* import | **Partial** |
| `.vtt` import | Mobile import picker can carry `.vtt`, but `subtitle_processor.dart` calls only `parseSrt` | `parseVtt` maps cues into SRT line model | **Unsafe/incomplete on both**; do not claim editable format support |
| `.ass`/`.ssa` import | Same `parseSrt` mobile processor limitation | `parseAss` maps into SRT line model | **Unsafe/incomplete on both** |
| Import `.msone` preview | Name/line counts, history and metadata summary | No preview | **Missing on desktop** |
| Import `.msone` replace existing | Supported, transactional | Always import as new | **Missing on desktop** |
| Import `.msone` as new | Supported | Supported via `importAsNewSession` | **Wired**, native acceptance |
| Imported SRT association | Existing, archive's own, or newly chosen SRT | Automatically archive's stored source locator | **Missing options on desktop** |
| Incompatible imported history | Confirm subtitles-only fallback | No fallback/UI; exception bubbles as import error | **Missing on desktop** |
| Create subtitles from scratch | Edit Mode, name/encoding and external save locations | Edit Mode, name only; internal unsaved project until Save As | **Partial**; no desktop encoding/location choice |
| Save active SRT to existing source | Explicit save; optional mobile per-line auto-write setting | File > Save; missing location falls back to Save As | **Wired** on SRT, native I/O acceptance |
| Save As SRT | Mobile export dialog (non-relinking) | Native Save As (relinks), explicit overwrite confirmation | **Behavior divergent** |
| Export edited SRT | Name, encoding, custom tag, folder | Native path, source encoding, fixed `MSone` tag | **Partial** — desktop lacks encoding/tag options |
| Export original SRT | Original-only option | Original/Edited choice for Translation Mode | **Wired**, semantics & mode testing |
| Prevent accidental overwrite (Save As/export) | Shared exporter and overwrite dialog | Explicit overwrite dialog + prepared-byte freshness guard | **Wired**, native picker behavior still unverified |
| Save existing `.msone` | Shared ProjectSaveFlow | Shared coordinator + desktop project writer | **Wired**, round-trip/native testing |
| Save `.msone` As | Project path picker | Native picker + explicit overwrite confirm and graph-freshness guard | **Wired**, native round trip needed |
| Project graph/branch/bookmark export | Graph/refs in `.msone` | Uses same coordinator to build archive | **Wired**, covered by service tests |
| Reopen imported project's source | User selects/relinks path during import | May retain stale original machine path | **Risk**, desktop relink needed |
| External SRT Source View | Shared raw editor and apply | Shared Source View tools/checkpoint apply | **Wired**, encoding/round-trip native test |
| Edit vs Translation Mode | Both modes | Mode-aware inspector and controls | **Wired**, native behavior to verify |
| Cue insert/delete/split/merge | Existing editor functions | Shared repository-driven Studio Dock actions | **Wired**, edge cases/native input |
| Text style, color, alignment | Existing controls | Formatting, color, alignment in Studio Dock | **Wired**, native focus/selection |
| Timings, shifts, synchronization | Existing tools | Timing inspector, batch shift and sync | **Wired**, real-media precision |
| Find/replace, selection and bulk actions | Existing menu/sheets | Desktop menu + shortcuts/right-click | **Wired**, focus/undo native QA |
| Mark, comments, resolve, marked-lines | Existing mobile tools | Studio Dock flags, filter, sheet, fullscreen callbacks | **Wired**, collapsed-effect and native QA |
| SRT text effects | Shared effect engine | Three batches, grapheme-safe frames, collapse/filter/restore | **Wired**, playback/native QA |
| History/checkpoints/undo/redo | Existing graph | History panel and shared graph | **Wired**, import/history edge QA |
| Video/secondary subtitles/fullscreen/repeat | Shared player | Shared player linked to desktop workspace | **Wired**, native acceptance |
| Audio waveform/track selection | Existing waveform/player | Studio Dock waveform and controls | **Wired**, performance/native acceptance |
| Video subtitle-track extraction | Home extraction sheet | No wired desktop creation/import entry | **Missing on desktop** |
| Dictionaries/MSone features | Existing editor menus | Shared tools and gated menu callbacks | **Wired**, account/network/native acceptance |
| App/Project Settings, themes, Help | Existing settings/sheets | Reused live surfaces | **Wired**, platform-option relevance review |
| External file associations, SAF/bookmarks | Android SAF, iOS/desktop pickers | Native file picker, macOS bookmark flow on save | **Unverified natively** |

## Existing test evidence, not a native pass

- `test/studio_dock_project_actions_test.dart`: UTF-8/blank SRT import,
  single-cue VTT parser import, empty project creation, invalid import. No
  multi-format round-trip tests or `.msone` desktop import-choice UI tests.
- `test/studio_dock_file_actions_test.dart`: SRT Save As/relink, direct Save,
  export original/edited, overwrite confirmation boundary, stale plans,
  charset rejection, and macOS missing-bookmark handling. Does **not** test
  direct Save after VTT/ASS/SSA import — the critical missing case.
- `test/studio_dock_project_save_actions_test.dart`,
  `test/project_document_portability_acceptance_test.dart`,
  `test/session_project_import_repository_integration_test.dart`: project
  saving and import history behavior at service level, not desktop chooser
  feature parity.
- `test/studio_dock_desktop_startup_test.dart`,
  `test/studio_dock_live_session_widget_test.dart` and other Studio Dock tests
  cover portions of live startup, session and editor functionality. Native
  Windows/Android acceptance remains open.

## Required follow-up and proposed verification

1. **P0 first:** add a format gate at the shared external-Save boundary,
   desktop Save, and any other path that might write SRT bytes to a non-SRT
   source; add regression tests proving that importing VTT/ASS/SSA cannot
   change the original file on Save. Conversion must be explicitly named and
   require a different `.srt` destination.
2. **P1:** build common UI-neutral import plans and use them in both home
   flows; show `.msone` metadata/replace-or-new/source-location/history
   fallback choices on desktop. Add cancel/no-write, replace/undo-graph,
   relink, encoding-preview and cleanup/merge integration/widget tests.
3. **P1:** reconcile Save As and Export semantics, including whether Save As
   relinks; expose output encoding, tag and original/edited policy consistently
   without silently changing existing users' target files.
4. **P2:** expose video subtitle extraction in desktop Home if the platform
   supports the existing workflow; reconcile project-create name/encoding and
   initial file-location options.
5. Native acceptance matrix: Windows open SRT, Cancel import, import `.msone`
   as new/replace with each SRT-path choice, create, Save, Save As, Export
   original/edited, Save/Save As `.msone`, restart/resume last line, missing
   file/revoked path, encoding failure, overwrite confirmation and imported
   history/undo. Repeat relevant SAF cases on Android. Include real VTT,
   ASS and SSA fixtures, but keep their original files read-only until full
   native format support exists.

No platform builds in GitHub Actions; Flutter analysis and tests only.
