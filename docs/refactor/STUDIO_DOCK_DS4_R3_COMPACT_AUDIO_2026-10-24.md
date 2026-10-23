# SubtitleStudio — DS4 R3: Compact waveform and selected audio

Date: 2026-10-24
Branch: feature/studio-dock-integration

## Completed scope
- Studio Dock remains the only native Windows/macOS/Linux desktop interface. Android and iOS continue to use their existing mobile workflow.
- The shared WaveformWidget has a new opt-in compact flag (default false), retaining full-size controls for mobile. Studio Dock uses a 28px compact zoom/auto-scroll toolbar, no full-height right amplitude column, and compact initial/loading/error treatments. These keep the waveform interaction surface usable inside the 13% vertical band.
- StudioDockPlaybackLink carries selected audio status: waiting, ready with verified FFmpeg stream selector (or explicit auto), or unavailable. Disposing/detaching media clears the selection, and waveform never owns a second player.
- StudioDockVideoSurface resolves the selected mpv track with the production VideoPlayerWidgetState.resolveWaveformSelectedAudioStream() mapping (mpv track-list FFmpeg global stream index); it rejects ambiguous/missing metadata and ignores out-of-order async callbacks.
- Waveform now reloads when the verified audio selection changes, clears previous track samples while waiting, shows a safe error if unresolved, and uses existing cancellation epochs to prevent stale decode from reappearing.
- LoadAudioFile.useSavedAudioTrackPreference defaults true for existing mobile behavior. Studio Dock explicitly sets it false, so an auto-selected audio track cannot accidentally decode an older persisted track ID.
- Existing WaveformSeekCoordinator continues to own bounded scrubbing and exact final seeks. No duplicate native media player, alternative waveform decoder, or classic Editor navigation was introduced.

## Tests and gates
- Added short-band waveform ready/loading/error widget regressions, including toolbar controls and RenderFlex overflow safety.
- Added audio selection state tests for auto, verified FFmpeg stream and unavailable metadata, plus legacy preference behavior.
- Run full analyzer and Studio Dock focused tests using Flutter GitHub Actions only; no native app builds.
- Previous DS4 R2 full suite passed: 848 tests, zero analyzer issues, https://github.com/anzilr/SubtitleStudio/actions/runs/40031142194

## Native acceptance and outstanding work
- Windows host still required to verify waveform actual source decoding, playhead sync, selected audio track switching (two-track MKV preferred), 13% height rendering at 1366x768 and 1920x1080, playing/paused scrubbing, and media switch disposal.
- Native selected-track metadata may be unavailable for some containers; the waveform must show an error rather than fake a stream while video remains usable.
- DS4 R4 after native feedback: improve compact layout further only if necessary. DS5: checkpoint-backed cue insertion/timing/style/notes and native Save/Export, solely in Studio Dock.