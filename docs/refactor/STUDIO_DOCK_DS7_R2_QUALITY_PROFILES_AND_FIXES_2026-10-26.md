# SubtitleStudio — DS7 R2: quality profiles and safe fixes

Date: 2026-10-26
Branch: `feature/studio-dock-integration`

## Scope

- Introduce three quality rule presets: General (default), Streaming
  (stricter reading speed and gap), and Relaxed. The chosen preset is
  remembered for the desktop workspace via SharedPreferences.
- Count user-visible grapheme clusters (`characters` 1.4.1) instead of Unicode
  scalar values. Malayalam vowel signs, combining characters, and emoji
  sequences should not be overcounted by line-width and CPS rules.
- Add deterministic whitespace suggestions. They collapse repeated ASCII
  spaces and trim trailing spaces, preserve explicit blank subtitle lines,
  and retain supported SRT/ASS formatting tags exactly.
- The review dialog separates Issues from Suggested fixes, and displays
  before/after text. All suggestions are **unchecked by default**; users
  choose each proposal explicitly before Apply becomes active.
- The production session applies selected proposals via the existing guarded
  `updateMultipleLinesWithHistory` route, producing one undoable checkpoint.
  The writer rejects stale sources, unknown cue IDs, duplicate IDs, forged
  proposals and no-op changes. It also retains originals, marks and comments.
- Demo/read-only sessions may review fixes, but cannot Apply.

## Deliberate limits

- This checkpoint does not attempt speculative fixes for overlaps, CPS,
  duration, spelling, or malformed timecodes. Those remain diagnostic.
- Presets are named fixed defaults, not a full editable profile designer.
  User-defined numeric limits and language-specific conventions are future
  refinements.
- Native Windows acceptance is deferred until the user's laptop is available.

## Verification

- Tests cover Malayalam grapheme counting, preset thresholds, whitespace
  suggestions, tag/blank-line preservation, explicit UI selection,
  persisted preset choice, and stale/forged-fix rejection.
- Run only `flutter pub get`, Flutter analysis, and Flutter tests in CI;
  never run platform builds in GitHub Actions.
