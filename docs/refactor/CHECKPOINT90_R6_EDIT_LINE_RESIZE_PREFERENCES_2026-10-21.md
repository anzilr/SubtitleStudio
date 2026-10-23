# SubtitleStudio — CP90 R6: Edit Line resize preference ownership

Date: October 21, 2026
Branch: `refactor/riverpod-architecture`
Scope: UI preference lifecycle; no file, encoding or native-media changes

## Issue and change

Edit Line had two widget-owned debounce timers for the desktop split and
mobile video split. Closing the route canceled those timers, dropping a drag
made within the final 300 ms (desktop) or 500 ms (mobile). In addition, a
desktop logging `await` ran before the widget updated its local ratio, so
asynchronous logging could delay scheduling the preference save.

The route-scoped `EditLineController` now owns the already-tested
`EditorResizePreferenceCoordinator` (shared with the main Editor). Both
ratios update Riverpod state synchronously. The desktop local widget ratio
still uses the existing `setState` behavior, and mobile remains a local
ratio update without forcing a parent widget rebuild on each drag frame.
The coordinator retains the established 300/500 ms debounce intervals,
coalesces rapid changes, and flushes the latest values on provider teardown.

On the first drag, the controller captures an `EditLineRepository` while
Riverpod is active. Pending saves use that captured repository, never a
widget or `ref` after disposal. The existing preference keys are unchanged:
`resizeRatio` updates `Preferences.editLineResizeRatio` (not the main
Editor's `editScreenResizeRatio`), and `mobileVideoResizeRatio` retains its
shared field. The Isar schema and stored project documents are untouched.

## Regression coverage

- New Isar-backed controller test: rapid successive desktop/mobile changes
  reach state immediately, survive provider disposal without waiting for
  the debounce timers, and persist the *last* selected values.
- The test also guards against overwriting the separate main Editor desktop
  ratio, using the actual `Preferences` schema and repository writer.
- The shared coordinator's existing five tests continue to cover debounce,
  independent channels, in-flight save ordering, repeated closure and
  save-error recovery.
- Run full Linux `flutter pub get`, `flutter analyze`, `flutter test` in
  GitHub Actions; no platform builds or extra Windows/macOS file-host matrix.

Verification: [Linux GitHub Actions run 39664510820](https://github.com/anzilr/SubtitleStudio/actions/runs/39664510820)
passed **672 Flutter tests and zero analyzer issues**. The initial R6 run
passed all 672 tests but reported two analyzer diagnostics: an unnecessary
`dart:typed_data` import in Edit Line and an unused Windows parameter in an
Editor Save test fake. Both were removed and the full Linux suite was rerun
successfully. No native application builds ran in CI.

## Remaining constraints

- Pending writes are flushed on Flutter route disposal; forced process death
  cannot guarantee completion of asynchronous disk I/O.
- No Android/iOS/Windows/macOS native smoke test is implied by the Flutter
  suite. The media_kit hot-restart SIGSEGV remains a separate open issue.
- Continue CP90 mixed UI/controller boundaries and the already planned CP91
  checkpoint-history and compact mobile Edit Line work. Waveform experiments
  and appearance remain paused.
