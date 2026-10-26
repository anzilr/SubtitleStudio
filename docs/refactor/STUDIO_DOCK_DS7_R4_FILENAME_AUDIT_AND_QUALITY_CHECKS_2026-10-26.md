# SubtitleStudio — DS7 R4: descriptive filenames and additional quality checks

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Dart filename audit

Obsolete planning identifiers were present in **test filenames only**; none
of the production `lib/` Dart paths contained `DS1`, `DS2`, or `CP93`.

| Old test file | Descriptive replacement |
| --- | --- |
| `studio_dock_ds1_test.dart` | `studio_dock_workspace_geometry_test.dart` |
| `studio_dock_ds2_test.dart` | `studio_dock_command_palette_widget_test.dart` |
| `studio_dock_ds2_layout_preferences_test.dart` | `studio_dock_layout_preferences_test.dart` |
| `cp93_project_portability_acceptance_test.dart` | `project_document_portability_acceptance_test.dart` |

The legacy project-portability handoff reference now uses the updated name.
Other files are intentionally named: `subtitle_encoding_preview.dart` does
preview decoding, `studio_skin_preview.dart` displays read-only previews,
`legacy_collection_write_guard.dart` enforces the legacy mutation boundary,
and `tool/studio_dock_demo.dart` is a standalone development harness.
`edit_line_placeholders.dart` / `edit_placeholders.dart` provide actual UI
placeholder widgets.

## Added quality issues

- **Repeated subtitle text**: same nonempty visible caption twice in a row
  when sorted chronologically. Comparison ignores harmless tag/case/whitespace
  differences but preserves punctuation; a repetition can be intentional,
  so the finding is advisory only.
- **Out-of-order timecode**: a later row in the subtitle file starts earlier
  than the preceding valid start. This inspects source order independently of
  overlap/gap detection, which already sorts by chronology.
- Both categories are displayed and filterable in Studio Dock's quality report;
  tapping an issue navigates to the affected cue. No new automated correction
  or history mutation is introduced.

## Verification

- Focused tests cover semantic filenames in the Flutter test discovery glob,
  repeated-text navigation, formatting-insensitive comparisons, invalid/empty
  text guards, source-order warnings, and non-mutating behavior.
- GitHub Actions remains limited to Flutter dependency resolution, analysis,
  and tests. No platform builds.

## Next

- Evaluate conservative line-break and timing proposals in preview mode,
  only enabling Apply when an exact-source, checkpointed rollback path exists.
- Windows visual acceptance pending until the user's laptop is available.
