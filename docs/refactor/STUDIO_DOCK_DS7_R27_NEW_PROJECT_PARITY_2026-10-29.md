# Studio Dock DS7 R27 — new-project creation parity

Date: 2026-10-29
Branch: `feature/studio-dock-integration`

## Compared with mobile

Mobile's Create Subtitle sheet offers a subtitle name, SRT text encoding,
an SRT file location and an `.msone` project-file location. Desktop previously
offered only a project name and always stored `UTF-8` with no file locations.

Studio Dock now offers the same encoding choices — UTF-8, ISO-8859-1 and
Windows-1252 — with optional creation-time file locations for both `.srt`
and `.msone`. Leaving **Save SRT and project files now** off preserves the
existing convenient desktop workflow: an Edit Mode project is created inside
SubtitleStudio and file locations can be chosen using Save As later.

## Data and cancellation rules

- The user chooses all requested paths **before** project/session creation.
  Canceling the creation dialog or either location picker does not create a
  session or write any file.
- When saving immediately, both paths are required. Existing destinations
  are refused before session creation; the existing guarded writers also
  reject replacement if a file appears during the save operation.
- The empty SRT is written and linked first. The portable `.msone` document
  is built afterward so that it remembers the real SRT location and encoding.
- If a disk operation fails after project creation, the new Edit Mode project
  remains available in SubtitleStudio. The user is told to finish file
  creation through Save As rather than losing their project.
- Project names reject file-path characters and unsupported `.vtt`/`.ass`/
  `.ssa` extensions. Subtitles remain SRT-only until true format support.

## Tests and follow-up

- Dialog tests cover cancelation, invalid names, default encoding, explicit
  encoding selection, and selecting both paths before enabling Create.
- Repository tests cover encoding persistence, Edit Mode, and name validation.
- On-disk integration verifies Create → save both files → add edited text →
  Save → reopen the files and check the linked SRT and portable document.
- Native Windows/Linux/macOS file pickers and save failure behavior still
  require manual acceptance. Remaining parity work includes full import/
  replace round trips and native video-subtitle extraction with real fixtures.

Verification: prefer the connected VS Code workspace for pull, analysis and
tests. Run GitHub Actions only if that workspace is unavailable; do not run
platform builds in Actions.
