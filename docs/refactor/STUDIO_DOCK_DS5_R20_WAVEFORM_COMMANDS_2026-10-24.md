# SubtitleStudio — DS5 R20 Direct Waveform Controls

Date: 2026-10-24
Branch: feature/studio-dock-integration

## Audit finding

Mobile exposes Generate/Hide and Regenerate Waveform in the Edit main menu.
Studio Dock previously rendered the waveform automatically but offered no direct control.

## Implemented behavior

The real StudioDockWaveformSurface now shows a compact toolbar above its
existing WaveformWidget, using its original session-scoped Riverpod provider.

- Hide removes the graph but retains the controller, playback and toolbar.
- Generate reveals it using the loaded waveform or ongoing track load; it
  does not start a duplicate decode solely due to visibility changes.
- Regenerate is enabled when the player has resolved an audio track. It clears
  the same persisted PCM cache as mobile, dispatches ClearWaveform and reloads
  with LoadAudioFile, retaining the selected FFmpeg stream selector and
  useSavedAudioTrackPreference=false.
- A busy regeneration disables command buttons; errors are displayed inline.
- Media, collection and audio selection are rechecked before reloading.
- No new media_kit player is created or remounted. The current waveform
  still controls seek, subtitle time edits, zoom and source highlight.

## Validation and limits

Four focused widget tests cover visibility, Generate, Regenerate, player
audio-track prerequisite and busy-state gating without requiring native FFmpeg.
Real waveform extraction, Isar cache deletion, compact peak-cache behavior,
selected track accuracy and controller lifetime remain native/integration
acceptance items—not proven by toolbar-only widget tests.

Floating video controls, repeat/range playback and line-format/dictionary
shortcuts remain on the parity ledger; do not call parity complete.

GitHub CI: flutter pub get, flutter analyze, focused/full flutter test only.
No platform builds or live MSone submissions. Mobile UI is unchanged.
