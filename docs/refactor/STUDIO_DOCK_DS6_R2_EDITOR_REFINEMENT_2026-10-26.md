# SubtitleStudio — DS6 R2: compact editor correctness

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Existing behavior audited and retained

- The Original and Edited text inputs retain 112px fixed heights and their
  internal text scrolling. Read-only Original remains selectable, and its
  edit toggle uses the shared original-text transaction.
- START and END remain in one row under the Text inspector; the independent
  Timing tab stays removed. DURATION still updates END rather than START.
- Compact 28px subtitle rows and 13pt text remain unchanged, as does the
  36/24/40 video/waveform/list layout. Mobile UI is not modified.

## Refinements

- Replaced the confusing header `selected cue / total cue` display (which
  regularly showed `569 / 569`) with a real subtitle count. Filtering and
  searching display `shown of total`; multi-selection reports its size.
  The selected cue number stays in the Line Inspector header.
- Duration is parsed with exact millisecond precision: only positive seconds
  with up to three decimals, a valid canonical START time, and an END before
  24:00:00,000 are accepted. Invalid START no longer silently maps to zero.
- Invalid duration input now counts as an unsaved timing draft: Apply is
  disabled, navigation shows Apply/Discard/Cancel, and Cancel keeps the value.
  The existing valid END remains unchanged until the duration is corrected.
- A project switch or accepted structural update clears stale duration
  validation errors.

## Regression coverage

- Unit tests cover duration rounding/precision, invalid values, invalid
  START, and 24-hour overflow.
- Widget tests preserve the 112px height, Original selectability/edit toggle,
  invalid-duration navigation boundary, and filtered header counts.
- Run Flutter analyzer and focused + full Flutter tests in GitHub Actions;
  there must be no platform builds. Native Windows acceptance remains deferred.
