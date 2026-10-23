# SubtitleStudio — DS2 R1 Desktop Interactions and Shared Hotkeys

Date: October 23, 2026
Branch: `feature/desktop-workspace-preview`
Specification: [Studio Dock v1](STUDIO_DOCK_V1_IMPLEMENTATION_DESIGN_2026-10-23.md)

## Existing keyboard infrastructure confirmed
- `lib/utils/msone_hotkey_manager.dart`: production cross-platform desktop hotkey manager powered by `hotkey_manager`.
- Defined platform-aware, **in-app** commands include next/previous cue (primary + period/comma), play/pause (Ctrl+Space on Windows/Linux or Shift+Space on macOS), find (Ctrl+F), mark cue (primary+M), save (primary+S), and many additional editor actions.
- The standalone desktop-preview entrypoint calls `MSoneHotkeyManager.initialize()` once. Studio Dock registers only its current **nextLine, previousLine, playPause, findReplace, markLine** callbacks using this manager, and unregisters those callbacks on widget disposal.
- Text-field focus protects editing from command callbacks. No registered save/open/export callback exists in the demo preview, and no production records are touched.
- The new palette uses a local `CallbackShortcuts` Ctrl/Cmd+K mapping because that chord has no existing `HotkeyAction` mapping. Other native key chords are **not duplicated**.

## New DS2 R1 interactions
- Grid cue focus and Up/Down keyboard movement, plus Ctrl/Cmd toggle selection and Shift range selection by visible cue identity, with no media seeking.
- Right-click menu for select cue, toggle review mark, copy existing start/end timecodes to clipboard.
- Searchable command palette: find cue, next/previous cue, toggle playback preview, review mark, and switch inspector tabs.
- Preview status and all data remain in-memory. Existing shared domain controllers, Isar and media engine are untouched.

## Tests and release gate
- Existing DS1 tests retained; DS2 widget regressions cover palette, focus navigation and multi-row mark actions.
- GitHub Actions MUST run `flutter pub get`, `flutter analyze`, `flutter test` only. No platform builds.
- Windows native visual smoke is a separate user/local validation gate.
- Deferred to DS2 R2: pane preference persistence, shortcut lifecycle hardening and advanced focus/context-menu actions.
- Later DS3–DS5 will wire production transactions, playback and file persistence only via authoritative shared services.

## Final verified gate
- [Flutter Actions #40015101393](https://github.com/anzilr/SubtitleStudio/actions/runs/40015101393): **581 tests passed, analyzer zero issues**. No native platform builds.
