# CP89 R3 — Preserve blank cues and blank text lines when importing/opening

Date: October 21, 2026

Branch: `refactor/riverpod-architecture`

## Reported regression

An intentionally empty numbered SRT cue was silently dropped on import. The
main import parser only finalized entries with a nonempty text line. It also
treated *every* blank line as the end of a cue, so internal empty text lines
could be lost. Source View and secondary subtitle open used a separate parser
which likewise stopped reading cue text at the first blank line. The Editor's
strict raw-SRT Save path had a third indiscriminate blank-line split.

## Implemented

- The shared `SubtitleParser.parseSrt` now discovers cue boundaries from the
  next valid timestamp header (numbered or unnumbered) rather than from every
  blank line. Empty captions are valid; interior blank lines and text
  indentation are preserved. A single structural blank separator is removed;
  extra blank lines remain content. A final newline is treated as a line
  terminator. Whitespace-only text at EOF without a separator stays intact.
- `subtitle_processor` imports from this shared parser. It retains empty
  cues, SRT legacy 1–3 digit millisecond inputs, and original multiline text.
  Timestamp punctuation/width still normalizes for the existing editor data
  model; no Isar or `.msone` schema change is necessary.
- Optional hearing-impaired cleanup no longer removes an *already empty* cue
  or deliberately blank lines in an otherwise retained caption. Content that
  becomes empty solely through requested annotation removal is still omitted.
- `SubtitleEntry` can parse a numbered cue with no text and no longer trims
  cue content. `RawSrtDocument.parseStrict` recognizes numbered cue boundaries
  after separators so an empty line inside a cue is not split into an invalid
  block; malformed numbered timing remains rejected.
- Source View continues to retain the original unmodified raw bytes, BOM and
  CRLF/newline style from CP89 R1 while its parsed cue list now shows the
  actual blank captions and internal line breaks.

## Automated checks

- Shared SRT parser: empty cues, CRLF, internal/leading/trailing blank text
  lines, padded text, short millisecond values and whitespace-only EOF text.
- Real import service → Isar persistence → strict export → parser: retains the
  same cue count, blank text, whitespace and multiline content.
- Source View opening: parsed blank cue list alongside lossless raw Save.
- Editor raw source and individual cue parser: blank cue and multiline
  round-trip with strict malformed-cue rejection.
- Optional hearing-impaired cleanup: preexisting empty cues and blank text
  lines survive.
- Because import/open/save logic changed, run Linux full Flutter analyzer
  and tests, plus focused Windows and macOS host Flutter checks. Native iOS
  document behavior remains subject to the separate CP93 acceptance gate.

## Status and known limits

- Flutter SDK is unavailable in this workspace; GitHub Flutter-only CI is
  the executable verification gate for this change.
- First Linux check reported one existing hearing-impaired cleanup regression:
  deleting a leading annotation left an unintended newline. The cleanup now
  removes artifact edge newlines unless the original cue had blank edge lines;
  new regression cases cover both. Verification must use the updated rerun.
- [Corrected Linux full CI run 39644802316](https://github.com/anzilr/SubtitleStudio/actions/runs/39644802316):
  **635 tests passed**, analyzer successful.
- [Corrected platform-sensitive CI run 39644802337](https://github.com/anzilr/SubtitleStudio/actions/runs/39644802337):
  **Windows 104 tests passed**, analyzer successful. macOS was still queued at
  this report update, so its result is not yet accepted.
- No Android/iOS/Windows/macOS/Linux app builds ran in GitHub Actions.
- Generic SRT cannot unambiguously distinguish every surplus separator blank
  from an intentional leading or trailing empty text line. The rule here is
  deterministic: one blank separator, extras retained as text. The raw Source
  View remains appropriate for byte-exact layout preservation.
- Importing into Isar still converts line endings to `\n` within cue text;
  export follows the SRT serializer's newline policy. Byte-exact newline
  preservation across full import → structured edit → export would require an
  explicit metadata/compatibility design and remains open.
- Next: finish remaining charset-fixture verification, then CP90 Editor
  ownership refactor, CP91 checkpoint/compact editing UX, CP92 cleanup and
  CP93 native acceptance. Waveform experimentation stays deferred; desktop
  UI preview remains isolated.
