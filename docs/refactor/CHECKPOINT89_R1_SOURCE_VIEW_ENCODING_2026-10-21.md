# CP89 R1 — Source View encoding round-trip

Date: October 21, 2026

Branch: `refactor/riverpod-architecture`

Base: CP88 R9 (`27e96e91f710fa1108f921d2f292d24198b332c9`)

## Changes

- Source View reads bytes using the same `SubtitleExtendedEncodingService`
  as subtitle import/export, instead of silently interpreting malformed UTF-8
  as Latin-1. BOMs and strict UTF-8 are recognized automatically; ambiguous
  legacy files require the user to choose their charset.
- Source View state stores the canonical encoding name rather than Dart's
  limited `Encoding` object; this preserves `UTF-8 BOM`, `UTF-16LE BOM`,
  `UTF-16BE BOM`, and the portable/OS-supported legacy codec names.
- The Source View app bar displays the active encoding and offers **Open with
  encoding**. Options are queried from the installed codec, including only
  bidirectionally verified native code pages. Reopening refuses to discard
  unsaved raw edits.
- Save and Save As encode the original raw SRT text, maintaining its BOM and
  line endings without generating normalized cue text. Unrepresentable edits
  fail before writing, and before an Android Save As document is created.
- Android Home opens Source View using the selected authoritative `content://`
  URI without pre-decoding bytes (or quietly choosing Latin-1).
- Load errors remain visible, with an encoding-choice recovery action. Logs
  no longer stringify path-bearing write exceptions or selected Save As names.
- Added fake-backed controller regressions for Unicode, Arabic, Malayalam,
  UTF-8/UTF-16 BOMs, Windows-1252 and Windows-1251, unsaved edits, failed
  character conversion, and exact Save/Save As byte round trips.

## CI policy change requested by user

- `.github/ci-checkpoint` triggers the full Linux Flutter analyzer and tests.
- `.github/ci-cross-platform-checkpoint` separately opts in to focused host
  Windows and macOS Flutter analyzer/tests for platform-sensitive changes,
  such as file management, saving, importing, extracting and encoding.
- iOS adapter scenarios are exercised in the focused suite but **do not**
  represent a native iOS build or iPhone/iPad Files-provider acceptance.
- Neither workflow compiles/packages native apps. Those tests remain local.

## Verification

- Local `git diff --check`: passed.
- Flutter/Dart SDK unavailable in this workspace; authoritative Linux and
  Windows/macOS CI results to be recorded after GitHub runs.

## Remaining CP89 work

1. Share the same explicit/manual encoding choice with the import/editor and
   exported subtitle flows; test malformed and substitution-prone converters.
2. Review raw line-ending preservation across editor/database compilation,
   not just the Source View byte-preserving path.
3. Test large files, selection/reload UX and all supported language families;
   clarify when user-initiated conversion to UTF-8 is needed.
4. Native Android/Windows/macOS/iOS picker/provider, grant, Save As and app
   lifecycle acceptance remains open from CP88/CP93.
