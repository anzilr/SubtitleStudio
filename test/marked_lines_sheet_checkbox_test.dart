import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/app/repositories/app_preferences_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/marked_lines_sheet.dart';

class _Preferences implements AppPreferencesRepository {
  bool showAll = false;

  @override
  Future<bool> getShowAllComments() async => showAll;

  @override
  Future<void> setShowAllComments(bool value) async {
    showAll = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SubtitleLine _line(int number, String text,
    {bool marked = false, String? comment}) => SubtitleLine()
  ..index = number
  ..startTime = '00:00:00,000'
  ..endTime = '00:00:01,000'
  ..original = text
  ..marked = marked
  ..comment = comment;

void main() {
  testWidgets('fully marked SRT effect folds as one review card while '
      'individual frame comments remain accessible', (tester) async {
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cues = [
      for (var i = 1; i <= 3; i++)
        _line(i, 'Tes${List.filled(i, 't').join()}', marked: true,
          comment: i == 2 ? 'Frame note' : null)
          ..startTime = '00:00:0${i - 1},000'
          ..endTime = '00:00:0$i,000',
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(_Preferences()),
      ],
      child: MaterialApp(home: Scaffold(body: MarkedLinesSheet(
        markedLines: cues, allSubtitleLines: cues,
        onLineSelected: (_) {},
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('marked-effect-group-1')),
        findsOneWidget);
    expect(find.textContaining('3 marked frames'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('marked-effect-group-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('marked-effect-frame-2')),
        findsOneWidget);
    expect(find.text('Frame note'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marked lines checkbox toggles unmarked comment rows on and off',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = _Preferences();
    final marked = _line(1, 'Marked cue', marked: true);
    final unmarked = _line(2, 'Comment-only cue', comment: 'Needs review');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(preferences),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MarkedLinesSheet(
            markedLines: [marked],
            allLinesWithComments: [marked, unmarked],
            onLineSelected: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Show:'), findsNothing);
    expect(find.byIcon(Icons.filter_list), findsNothing);
    expect(find.text('Marked cue'), findsOneWidget);
    expect(find.text('Comment-only cue'), findsNothing);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(preferences.showAll, isTrue);
    expect(find.text('Comment-only cue'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(preferences.showAll, isFalse);
    expect(find.text('Comment-only cue'), findsNothing);
    expect(find.text('Marked cue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
