# SubtitleStudio — DS4 R2: Production Waveform in Studio Dock

Date: 2026-10-24
Branch: feature/studio-dock-integration

## Architecture
- Studio Dock remains the only desktop interface on Windows, Linux and macOS; mobile editor remains unchanged.
- StudioDockPlaybackLink carries video position, playing state, and seek requests. Only VideoPlayerWidgetState owns the existing media_kit player; the waveform owns none.
- VideoPlayerSection forwards the existing player position and play state. StudioDockVideoSurface attaches the existing seekTo method, detaching it on disposal.
- StudioDockWaveformSurface uses the existing WaveformWidget and Riverpod controller, loading the associated media through LoadAudioFile. Processing, cache, progress, scrub and seek-coordinator logic remain in the established waveform feature.
- The production waveform replaces the placeholder in the 43/13/44 balanced Studio Dock when a valid saved video exists; otherwise the disconnected message remains.
- Live player position updates rebuild the waveform only. The production Widget State remains stable through section navigation and resizing.
- Waveform direct time-edit/add-line persistence is intentionally disabled until shared checkpoint transactions are wired.

## Verification and limits
- New test verifies seek forwarding, detach and dispose semantics, and no video or waveform remount during Studio Dock navigation.
- Flutter CI only: dependency resolution, analyze, test. No native builds in GitHub Actions.
- Native Windows still needs media + audio test for waveform rendering, playhead accuracy, paused/play scrub and wheel seek, zoom and resizing, repeated project switching, and selected audio tracks.
- DS4 R3 will refine audio-track metadata, duration, waveform sizing and native acceptance.
- DS5 will implement add/delete/split cues, timing/style/notes and external Save/Export within Studio Dock. Never fall back to classic desktop UI.