# SubtitleStudio — DS6 R1: desktop modal keyboard consistency

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Scope

Studio Dock is the native-desktop presentation layer. This checkpoint adds
keyboard behavior to its own dialogs without changing the shared mobile UI,
the subtitle model, or file persistence.

## Implemented

- Enter and numeric-keypad Enter activate the primary button; Escape takes the
  cancellation path on desktop confirmation dialogs for bulk review, video
  unload, cue deletion, selected deletion, replacement, bulk tools and history
  restoration.
- Merge defaults to the available adjacent cue (next when available, previous
  for the last cue). Export defaults to edited text. Explicit alternate
  choices remain available with mouse/keyboard focus navigation.
- Index selection, selected-cue shift, anchored synchronization and framerate
  conversion now use the same validated action for button and Enter, so an
  invalid value cannot be accepted from the keyboard.
- Selected-cue shift protects its pending asynchronous save: Enter cannot
  dispatch a second request and Escape cannot close the form during saving.
- Go to Line and subtitle color selection support Enter/numpad Enter/Escape
  through the existing submit/apply methods; Go to Line rejects out-of-range
  input before closing.
- Every keyboard-enabled desktop dialog owns an initial focus target, so an
  Enter keypress can reach its action even before the user clicks a field or
  tabs to a button. A focused editable field can still take focus normally.
- Existing dirty-draft confirmation, standalone split/insert dialogs,
  Shift+Enter editor focus and already-wired shortcut toggles are retained.

## Regression coverage

- Escape cancels deletion without a callback; Enter confirms exactly once.
- Enter combines with the only enabled neighbor.
- Go to Line rejects invalid Enter and supports Escape and valid Enter.
- Index selection rejects reversed Enter ranges, cancels with Escape and
  accepts a valid Enter range.
- Sync requires valid time anchors before showing the second confirmation;
  Escape on that confirmation does not invoke the persistence callback.

## Quality gate and native acceptance

Run `flutter analyze` and the focused Studio Dock Flutter test suite in GitHub
Actions (dependency resolution, analysis and tests only; no native builds).
Physical Windows acceptance is pending: dialogs opened via menus versus
shortcuts, focused text fields, color-picker input, keyboard layout variants,
and settings/modal routes owned by the shared mobile implementation.
