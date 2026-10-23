# SubtitleStudio — DS2 R2 Desktop Layout Preferences

Date: 2026-10-23
Branch: `feature/desktop-workspace-preview`
Build on: [DS2 R1 hotkey reuse](STUDIO_DOCK_DS2_R1_HOTKEYS_AND_INTERACTIONS_2026-10-23.md)

## Implementation
- `StudioDockLayoutPreferences` stores only per-device UI layout state using existing `shared_preferences`: explorer/inspector widths, center video/waveform ratios and whether side panels are open.
- Defaults are **240 px explorer, 320 px inspector, 43/13/44**, both panels open when breakpoints permit.
- Loaded values are clamped to the design minimums/maximums; no subtitle text, user content, project files or `.msone` state is written to these settings.
- Splitter drags debounce writes; drag completion, reset and desktop show/hide commands trigger immediate best-effort saves.
- The command palette includes **Reset workspace layout**.
- Restores per-device settings at preview startup, preserving edits made before the asynchronous preferences read completes.
- Existing four skins, demo media, cue editing prototype and shared hotkey registrations are unchanged.

## Regression and acceptance
- Shared preferences round-trip / invalid value bounds / widget reset from persisted closed Explorer are covered with mock preferences.
- Existing DS1 and DS2 R1 keyboard, palette, selection and responsive layout widget regressions continue to run.
- Flutter-only Actions: `flutter pub get`, `flutter analyze`, `flutter test`; **no platform builds in CI**.
- Local Windows native smoke must still verify persistence after process restart, scaling, drag thresholds and focus.
- Native integration with persistent projects and real video remains DS3–DS5.

## Next
DS2 keyboard and context-menu acceptance on Windows, then the shared-core production integration gate (DS3). Continue using the existing `MSoneHotkeyManager` and registered HotkeyAction bindings rather than introducing duplicate keyboard infrastructure.
