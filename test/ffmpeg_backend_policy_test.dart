import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/ffmpeg_backend_policy.dart';

void main() {
  group('FFmpegKit platform policy', () {
    test('native backend is selected for every supported OS', () {
      for (final operatingSystem in <String>[
        'android',
        'ios',
        'macos',
        'windows',
        'linux',
      ]) {
        expect(
          FfmpegKitPlatformSupport.supports(operatingSystem),
          isTrue,
          reason: 'Expected native FFmpegKit on $operatingSystem',
        );
      }
    });

    test('does not silently assume native plugins on unsupported OS', () {
      for (final operatingSystem in <String>['fuchsia', 'web', '']) {
        expect(
          FfmpegKitPlatformSupport.supports(operatingSystem),
          isFalse,
        );
      }
    });
  });
}
