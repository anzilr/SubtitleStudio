# SubtitleStudio — DS5 R13 Import Comments

Date: 2026-10-24
Branch: `feature/studio-dock-integration`

## Intent

Expose the existing mobile **Import Comments** feature in the sole desktop
Studio Dock UI without changing what it imports, the accepted file format or
the shared checkpoint transaction.

## Behavior

- Tools menu and Tools panel offer **Import Comments (.msone)** only for live,
  editable sessions with subtitle cues. The command waits for the Tools popup
  to fully dismiss before starting the next dialog/file picker.
- All entry points use the existing unsaved subtitle/Source View draft gate.
  Cancel leaves the draft in place and never launches an importer.
- The live session hosts the existing `ImportCommentsSheet` in a bounded
  desktop dialog. The sheet still opens `.msone` project files, decodes with
  `ProjectDocumentCodec`, previews available annotations, and invokes
  `ProjectCommentRepository.importComments`.
- Import matches destination cues by **1-based cue index**, just as on mobile.
  It imports comment, marked and resolved metadata; original/edited text and
  start/end timing remain untouched. The repository makes one undoable V2
  checkpoint for changed metadata. No import is reported on Cancel.
- After a successful import, the host reloads the authoritative collection,
  restores the surviving desktop selection and supplies a complete cue update
  to Studio Dock. This refreshes marked/review filters and checkpoint history
  without remounting the video player or replacing the native workspace.
- The established MSone submission feature is unrelated and untouched.

## Automated acceptance

- Desktop widget coverage: capability gating; Tools popup lifetime and Back;
  unsaved-draft Cancel/Discard; Tools panel shortcut; empty session behavior.
- Existing `project_comment_import_test.dart` and
  `project_comment_repository_integration_test.dart` cover source plan
  extraction, index matching, field preservation, live-collection writes,
  foreign/ambiguous session rejection and
  undo/redo transaction behavior.
- Flutter dependency resolution, analyzer, focused Studio Dock and full
  Flutter suites on GitHub Actions, with **no platform builds**.

## Deferred native acceptance

Windows desktop acceptance will include real `.msone` selection and Cancel,
large imports, matched/unmatched line counts, Undo/Redo, marks/resolved filters,
Unicode comments and route/focus behavior. No MSone submission to production
is required or performed for this checkpoint.
