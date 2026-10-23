# SubtitleStudio — CP91 R7 branch discovery and saved-point terminology

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`  
Scope: Edit History visual and classic UI; no database schema or project-format changes.

## User report

- Rename **saved versions** to **saved points** and **Separate path** to
  **Separate branch**.
- **Branch from this point** creates a named branch, but the new name is not
  immediately visible and there is no obvious way to choose it. The branch
  chip strip scrolls horizontally, so additional branches may be offscreen.

## Implemented

1. The classic Edit History count and snapshot/save-related UI now use
   **saved point** terminology. The detached history status now says
   **Separate branch**. Known automatically generated snapshot titles and
   classic badges use **Saved project point** / **Saved point**. Persisted
   `snapshot`, `manual`, and custom descriptions are unchanged.
2. A new **View branch** picker lists **All branches** and every named
   branch, regardless of the horizontal chip strip's scroll position. Branch
   colors match the timeline and chips. The picker is always reachable on
   narrow phone screens; it does not shrink commit cards.
3. Successful **Branch from this point** automatically focuses the newly
   created branch's history. Only its tip and ancestors are shown, with the
   original editor HEAD and editing state untouched.
4. A focused branch that is not in use offers **Switch to this branch**.
   This invokes the existing explicit confirmation and concurrent HEAD/tip
   safeguards, so viewing a branch is not mistaken for editing on it.
5. Widget tests cover branch creation, focused history, separate guarded
   editing switch, picker reset to all branches, and selecting the final
   branch from a many-branch 320px viewport. Label contract tests are updated.

## Verification

Code review and `git diff --check` completed. Flutter SDK is not available
in the agent's scratch environment, so the Linux GitHub Actions job runs
`flutter pub get`, `flutter analyze`, and `flutter test -j 1`, without any
Android, desktop, iOS or other platform builds.

- Code commit: `ef404a0796c64df869540c70d5d5e063f3b541cb`
- [CP91 R7 CI run](https://github.com/anzilr/SubtitleStudio/actions/runs/39843632143)
- Result: **success — zero Flutter analyzer issues; 757 tests passed**.

## Next

Resume the already planned compact portrait Edit Line pilot in CP91 R8;
keep desktop screen integration deferred until after CP93.
