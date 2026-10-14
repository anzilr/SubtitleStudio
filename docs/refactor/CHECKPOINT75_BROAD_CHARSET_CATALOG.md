# Checkpoint 75 — Wider subtitle encoding catalog

Date: 2026-10-14
Branch: `refactor/riverpod-architecture`
Baseline: Checkpoint 74 R2, 299 tests, analyzer 0.

## Reference research and implementation

The 2026-10-12 encoding study of KDE Subtitle Composer and Subtitle Edit
already identified their broad user-selectable charset lists, ranked/optional
detection, source-encoding preservation and independent save charset.
Checkpoint 75 expands the choices without embedding GPL source code.

The preexisting `charset_converter: ^2.3.0` plugin can use native OS text
codecs. It supports platform-specific aliases/availability, so the app cannot
truthfully show every listed encoding on all OSes. A new injectable
`SubtitleExtendedEncodingService` probes BOTH directions with script-specific
samples and lists only those codecs available locally, atop the portable
Checkpoint 74 Unicode/Latin-1/Windows-1252 tier.

40 **candidate** legacy encodings are researched and registered:
- Windows-1250/1251/1253/1254/1255/1256/1257/1258;
- ISO-8859-2 through -11 (excluding nonexistent -12), plus -13 to -16;
- KOI8-R/U, IBM437/850/852/855/866/874, Macintosh;
- Shift_JIS, EUC-JP, ISO-2022-JP, EUC-KR, GBK, GB18030,
  Big5, Big5-HKSCS and TIS-620.

Including Checkpoint 74's nine portable encoding/BOM profiles, there are
**49 candidate profiles**, but runtime-exposed totals depend on device and
working platform converter registrations.

## Reliability
- Existing strict automatic BOM/UTF-8 detection stays unchanged. Ambiguous
  bytes are not guessed as an arbitrary Windows/ISO code page.
- Import and both desktop/Android SAF/iOS exports invoke the same async
  codec service. Availability is checked, and conversions are verified by a
  reverse roundtrip to reject replacement-character substitutions.
- Encoding failures must not silently switch to UTF-8, and desktop file
  writes encode their full content before opening the destination.
- Dropdowns are populated from runtime-verified available encodings; an
  imported charset missing on this platform is retained as unavailable,
  requiring deliberate conversion instead of silent relabeling.
- The native conversion adapter is injectable for deterministic unit testing
  without platform channels; fixtures use independently specified bytes for
  CP1250, CP1251, CP1256, Shift_JIS, EUC-KR and GB18030.

## Remaining limitations / qualification
- Runtime plugin implementations differ by OS; macOS support in the pinned
  2.3.0 release is not established here and may expose only portable codecs.
- Strict byte roundtrip may reject noncanonical but valid multibyte byte
  sequences, intentionally favoring data preservation over auto-normalizing.
- Charset detection confidence heuristics and preview/ranked candidates
  remain future UI work.
- Existing legacy intent paths returning String instead of raw bytes need
  a separate audit; core SAF/desktop file import already uses bytes.
- Additional charsets may be possible as plugins/platform capability matures.
- Real Android/iOS/Windows/Linux/macOS native tests and project backup
  compatibility tests remain outstanding.

References:
- docs/refactor/SRT_ENCODING_REFERENCE_RESEARCH_2026-10-12.md
- https://invent.kde.org/multimedia/subtitlecomposer.git
- https://github.com/SubtitleEdit/subtitleedit.git
- https://pub.dev/packages/charset_converter/versions/2.3.0
