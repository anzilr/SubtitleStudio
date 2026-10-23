# SubtitleStudio — CP91 R9: Compact Edit Line action controls

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Context

CP91 R8 improved cue editing and timestamp layout on narrow portrait phones.
Its device-level visual acceptance remains pending. CP91 R9 addresses a
separate, visible constraint: the Edit Line action row attempted to fit up
to seven buttons into the same limited width, reducing hit area and making
frequently used controls harder to reach.

## Changes

1. New reusable `EditLineActionStrip` owns presentation-only expansion state.
   On narrow portrait phones, the primary row always shows **Previous**,
   **Save**, **Play/Pause** when video is loaded, **Next** and a **Tools**
   toggle. Dictionary, formatting and line actions appear on a second row
   only while Tools is expanded.
2. The frequent `IconButton` controls use 48px minimum width and height in
   compact portrait. Tooltips identify Previous/Next subtitle, Save, and
   Play/Pause controls for accessibility.
3. Landscape, desktop and wider UI retain the old full-width action order,
   action availability, button sizing and all existing callbacks.
4. No changes to Riverpod controllers, keyboard editing, media player
   lifetime, subtitle persistence, `.msone` format, skin palettes or
   automatic save navigation rules.

## Regression coverage

`test/edit_line_action_strip_test.dart` checks:

- Primary action visibility on 320px portrait and retained Save/Next taps.
- Expand/collapse of all available tools without changing editor callbacks.
- Full original action availability on a wide/landscape layout.
- No-video compact mode with optional player/line action controls absent.

## Verification

- Code commit: `4d5fdddb557926f41ab19d2b67413cfc05de42a6`.
- [Flutter CI run](https://github.com/anzilr/SubtitleStudio/actions/runs/39907251049):
  **success, zero analyzer issues and 766 Flutter tests passed**.
- GitHub Actions runs dependency resolution, Flutter analysis and full
  Flutter tests on Linux only. No Android, iOS, Web or desktop builds.

## Android acceptance (pending)

1. On a narrow portrait phone, open Edit Line. Verify Previous, Save,
   optional Play/Pause, Next and Tools are all immediately available.
2. Tap Tools: dictionary, formatting and line action menus must work.
   Collapse Tools and verify Save and navigation still work.
3. Repeat with no video, with video paused/playing and with the keyboard
   open; confirm controls remain tappable and the subtitle is saved.
4. Rotate to landscape. The original single-row toolbar should reappear.
5. Repeat in Carbon Zero Light/Dark/Classic and at least one other skin.

## Roadmap

R8 and R9 are Flutter-level feature gates, not a replacement for physical
device checks. After confirming narrow portrait acceptance, proceed to CP92
cleanup/regression/performance and then CP93 cross-platform acceptance.
