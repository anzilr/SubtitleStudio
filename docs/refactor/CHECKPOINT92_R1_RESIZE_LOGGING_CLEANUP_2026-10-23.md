# SubtitleStudio — CP92 R1: Edit Line resize logging cleanup

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Scope and evidence

CP92 begins with a contained hot-path audit of Edit Line's resizable video
pane. The mobile `ResizableSplitView.onRatioChanged` callback previously
called `logInfo` for every drag update. Desktop callbacks also sampled
diagnostic logs while the same class logged transient loading/layout
states during builds. This produced unnecessary asynchronous logging work
while users dragged the divider, despite the resize preferences already
being coalesced by the Edit Line controller.

## Change

1. Remove per-event mobile and sampled desktop divider logging, transient
   resize-loading logs and stale commented-out layout tracing.
2. Remove the obsolete `_lastLoggedRatio` state and log-only throttle in
   desktop resize preferences.
3. Keep both `onRatioChanged` handlers, in-memory ratios, Riverpod state and
   the controller's debounced preference persistence unchanged.
4. Add a regression that schedules 1,000 quick desktop/mobile ratio updates,
   closes the controller, and confirms the final values are persisted in
   Isar without overwriting the main Editor's independent resize setting.

This is a reduction in avoidable log traffic, **not a measured frame-time
improvement**. No video ownership, layout, player GlobalKey, save, import,
subtitle history or `.msone` format code was changed.

## Verification

- Code commit: `c8085c017da63fc145e1dcbd53a19a2205740d7d`.
- [GitHub Actions Linux run 39915868638](https://github.com/anzilr/SubtitleStudio/actions/runs/39915868638):
  769 Flutter tests passed and zero analyzer issues.
- No platform app builds were requested in CI.

## Follow-up

Continue CP92 with a separate audit of potentially identifying file/media
path diagnostics and targeted benchmarks of import/open/save/restore.
CP91 compact Edit Line physical-device acceptance and the independent
`libmpv.so` hot-restart lifecycle issue remain open; neither is established
by this non-native checkpoint.
