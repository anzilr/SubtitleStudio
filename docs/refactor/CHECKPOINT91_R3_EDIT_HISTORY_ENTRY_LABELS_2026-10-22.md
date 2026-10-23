# SubtitleStudio — CP91 R3: Friendly edit-history entry labels

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## User-facing issue

CP91 R2 simplified history controls and dialogs, but the actual edit
events still exposed raw technical descriptions in both history
presentations: "Edited line 17", "Added line at position 2",
"Merged lines 6 and 7", "Updated comment on line 3", and the
uppercase technical chips "SNAPSHOT" and "MANUAL".

## Changes

A shared, pure, display-only formatter,
`CheckpointHistoryLabels.entryTitle`, interprets known
machine-generated events using both their operation type and exact
description pattern. It converts them to familiar subtitle-editor
language without altering their stored descriptions or operation IDs:

| Stored event description | Displayed label |
| --- | --- |
| `Initial state` | Project started |
| `Edited line 17` | Edited subtitle 17 |
| `Added line at position 2` | Added subtitle 2 |
| `Deleted line 4` | Deleted subtitle 4 |
| `Split line 12` | Split subtitle 12 into two |
| `Merged lines 6 and 7` | Combined subtitles 6 and 7 |
| `Marked line 8` | Marked subtitle 8 for review |
| `Unmarked line 8` | Removed review mark from subtitle 8 |
| `Updated comment on line 3` | Updated note on subtitle 3 |
| `Updated resolution of line 3` | Updated review status of subtitle 3 |
| `Captured external subtitle changes` | Saved changes made outside the editor |
| `Snapshot` (default snapshot name) | Saved project version |

The formatter also handles legacy edit-tagged annotations and empty
older descriptions. Any custom manual save-point name is displayed
exactly as entered, even if it resembles an automatic event. Unknown
imported descriptions are left intact rather than guessed.

Both `CheckpointHistoryPanel` (visual history) and the classic
`CheckpointSheet` now use that same formatter, including the
classic restoration dialog. The classic snapshot/manual badges are
labeled "Saved version" and "Save point"; "Snapshot" action becomes
"Save Version"; restoration dialogs and snapshot explanations use
editor-friendly terminology. The number of entries in the classic
header is presented as saved versions rather than raw change count.

## Compatibility and safety

**Display-only migration.** No writes are made to `Checkpoint.description`,
`operationType`, `checkpointType`, branch references, or the checkpoint
parent graph. The existing Isar schema, V1/V2 compatibility, `.msone`
format, restoration safeguards, alternate history, named branches and
bookmarks are untouched.

## Regression scope

- Ten pure mapping tests cover known generated descriptions,
  annotation types, split/merge numbering, manual names, unknown
  legacy descriptions, blank fallbacks, and classic badge types.
- Two graph widget regressions check the visible label against
  the unchanged stored description, including custom manual names.
- Existing branch/tip race guards, checkout flows, protected references,
  restore dialogs, and full Flutter regressions remain enabled.

## Verification

One Linux Flutter-only job: dependency resolution, `flutter analyze`,
and full `flutter test`. No native application builds, other platform
runners, or per-change CI dispatch. The final [Linux Flutter CI run #39830916901](https://github.com/anzilr/SubtitleStudio/actions/runs/39830916901)
completed successfully with **744 tests passed** and `flutter analyze`
reporting **No issues found**. This includes 10 pure mapping tests
and 2 graph widget tests for the new edit-history labels.
The accepted code commit is [`501cbbd`](https://github.com/anzilr/SubtitleStudio/commit/501cbbdbe95b41d7ae3448e3d3e601c3c38938c9).
No native app builds or multiplatform tests were run.

## Next

CP91 R4: further history accessibility/compact reference management,
then the compact mobile Edit Line productivity changes, followed by
CP92 cleanup and CP93 platform acceptance.
