# Desktop Workspace — parallel UI preview track

Created: 2026-10-20
Branch: `feature/desktop-workspace-preview`
Base: `refactor/riverpod-architecture` at commit `f48327f`

## Decision

Run **two parallel tracks**:
- **Core refactoring stays authoritative on `refactor/riverpod-architecture`** (CP88–CP93; file access, encoding, editor controllers, Git-style checkpoint UX, cleanup, native acceptance).
- **Desktop presentation and usability prototypes stay on this feature branch** until shared contracts are stable. Build layout, resizing, desktop keyboard interactions and tests without forking domain logic, Isar models, project files, or native media services.

The user wants to see the desktop workspace now, before refactoring finishes. An independently launched **demo-data UI** is preferable to a premature deep integration that risks regressions to Android and corrupting real subtitle projects.

## Included first milestone

- Independently runnable `lib/main_desktop_preview.dart`. It intentionally skips the production `main.dart` boot sequence, Isar setup, media_kit startup and native file pickers.
- Single-screen three-column editor: 61px rail; collapsible/resizable project sidebar; center video placeholder + transport + schematic waveform + searchable subtitle table; optional/resizable right inspector.
- Project/file/version preview, keyboard-friendly list, a filter, cue selection and a local-only editable line inspector with mark/reset actions. Theme uses Carbon Zero-compatible neutral surfaces with jade semantic accent as a **prototype**, not a new registered skin.
- Breakpoints collapse project sidebar on smaller widths and the inspector on narrow desktops. These are independent desktop widgets (no changes to mobile screens).
- Placeholder video and synthetic subtitle lines are *visibly identified as demo data*. They are not user content and do not create or alter any SRT, MSone, Isar database or cached waveform.

## Launch the actual Flutter desktop layout

```powershell
git fetch origin
git switch --track origin/feature/desktop-workspace-preview
flutter pub get
flutter run -d windows -t lib/main_desktop_preview.dart
```

If a local feature branch already exists, use `git switch feature/desktop-workspace-preview` and `git pull --ff-only`. For Linux or macOS, replace `windows` with `linux` or `macos`.

**Builds stay local:** GitHub Actions is permitted only `flutter pub get`, `flutter analyze`, `flutter test`; no Windows, Linux, Web or mobile builds in CI.

## Interaction scope and limitations

Working in preview: cue search, cue selection, mark/unmark, editing demo text, restoring text, simulated play/pause, editor/history/tools navigation, resizing sidebar/inspector, inspector toggle.

Deliberately not wired: real player, subtitle persistence/Isar, project import, video loading, waveform decoding or seek/timing changes, checkpoint actions, export, collaboration. Buttons needing these services are omitted or replaced with explanation placeholders rather than fake workflows. This is a **functional layout prototype, not production desktop editing**.

## Integration gates

1. Confirm visual proportions, vertical space use and keyboard/touchpad affordances with real Windows screenshot and local feedback.
2. Replace demo cue data with a Riverpod read-model adapter to `EditState` and reusable subtitle list provider, without duplicating parsing/database operations.
3. Introduce a desktop document selection adapter after CP88, retaining mobile SAF and the current `StudioFileIdentity` contract.
4. Connect media, waveform and checkpoint history only through the existing service/controller boundaries once their CP90/CP91 components settle.
5. Keep this feature branch periodically rebased or merged forward from the core refactor after tests; avoid directly cherry-picking half-complete domain APIs.
6. Prior to production release, run local Windows native acceptance, tests, loading/saving a sample SRT, performance and accessibility checks.

Desktop UI can develop in parallel with refactor; **production integration still depends on CP93 acceptance**.

## Flutter-only quality acceptance

[GitHub Actions run 39487356891](https://github.com/anzilr/SubtitleStudio/actions/runs/39487356891): **SUCCESS**, **573 tests passed**, `flutter analyze`: **No issues found** on October 20, 2026. This includes four new desktop widget regressions covering wide workspace panels, subtitle search/selection, inspector toggle/navigation, and narrow-window collapse. Only dependency resolution, analyzer and Flutter tests ran; **no Windows, Android, Linux, macOS, iOS or Web builds were run in CI**.

The initial CI run [39486519781](https://github.com/anzilr/SubtitleStudio/actions/runs/39486519781) also passed 573 tests but noted a redundant `dart:ui` import. The final run above removed that lint and is the acceptance gate. Windows native rendering and actual desktop device input are still to be tested locally.

## Local desktop smoke test checklist

1. Run `flutter devices` and confirm the intended desktop target is visible.
2. Start `flutter run -d windows -t lib/main_desktop_preview.dart`. Do **not** start the production entrypoint `lib/main.dart` for this isolated layout check.
3. At roughly 1500×900 or larger: project tree, video, waveform, subtitle table, and line inspector should all be visible. Resize project sidebar and inspector using the thin separator strips.
4. Enter `midnight` in cue search, select the resulting line, edit its text in the inspector, and verify both table and placeholder video update. Mark and Reset should change demo-only state.
5. Toggle the inspector, click History and Back to editor, then resize to ~820px wide; project and inspector panels should collapse without rendering overflow.
6. Exit and relaunch; since there is no storage adapter yet, all demo edits should reset. The app must never touch existing Isar projects, SAF permissions, videos or subtitle files.

This branch remains experimental. Desktop production integration will reuse shared core services as CP88–CP93 proceed in parallel.
