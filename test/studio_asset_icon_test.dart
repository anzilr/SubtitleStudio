import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/widgets/studio_asset_icon.dart';

void main() {
  testWidgets('dictionary, project and amplitude SVGs are declared and load',
      (tester) async {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    const icons = [
      StudioAssetIcons.olam,
      StudioAssetIcons.urban,
      StudioAssetIcons.projectSettings,
      StudioAssetIcons.amplitudeIncrease,
      StudioAssetIcons.amplitudeDecrease,
      StudioAssetIcons.showWaveform,
      StudioAssetIcons.hideWaveform,
      StudioAssetIcons.showVideo,
      StudioAssetIcons.hideVideo,
      StudioAssetIcons.resumeSubtitleFlow,
      StudioAssetIcons.pauseSubtitleFlow,
      StudioAssetIcons.markedLinesSheet,
    ];
    for (final path in icons) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(pubspec, contains('- $path'));
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          for (final path in icons) StudioAssetIcon(path, size: 28),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(StudioAssetIcon), findsNWidgets(icons.length));
    expect(tester.takeException(), isNull);
    // The provided Add Effects artwork must not replace the established icon.
    expect(pubspec, isNot(contains('- assets/add_effects.svg')));
  });
}
