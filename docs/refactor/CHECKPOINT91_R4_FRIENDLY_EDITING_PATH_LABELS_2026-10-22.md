# SubtitleStudio — CP91 R4: Editing-path labels without Git terminology

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Problem confirmed

After CP91 R3, Edit History still displayed the exact strings `main`
and `current branch` because the presentation helper exposed the Git
reference suffix from `refs/heads/main`. The heading, branch chips and
checkout confirmation continued using technical terms despite the new
subtitle-friendly edit-event descriptions.

## User-facing changes

| Previous UI | Current UI |
| --- | --- |
| Working on main | Editing: Main edits |
| main (current branch) | Main edits · In use |
| Switch to branch | Use this editing path |
| Start a branch here | Start another editing path |
| Name new branch / Rename branch | Name editing path / Rename editing path |
| Switch to this branch? | Use this editing path? |
| Detached version: Not on a branch | Editing from version #… · Separate path |
| Branch point | History split |
| From #… · On current path | From #… · Earlier on this path |

For non-default editing paths, the existing user-supplied names remain
visible; active paths use the same "In use" status. Bookmarks retain their
user-supplied names. Restoring a version explicitly explains that editing
can continue separately without changing the saved positions of other
paths. Switching to a named path remains a distinct action.

## Implementation details and safeguards

Changes are in the shared display helper
`CheckpointHistoryLabels` and `CheckpointHistoryPanel` only.
`refs/heads/main` is **not** renamed. The graph still knows the exact
branch names, protected main/HEAD properties, attached/detached state,
checkout target IDs, observed HEAD ID and observed branch-tip ID. Existing
backend validation and guarded mutations are unchanged. Older `.msone`
archives and Isar history records continue to use their original
reference IDs.

The history vocabulary no longer leaks `main` or `current branch` on
the visual history surfaces, including the active header, chips, menu
choices and confirmation dialog. Internal widget keys intentionally
still contain exact reference IDs for stable identity and testing.

## Regression tests

Expanded `checkpoint_history_labels_test.dart` to verify the built-in
protected main reference presents as "Main edits", alternate named paths
remain recognizable, detached status stays comprehensible, and the
underlying main reference and protection flags are unchanged.
Expanded `checkpoint_history_panel_widget_test.dart` to verify the
visible header/chips and menu/dialog copy, absence of old labels, use
of alternate paths, and preservation of protected reference actions.

## Verification

The final [Linux GitHub Actions run #39832780788](https://github.com/anzilr/SubtitleStudio/actions/runs/39832780788)
passed **746 Flutter tests**, and `flutter analyze` reported **No issues
found**. This includes new regression coverage for default-path aliases,
alternate active paths, history controls, and unchanged internal ref
identity/permissions. The verified code is
[`1a05aa9`](https://github.com/anzilr/SubtitleStudio/commit/1a05aa9962991c9b3340c930f220f6456103db24).
Only Flutter dependency resolution, analysis and tests ran on Linux;
there were no native builds or multiplatform matrix checks.

## Next

CP91 R5: compact reference management and accessibility, then mobile
Edit Line productivity/layout work. Follow CP92 cleanup and CP93 native
acceptance. Physical device acceptance remains separate from Flutter
unit/widget tests.
