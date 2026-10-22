# SubtitleStudio — CP90 R10: Edit Line media readiness lifecycle

Date: October 22, 2026  
Branch: `refactor/riverpod-architecture`

## Problems

The Edit Line widget previously waited for player initialization without
validating whether the selected cue or video had since changed. An older seek
could therefore run after a newer cue selection, video replacement or Unload.
The initial seek could also be lost when the player key had not yet attached.
A video picker callback could resume after the route was disposed. Finally,
pending writes of video preferences could complete after an Unload operation
and restore an outdated video location in the project settings.

## Implementation

- Introduced a pure-Dart `EditLineMediaRequestCoordinator` with separate
  epochs for the latest subtitle seek, selected media, and file-picker
  request, including terminal route disposal.
- Every seek invalidates previous player-ready waits. Delayed calls only
  apply to the same mounted, initialized player, the latest seek token and
  the same selected video path; old results are ignored.
- The initial cue seek now also waits for the player to mount instead of
  requiring `GlobalKey.currentState` to exist during its first frame.
- Video state synchronization similarly validates the selected media.
- Video picker completion and post-save UI effects are guarded by the
  active route, picker request and media epoch.
- Unload invalidates seeks and picker callbacks, stops repeat playback,
  and clears the UI's playing state before removing video preferences.
- A controller-independent `EditLineVideoPathWriteQueue` serializes
  video-location preferences, ensuring a pending Save completes before
  a subsequently requested Unload. Its repository functions are captured
  during mounted initialization, avoiding Riverpod reads during teardown.
- No modifications to native `media_kit`/libmpv, FFmpeg, waveform, Isar
  schemas, `.msone` project format, appearance, or desktop preview.

## Verification

Eight new regression tests cover seek supersession, media swap/unload
invalidation, competing pickers, route disposal, preference write order,
and error recovery. The full Linux Flutter analyzer and tests run in
the existing CI gate. Native Android/iOS/macOS/Windows/Linux builds are
not executed in GitHub Actions.

The original [R10 CI run 39814558939](https://github.com/anzilr/SubtitleStudio/actions/runs/39814558939)
failed analyzer before tests: the video-visibility button still called the
old seek helper without required `seekToken`/`videoPath` parameters.
The R11 validation repair redirects that button to the lifecycle-safe
`_seekVideoToSubtitle` path and invalidates pending requests when hidden.
R10's tests and analyzer are being rechecked together with R11; the final
result will be recorded after CI finishes.

## Remaining

CP90 remaining Editor-state cleanup and native lifecycle acceptance hooks;
CP91 Git-style history/mobile editing UX; CP92 cleanup/profiling; CP93
native-platform and project compatibility acceptance. The previously reported libmpv hot-restart crash is no longer
reproducible according to the user's October 22 device testing. This is a
device-level status update, not a new automated native test result. Waveform
experimental work and appearance changes remain deferred.
