# SRT encoding expansion: reference implementation study

Date: 2026-10-12
Repository: `anzilr/SubtitleStudio`
Scope: **design/reference research only**. No Flutter codec change, UI change, schema migration or new CI workflow.

## User-supplied reference projects

### KDE Subtitle Composer
- Primary repository: https://invent.kde.org/multimedia/subtitlecomposer.git
- Readable GitHub mirror used for source inspection: https://github.com/KDE/subtitlecomposer
- `src/formats/formatmanager.cpp`: attempts encoding detection with ICU `ucsdet_detectAll` and confidence when built with ICU, or KDE `KEncodingProber`; 100%-confidence outcomes can be accepted automatically, otherwise a detection dialog lets the user choose a codec. Text input is converted to Unicode *before* subtitle format parsing. Writing chooses `QTextCodec`, uses `QSaveFile` for atomic replacement and supports newline style.
- `src/dialogs/encodingdetectdialog.cpp`: shows ranked detected candidates plus the full available encoding catalog, previews the source bytes decoded using the selected codec, enables confirmation on valid selection.
- `src/actions/kcodecactionext.cpp`: separate **Open: Autodetect** and **Save: Current/Default/explicit** encoding choices; groups encodings by language/script through KDE's charset catalog.
- **Adapt ideas, not Qt code**. Avoid copying the code's broad `UTF-/UCS-` BOM rule: SubtitleStudio should *preserve an exact selected BOM policy*. The KDE manager also reads only the first 1 MiB of text into its parser in the inspected revision; do **not** adopt that input truncation.
- Observed per-file SPDX: `GPL-2.0-or-later` for FormatManager/codec action; verify licensing before any source reuse.

### Subtitle Edit (current main)
- https://github.com/SubtitleEdit/subtitleedit
- `src/libse/DetectEncoding/EncodingTools.cs`: uses the `UtfUnknown` charset detector, taking its best-ranked result when available, or an explicit default; empty bytes resolve as ASCII.
- `src/ui/Logic/EncodingHelper.cs`: centralized encoding list plus separate `UTF-8 with BOM` and `UTF-8 without BOM` options, and `Try to use source encoding`. Detecting UTF-8 is not sufficient to recreate the original BOM: it explicitly inspects original bytes before saving.
- `src/libse/Common/TextEncoding.cs`: display model separates code page, label and UTF-8 BOM choice; names/code pages can be resolved to a real encoding.
- `src/ui/Features/Files/ManualChosenEncoding/ManualChosenEncodingViewModel.cs`: manual searchable encoding picker with a live preview of up to 100,000 input bytes. It guesses the initial selection, but makes override easy.
- `src/seconv/Core/LibSEIntegration.cs`: encoding override, fallback, BOM recognition and format-specific encoding save rules; a separate fallback is used only for ambiguous input without valid UTF-8/BOM.
- `tests/UI/Logic/EncodingHelperTests.cs`: source UTF-8 BOM preservation, no-BOM preservation, ASCII no-BOM case, UTF-16 preservation and binary input fallback.
- `tests/seconv/Core/InputEncodingFallbackTest.cs`: BOM precedence, UTF-8 with valid multibyte bytes, Windows-1250 legacy fallback and UTF-8 multibyte character at the end of the file.
- Repository license as reported by GitHub: **MIT**, although check the applicable file headers and third-party dependencies before code reuse.

## SubtitleStudio current limitations (verified at Checkpoint 65)

- `lib/services/subtitle_encoding_decoder.dart`: tries UTF-8 first, then Latin-1 before Windows-1252 and UTF-16. Because Latin-1 can decode all 8-bit byte values, Windows-1252 selection is ordinarily unreachable after Latin-1 succeeds. No explicit detection candidate/confidence/override result. No reliable UTF-16 BOM-first handling.
- `lib/utils/srt_compiler.dart`: only maps UTF-8, Latin-1 and ASCII explicitly, and silently maps unrecognized encoding strings to UTF-8; this can produce SRT files in the **wrong encoding** while keeping misleading metadata.
- The application stores an encoding label in `SubtitleCollection.encoding`; it does not yet track encoding **and BOM and fallback choice** as a complete codec state through every import/export path.

## Recommended Flutter architecture

```
File bytes / Android SAF bytes
  -> SubtitleEncodingService.inspect(rawBytes, sourceLabel?)
     -> deterministic BOM checks (UTF-32/UTF-16/UTF-8 in safe order)
     -> strict UTF-8 validation, distinguish ASCII-only
     -> optional heuristic detector returning candidates + confidence/reason
     -> user override / searchable encoding preview when ambiguous
  -> SubtitleEncodingService.decode(bytes, chosenEncoding, strictPolicy)
  -> SRT parser -> subtitle domain model

Subtitle domain model + source encoding metadata
  -> SrtCompiler.compileText(...)
  -> SubtitleEncodingService.encode(
       text, requestedEncoding, explicitBomPolicy, strictPolicy)
  -> verify encoded bytes with reverse round-trip
  -> atomic file write or validated SAF output
```

**One shared service** should own canonical charset IDs, aliases, bytes↔text conversion, BOM, confidence and encoding availability. UI/import/Source View/compiler/export/Save As must call the same service; avoid platform-duplicated fallback logic.

Proposed types (names are illustrative, not yet implemented):
- `SubtitleEncodingProfile`: canonical charset, BOM (present/absent or explicitly chosen), newline mode, source/provenance and requested policy.
- `SubtitleEncodingCandidate`: charset, confidence or rank, reason and decoded preview.
- `SubtitleEncodingResult`: decoded text, selected profile, warning flags and recovery hints.
- `UnsupportedCharsetException` / `UnrepresentableCharactersException`, **never silently UTF-8 fallback** for a selected unavailable codec.

### Priority and quality gates

1. Strict UTF-8 + BOM-aware UTF-16LE/BE and UTF-8 with/without BOM; make decode and encode symmetric.
2. ASCII, ISO-8859-1, Windows-1252, Windows-1250, Windows-1251, Windows-1256 where the selected platform codec can truly encode **and** decode.
3. Expand script-sensitive regional encodings based on real `.srt` fixtures and runtime support: Shift_JIS, EUC-JP, GB18030, Big5, EUC-KR, etc. Support should be independently capability-checked per platform; never list a codec as usable if export isn't supported.
4. Automatic detection result should be advisory unless a deterministic BOM or strict byte validity allows confidence. **Latin-1 is not a meaningful fallback detector**; language/script heuristics may produce ambiguous candidates. Display a preview and manual override instead of wrong character substitutions.
5. Default new text documents to explicit UTF-8 without BOM; preserve the original encoding and BOM by default for existing files, subject to user confirmation if the text can no longer fit that encoding. For unrepresentable characters, block unsafe saves and offer UTF-8 conversion.
6. Keep import/export file encoding metadata consistent with `.msone` and Isar. Plan any additional BOM/source-preference field as a compatibility-preserving optional metadata migration. Encoding changes are **file/export metadata**, not subtitle text history commits unless the content itself changes.

### Regression fixture matrix

- UTF-8 ASCII-only, UTF-8 multibyte at end-of-file, UTF-8 BOM/no-BOM.
- UTF-16 LE/BE BOM; no-BOM UTF-16 only when confidently recognized or manually selected; NUL bytes must not be misclassified as ordinary text.
- Windows-1252 smart punctuation versus ISO-8859-1 control byte ambiguity.
- Windows-1250 Central European, Windows-1251 Cyrillic, Windows-1256 Arabic, and real non-Latin scripts as supported.
- Malayalam, Arabic RTL, Chinese, Japanese, Korean, emoji: round-trip in UTF-8 and explicit failure on non-representable legacy charset.
- Truncated/corrupt UTF-8 sequences, mixed encodings, invalid byte patterns, empty files and Unicode replacement characters.
- Large files and streaming/byte sampling: never truncate the subtitle input while detecting from a smaller byte sample.
- CRLF, LF and CR preservation; file format delimiters; actual SRT parser/compiled SRT round trip.
- Verify equal file bytes for unmodified source encoding/BOM where format normalization does not intentionally alter output.
- Windows/macOS/Linux/Android/iOS codec availability, Android SAF, and Source View save consistency.

## License and implementation boundary

Study algorithms and UX patterns. Prefer an independently written Dart implementation around permitted/compatible charset libraries. KDE's inspected GPL-2.0-or-later components and Subtitle Edit's MIT repository are not blanket permission to copy code without retaining applicable notices. Third-party ICU, UtfUnknown, and codec libraries have their own licenses and platform build constraints.

## Scheduling

The encoding feature remains a **dedicated future milestone**, independently of the Git-inspired HEAD/branch/bookmark redesign and deferred desktop workspace. This document is a source-grounded research handoff, not an implementation claim. Avoid unnecessary GitHub Actions on documentation-only commits.
