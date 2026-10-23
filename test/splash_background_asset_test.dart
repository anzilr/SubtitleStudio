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
}
