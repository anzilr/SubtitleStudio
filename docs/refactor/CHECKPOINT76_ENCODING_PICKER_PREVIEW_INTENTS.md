# Checkpoint 76 — Encoding picker, preview and intent safety

Date: 2026-10-14
Branch: `refactor/riverpod-architecture`
Baseline: Checkpoint 75 R2, 303 passing tests, analyzer 0.

## Work implemented

- Added a reusable searchable charset dialog used by both subtitle import
  and export screens. Results are lazily rendered and searched without
  assuming all OS codecs are supported. Only runtime-verified choices
  are selectable, with a cancel action.
- Import now offers an on-demand decoded-text preview. Preview and final
  import share the same raw-byte reader and
  `SubtitleExtendedEncodingService`, avoiding inconsistent guesses.
  The display is limited to 500 *Unicode code points after decoding*,
  not 500 source bytes, so it cannot cut multibyte sequences.
- Android intent helpers expose `readBytesFromUri` and
  `readBytesFromIntentFile` and use strict explicit decoding for
  backwards-compatible String helpers. Removed the old implicit
  UTF-8-to-Latin-1 fallback, which could scramble smart punctuation and
  other legacy character sets. All import flows reaching the main
  import screen now read source bytes directly.
- Added 18 more optional native-codec candidates (DOS IBM regional pages,
  MacCyrillic/Greek/Turkish/Central Europe, GB2312, EUC-TW,
  HZ-GB-2312 and ISO-2022-KR). Together with Checkpoint 75's
  40 native candidates and Checkpoint 74's 9 portable profiles there
  are now 67 *candidates*, not 67 guaranteed working codecs.
- Runtime probing tests non-ASCII script samples for additional families;
  each actual conversion also demands a strict full roundtrip. This
  sacrifices noncanonical legacy byte sequences rather than silently
  changing them.
- New tests cover picker search/cancel, BOM and Unicode previews,
  malformed legacy input, Unicode-codepoint truncation, raw intent-file
  bytes and explicit Windows-1252 source decoding.

## Limitations and follow-up

- Native plugin reach varies across Android, iOS, Windows, macOS and Linux.
  OS/device-level verification is still necessary; Flutter test cannot
  certify the native conversions or Android intent URI channel.
- Preview currently reads and decodes all source bytes but displays a
  bounded string. Future work may use isolated chunked streaming for
  extremely large subtitle files (subject to multibyte boundaries).
- Charset search is a direct list filter, not confidence-ranked automatic
  language detection. A decoded preview can be linguistically incorrect
  even if bytes roundtrip under the wrong single-byte code page.
- A wider set of candidates is possible, but only bidirectionally validated
  native charsets are exposed on each device. No GPL source was copied
  from Subtitle Composer or Subtitle Edit.
- A separate desktop workspace remains deferred. Existing mobile layout
  is changed only in the encoding selector and preview surface.
