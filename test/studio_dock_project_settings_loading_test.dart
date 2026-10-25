import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/project_settings_sheet.dart';

import 'support/test_isar_harness.dart';

void main() {
  testWidgets('project settings uses the already-loaded subtitle collection',
      (tester) async {
    final harness = await TestIsarHarness.open();
    addTearDown(harness.close);

    // This collection deliberately does not exist in the database. The
    // opening sheet must use its supplied lines for stats and review marks,
    // rather than issuing another large fetchLines/getMarkedLines round trip.
    final collection = SubtitleCollection(
      fileName: 'cached.srt',
      encoding: 'UTF-8',
      lines: [
        SubtitleLine()
          ..index = 1
          ..original = 'Original'
          ..edited = 'Translated'
          ..marked = true,
        SubtitleLine()
          ..index = 2
          ..original = 'Second original',
      ],
    )..id = 7411;
    final session = Session(
      fileName: 'cached.srt', subtitleCollectionId: collection.id,
    )..id = 7412;

    await tester.pumpWidget(ProviderScope(
      overrides: [isarProvider.overrideWithValue(harness.isar)],
      child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(
        width: 880,
        height: 750,
        child: ProjectSettingsSheet(
          session: session,
          subtitleCollection: collection,
          onProjectUpdated: () {},
        ),
      )))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Project Statistics'), findsOneWidget);
    expect(find.text('Total Lines'), findsOneWidget);
    expect(find.text('Edited Lines'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('1 line marked'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
