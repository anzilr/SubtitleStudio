# Studio Dock DS7 R24 — SRT export choices parity

Date: 2026-10-29
Branch: `feature/studio-dock-integration`

## Implementation

- The desktop Export SRT dialog now offers the same meaningful output options
  as mobile: original or edited text in Translation Mode, output encoding, and
  a filename tag for edited exports. Edit Mode exports its single text track.
- The options are passed to the shared SRT export compiler. The saved copy
  never changes the working project's encoding or linked source location.
- Desktop Save As keeps its existing native-desktop behavior of linking the
  newly saved SRT as the project's working file. Its menu item and file-picker
  title now explicitly say that it switches the working file. Export SRT is
  described as a separate copy, so the two actions cannot be mistaken for
  identical operations.
- Cancellation returns without exporting or modifying the active project;
  output replacement still requires an explicit confirmation.

## Regression coverage

- `test/studio_dock_export_dialog_test.dart`: cancellation, output text,
  encoding, tag, and Edit Mode option visibility.
- `test/studio_dock_file_actions_test.dart`: custom export charset and tag
  produce bytes without changing the project's stored encoding or source.
- `test/studio_dock_file_actions_widget_test.dart`: Save As labeling, export
  confirmation, original/edited choices, Edit Mode path.

## Remaining parity

P1: Optional `.msone` project save during SRT import; create/new source choice
and a consistently documented Save As versus Export contract across mobile
and desktop. A native Windows source-file/reopen acceptance pass is still
required. Prior audit P0 format-write restrictions and R23 `.msone` import
preflight stay in force.

P2: Embedded video subtitle-track extraction in desktop Home, create-from-
scratch output encoding/location, and broader menu/shortcut parity.

Checks: Prefer the connected VS Code workspace for `flutter analyze` and
`flutter test`; no platform builds or GitHub workflow runs in this checkpoint.
