import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_srt_import_dialog.dart';

void main() {
  late Directory directory;
  late File source;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('studio_srt_import_');
    source = File('${directory.path}/example.srt');
    await source.writeAsBytes([
      ...'1\n00:00:01,000 --> 00:00:02,000\nIt'.codeUnits,
      0x92, ...'s a preview\n'.codeUnits,
    ]);
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<ValueNotifier<String?>> launch(WidgetTester tester) async {
    final result = ValueNotifier<String?>(null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final choice = await showDialog<String>(
            context: context,
            builder: (_) => StudioDockSrtImportDialog(filePath: source.path),
          );
          result.value = choice ?? 'cancelled';
        },
        child: const Text('Open import options'),
      ),
    ))));
    await tester.tap(find.text('Open import options'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Cancel leaves import untouched', (tester) async {
    final result = await launch(tester);
    expect(find.text('Import SRT'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-cancel')));
    await tester.pumpAndSettle();
    expect(result.value, 'cancelled');
    expect(await source.length(), greaterThan(0));
  });

  testWidgets('encoding selection drives preview and confirmed import choice',
      (tester) async {
    final result = await launch(tester);
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-encoding')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Windows-1252').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-srt-import-preview-text')),
        findsOneWidget);
    expect(find.textContaining('It\u2019s a preview'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-srt-import-confirm')));
    await tester.pumpAndSettle();
    expect(result.value, 'Windows-1252');
  });
}
