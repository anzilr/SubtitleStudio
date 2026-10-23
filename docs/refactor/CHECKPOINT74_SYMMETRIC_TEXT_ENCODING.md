# Checkpoint 74 — Symmetric subtitle text encodings

Date: 2026-10-14
Branch: `refactor/riverpod-architecture`
Baseline: Checkpoint 73 R2 — 291 tests, zero analyzer issues.

## Implementation
- Added pure-Dart portable `SubtitleTextCodec` for both decoding and encoding.
  It retains BOM policies in the existing SubtitleCollection.encoding string
  without a database schema migration.
- Autodetection accepts only deterministic UTF-8/UTF-16 BOM signals or
  strictly valid UTF-8. Ambiguous 8-bit legacy text is not guessed.
- Supported round-trip encodings: UTF-8 with/without BOM, UTF-16LE/BE with/
  without BOM, ASCII, ISO-8859-1, Windows-1252. Invalid UTF-8, truncated
  UTF-16, bad surrogate pairs, Windows-1252 undefined bytes and characters
  unrepresentable in the target encoding fail explicitly.
- Android SAF, desktop and iOS subtitle picker passes raw bytes to the
  subtitle import screen; users can select the source encoding. The parser
  persists that encoding in the session's SubtitleCollection.
- SRT compiler and Android/iOS save dialogs use the same byte encoder, no
  silent UTF-8 fallback. Export UI includes all supported encodings.
- Tests cover byte roundtrips, Unicode scripts, malformed inputs, SRT
  parser/compiler roundtrips and full files greater than five MiB.

## Boundaries
- Windows-1250/1251/1256 and regional multibyte codecs (Shift_JIS, GB18030,
  Big5, EUC-JP, EUC-KR) are deliberately deferred until both directions have
  validated implementations.
- Non-BOM UTF-16 and ambiguous 8-bit encoding require manual selection.
  No heuristic language detection in this checkpoint.
- Older intent callers which supply only a decoded string cannot restore
  source bytes. A follow-up should migrate those to raw-byte parsing.
- A recompiled SRT may normalize cue syntax/line endings; byte-for-byte
  equality is only promised by the unmodified text codec.
- Native Android/iOS/macOS/Windows/Linux file-dialog testing remains pending.

Reference: SRT_ENCODING_REFERENCE_RESEARCH_2026-10-12.md.

## Verified gate (Checkpoint 74 R2)

- **299 tests passed**, up from 291 in Checkpoint 73.
- **0 analyzer issues** (no errors, warnings or info notices).
- [Code commit `218a509`](https://github.com/anzilr/SubtitleStudio/commit/218a5094b48ab80fb58355009a80ccce4a1ef013).
- [GitHub Actions success, run 38587191118](https://github.com/anzilr/SubtitleStudio/actions/runs/38587191118).
- R1 passed the 299-test suite, but analyzer reported two informational
  redundant Dart imports. R2 removed them and passed both gates.
- Only the refactoring experiment branch was changed. Documentation-only
  commits after the quality gate do not rerun the checkpoint CI.

## Recommended follow-on checkpoint

Target a **regional encoding expansion and remaining raw-byte input audit**:
Windows-1250/1251/1256 with reversible test fixtures, plus Android intent
inputs that still decode text before entering the common subtitle parser.
Do not introduce platform-specific codec availability mismatches or silently
replace unrepresentable text. Waveform tuning remains separately scheduled.
