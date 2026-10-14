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
