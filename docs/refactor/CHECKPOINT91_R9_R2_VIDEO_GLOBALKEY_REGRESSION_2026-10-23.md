# SubtitleStudio — CP91 R9 R2: Duplicate video GlobalKey hotfix

Date: October 23, 2026  
Branch: `refactor/riverpod-architecture`

## Android report

On a OnePlus CPH2381 (Android 14), Edit Line reported
`Multiple widgets used the same GlobalKey` for `VideoPlayerWidgetState`.
Flutter identified two simultaneous parents:

- `SizedBox(height: 200.0)` in the inline video layout.
- `LayoutBuilder('video_player_layout_builder')` in the mobile resizable
  video layout.

Following a manual Flutter hot restart, the native `media_kit` reference
cleanup reported two references and `libmpv.so` raised `SIGSEGV`. These are
**two distinct events**. The duplicate GlobalKey is reproduced from source
and fixed here. The native crash after hot restart has recurred but is **not
proven fixed** by this Dart layout change.

## Confirmed root cause

Before CP91 R8, `_buildContentWithoutVideo` filtered an inline player by
testing whether a direct child was a `SizedBox` with exactly `height == 240`.
R8 introduced `EditLinePortraitMetrics` with a compact inline-video height
of 170–200px, so the filter left the inline player in the editing pane.
When the mobile resizable split was enabled, it also created a second player
with the same `_videoPlayerKey`. This violated Flutter's GlobalKey ownership
contract. The old spacing filter likewise depended on widget neighbors.

## Fix

1. Introduce `EditLineVideoSlot` with explicit inline video and spacing
   keys, independent of their heights or position.
2. Apply those keys to the inline player `SizedBox` and its 1px spacer.
3. `withoutInlineVideo` removes only the two keyed slots when building the
   resizable editing pane. An unrelated 240px box or 1px spacer is retained.
4. The existing video key, callbacks, `ResizableSplitView` preference,
   media initialization/disposal, Riverpod controller state, skin colors and
   `.msone` data remain unchanged.

## Regression coverage

New `test/edit_line_video_slot_test.dart` verifies slot removal at heights
170, 200 and 240; preservation of unrelated 240px and 1px widgets; and a
`GlobalKey` surviving transitions between fixed and resizable layouts with
one mounted player in each.

## Verification

- Code commit: `2a49bb54bd3228873f3b5cd6e7ebbd3525caaaa4`.
- GitHub Actions: [run 39908801629](https://github.com/anzilr/SubtitleStudio/actions/runs/39908801629)
  succeeded; 768 Flutter tests passed and zero analyzer issues.
- CI does not build Android, Web or desktop binaries.

## Android acceptance (required)

1. Stop the existing debug app process completely. Fetch the latest
   `refactor/riverpod-architecture` and install a new local debug build.
   Do **not** use hot restart for this comparison.
2. Load a video in Edit Line. Toggle **Resize Player on Keyboard** in the
   menu, show/hide video and open/close the keyboard repeatedly.
3. Verify there is exactly one video pane and no duplicate GlobalKey error.
   Check that play/pause, seeking and saving a subtitle still work.
4. Repeat after returning to the Editor and opening Edit Line again, and
   after rotating. Preserve the project data throughout.
5. Test a completely separate fresh-process start and, if needed, a manual
   hot restart while video was active. If only the latter still causes
   `libmpv.so` SIGSEGV, capture a fresh timestamped native stack and log it
   as a distinct media-kit lifecycle defect.

Do not mark the native SIGSEGV fixed from analyzer/widget results alone.
