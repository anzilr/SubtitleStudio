# SubtitleStudio — CP93 R6: Splash background asset and startup gate

Date: October 23, 2026
Branch: `refactor/riverpod-architecture`
User report: the original film-strip background no longer appeared at startup.

## Root cause

The user replaced the large JPEG with an optimized `1200×2100` WebP in commit
`51af1dac` but the Flutter asset manifest and splash widget still referenced
the deleted `assets/msone_bg.jpg`. The older code also performed an unawaited
full-resolution preload using an image-cache key different from the actual
`Image.asset` decode, concealed the image until decoded, and navigated away
after a fixed 1.2-second minimum without coordinating background readiness.

## Correction

- Register and render the existing user-supplied `assets/msone_bg.webp`.
- Use one decoding path (direct `Image.asset`, no duplicate preload or
  redundant cache-size decode), retaining the existing film-strip overlay,
  logo, text and loading animation.
- Signal the splash route after the first image frame has been painted. Give
  the background 1.8 seconds to become ready, then show the splash for one
  second before normal navigation. Image failure reports only an exception
  type, displays the existing black fallback and releases the wait; a missing
  callback cannot block startup indefinitely.
- Add a Flutter test verifying the bundled WebP is decodable at its expected
  dimensions and both asset declarations use the same path.

## Validation and remaining acceptance

- Git diff check and WebP image metadata validation completed locally.
- Flutter analysis and tests must run in GitHub Actions (no platform builds).
- Cold-launch visual acceptance on Android is still required: the background
  should be visible behind the blurred dark overlay, with no black-only
  flash beyond the native Android launch screen and no excessive delay.
- The CP93 R5 waveform device acceptance remains separate.
