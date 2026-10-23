import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/widgets/subtitle_encoding_picker.dart';

void main() {
  testWidgets('searchable picker filters case-insensitively and selects',
      (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await SubtitleEncodingPicker.show(
            context: context,
            options: const [
              'Auto', 'UTF-8', 'Windows-1256', 'Windows-1251', 'GB18030',
            ],
            selected: 'UTF-8',
            title: 'Import charset',
          );
        },
        child: const Text('Open'),
      ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Import charset'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('encoding-search-field')), '1256');
    await tester.pumpAndSettle();
    expect(find.text('Windows-1256'), findsOneWidget);
    expect(find.text('Windows-1251'), findsNothing);
    await tester.tap(find.byKey(
      const ValueKey('encoding-choice-Windows-1256')));
    await tester.pumpAndSettle();
    expect(result, 'Windows-1256');
    expect(find.text('Import charset'), findsNothing);
  });

  testWidgets('picker cancellation preserves the selection', (tester) async {
    String? result = 'previous';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await SubtitleEncodingPicker.show(
            context: context,
            options: const ['UTF-8', 'GBK'],
            selected: 'UTF-8',
          );
        },
        child: const Text('Pick'),
      ))),
    ));
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('encoding-search-field')), 'not-a-codec');
    await tester.pumpAndSettle();
    expect(find.text('No matching encodings'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
