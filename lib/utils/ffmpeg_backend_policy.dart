/// Centralized FFmpegKit platform policy for subtitle extraction and waveforms.
///
/// The package ships native FFmpeg/FFprobe implementations for these operating
/// systems. Architecture availability remains governed by the plugin's
/// supported binary targets (currently desktop x86_64, plus macOS arm64).
abstract final class FfmpegKitPlatformSupport {
  static const Set<String> supportedOperatingSystems = <String>{
    'android',
    'ios',
    'macos',
    'windows',
    'linux',
  };

  static bool supports(String operatingSystem) =>
      supportedOperatingSystems.contains(operatingSystem);
}
