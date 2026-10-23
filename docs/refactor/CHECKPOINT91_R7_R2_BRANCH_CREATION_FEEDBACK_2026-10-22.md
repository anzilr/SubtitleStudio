# SubtitleStudio — CP91 R7 R2: Branch creation feedback

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Reported behavior

The user selected **Branch from this point**, entered a branch name, and
observed no new branch or confirmation. Trying again after **Restore this
point** produced the same result.

## Investigation

- The visual panel accepted arbitrary text in the name dialog, but the Isar
  reference store permits only Git-style portable name segments (letters,
  numbers, dots, hyphens and underscores, and optional `/` separators).
  A name containing a space was rejected by the store.
- The panel's generic mutation catch reported failure through the editor's
  `ScaffoldMessenger`. Because Edit History runs in a modal sheet, that
  snackbar may be obscured. The name dialog had already closed, making a
  rejected transaction look like a successful no-op.
- The durable action already supports creating a branch at a saved point
  without switching HEAD. New actual Isar coverage checks the flow after
  restoring an earlier point.

This is a confirmed silent-error route. The specific failure that occurred
on the user's device is not yet independently known; no device diagnostic
was supplied.

## Changes

1. `HistoryReferenceNaming` centralizes validation used by both the naming
   dialog and persistent `HistoryRefRepository` without changing the accepted
   `.msone` reference names.
2. Invalid names stay in the dialog, with actionable text (for example,
   replace spaces with hyphens). Empty names and invalid segments are also
   rejected before a transaction.
3. The panel displays a persistent, dismissible success/error message
   *inside* Edit History. Durable creation explicitly confirms the branch
   name and reminds users to select **Switch to this branch** if they want
   to edit on it. Known duplicate-name and missing-target errors receive
   contextual messages. Failure never claims a branch was saved.
4. Tests cover naming policy, a rejected name followed by a corrected name,
   simulated storage rejection, and a real Isar restore-then-create sequence.

## Verification

- Code commit: `82bd7da88175275bd523d065ebd2d59ddd62c498`
- [Flutter CI run](https://github.com/anzilr/SubtitleStudio/actions/runs/39847963076)
- Flutter dependency resolution, analyzer and complete tests only; no native
  builds. **Success: zero analyzer issues and 762 passing Flutter tests.**

## User acceptance on Android

1. Rebuild the latest `refactor/riverpod-architecture` branch in debug mode.
2. In Edit History, choose **Branch from this point** and try `My New Branch`.
   The dialog should stay open and ask for hyphens/underscores.
3. Change it to `my-new-branch`, save, and verify the new branch appears in
   **View branch**, with a visible success notice.
4. Use **Switch to this branch** and confirm. Save a new editing point,
   then return to history to verify its ownership.
5. Restore an earlier point and create `after-restore`. Verify it appears.
6. If a valid name still fails, capture the *in-panel error message* and
   share it together with the exact entered branch name; this distinguishes
   name collisions from session/history integrity failures.
