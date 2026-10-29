# Studio Dock DS7 R25 — video subtitle extraction parity

Date: 2026-10-29
Branch: `feature/studio-dock-integration`

## Desktop feature path

- Studio Dock now exposes **Extract subtitles from video** in File, the
  desktop toolbar (with narrow-layout overflow), the project chooser, and
  the empty desktop landing screen.
- Reuses the existing mobile extraction sheet and FFmpeg conversion flow,
  including video selection, subtitle-track selection, hearing description
  cleanup, overlapping line handling, and saving an extracted `.srt`.
- Successful extraction opens the persisted session inside Studio Dock,
  including when starting from an empty project catalog. No classic Home or
  Editor route is pushed.
- An unsaved inspector draft requires confirmation before launching the
  extraction flow. Cancel leaves the working project unchanged.

## Shared extraction correctness

- Track filtering only offers text subtitle codecs that can be converted to
  SRT. DVD/DVB/PGS and other bitmap/image subtitle streams are excluded.
- Captures repository references before the sheet closes so the asynchronous
  extraction cannot read Riverpod's disposed widget reference.
- On Windows/Linux, missing system FFmpeg/FFprobe now produces a usable
  dependency message instead of a generic video-selection failure.
- Fixed an existing Windows-only privacy test assertion that compared a
  normalized destination path against unnormalized separators.

## Coverage and limitations

- Widget tests cover File/toolbar exposure, unsaved-draft guarding, and the
  desktop landing's extraction completion/open-session transition.
- Unit tests cover text vs bitmap codec filtering.
- The extraction flow and its on-disk FFmpeg behavior still need a real
  Windows/Linux/macOS video fixture and native acceptance. Windows/Linux
  require `ffmpeg` and `ffprobe` on PATH; macOS uses the existing native
  FFmpeg implementation. Bitmap/OCR extraction remains unsupported.
- Export is SRT-only; this does not enable general VTT/ASS project import.

## Next parity priorities

- Optional `.msone` saving during SRT import, as offered on mobile.
- New-project name, encoding, and initial SRT location consistency.
- Complete native round-trip tests for SRT Save, Save As, Export, `.msone`
  Replace/Import As New, source relinking, and session resume.

Verification policy: pull and run Flutter analysis/tests in the connected
VS Code workspace; GitHub Actions only when VS Code is unavailable. No
platform builds in GitHub Actions.
