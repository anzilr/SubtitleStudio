import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('optimized splash WebP is declared, decodable and wired to the UI',
      () async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final splash = File('lib/widgets/splash_screen.dart').readAsStringSync();
    expect(pubspec, contains('assets/msone_bg.webp'));
    expect(splash, contains("'assets/msone_bg.webp'"));
    expect(pubspec, isNot(contains('assets/msone_bg.jpg')));
    expect(splash, isNot(contains('assets/msone_bg.jpg')));

    final asset = await rootBundle.load('assets/msone_bg.webp');
    final codec = await ui.instantiateImageCodec(
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
    );
    addTearDown(codec.dispose);
    final frame = await codec.getNextFrame();
    addTearDown(frame.image.dispose);
    expect(frame.image.width, 1200);
    expect(frame.image.height, 2100);
  });
  test('brand logo and compact Studio Dock mark are available and wired',
      () async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final splash = File('lib/widgets/splash_screen.dart').readAsStringSync();
    final studio = File('lib/desktop/workspace/studio_dock_workspace.dart')
        .readAsStringSync();

    const fullLogo = 'assets/subtitle_studio_logo.png';
    const toolbarMark = 'assets/subtitle_studio_brand_icon.png';
    expect(pubspec, contains(fullLogo));
    expect(pubspec, contains(toolbarMark));
    expect(splash, contains("'$fullLogo'"));
    expect(studio, contains("'$toolbarMark'"));

    for (final path in [fullLogo, toolbarMark]) {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      addTearDown(codec.dispose);
      final frame = await codec.getNextFrame();
      addTearDown(frame.image.dispose);
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
    }
  });
}
