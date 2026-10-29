# Studio Dock DS7 R23 — portable project import parity

Date: 2026-10-29
Branch: `feature/studio-dock-integration`
Predecessor: DS7 R22b (`4cb41e45b8b1f69f425caba8f4cdcbef180349fb`)

## Scope

- Desktop `.msone` import now reviews the portable document before any writes.
- Explicit destination: import as new or replace a selected existing project.
- Replacement has a separate irreversible-in-database confirmation. It does not overwrite external SRT files.
- Explicit source SRT choice: archived local SRT (only when accessible), current session SRT (on replacement, when accessible), locate another `.srt`, or import unlinked for later Save As.
- Unavailable archived paths from other computers are not treated as valid editable source files.
- Existing typed import repository is reused for complete history and portable reference remapping.
- On invalid project history, a dedicated confirmation offers subtitle-only import (which discards incompatible imported history); Cancel leaves the selected project unchanged.
- Main desktop `importFile` no longer silently accepts `.msone` without the preflight.
- SRT-only product language on the desktop landing screen remains consistent until VTT/ASS/SSA editing is lossless.

## Test coverage

`test/studio_dock_project_actions_test.dart`:
- No silent `.msone` import; new unlinked import preserves lines, marks, comments, edit position, and history.
- Locate local SRT without modifying its bytes.
- Replacement preserves source SRT and session identity, while importing the new history.
- Invalid history rejection does not mutate existing project; explicit subtitle-only retry imports no checkpoints.
- Missing archived SRT and non-SRT source cannot mutate a project.

`test/studio_dock_project_import_dialog_test.dart`:
- Preview and unavailable archive disabled.
- Explicit replacement target and existing SRT source.
- Browse local source.
- Cancel does not select an import.

## Remaining parity

P1: SRT import optional `.msone` save; desktop Save As (relink) vs mobile export (non-relink) clarity, shared encoding and tag options.

P2: Desktop embedded video subtitle-track extraction; create-from-scratch source location/encoding; complete keyboard and menu action parity; source-link integrity and reopen regression matrix.

Later: lossless VTT/ASS/SSA workflows, SubtitleEdit-inspired timing and editing tools, and video mux/burn-in workflows.

CI policy: `flutter pub get`, `flutter analyze`, `flutter test` only. No platform builds in GitHub Actions.
