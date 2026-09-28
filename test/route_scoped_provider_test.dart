import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/screens/edit/edit_controller.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';
import 'package:subtitle_studio/screens/source_view/source_view_controller.dart';

void main() {
  testWidgets(
    'editor controller uses configuration from nested ProviderScope',
    (tester) async {
      int? collectionId;
      int? sessionId;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProviderScope(
              overrides: [
                editConfigurationProvider.overrideWithValue(
                  const EditConfiguration(
                    subtitleCollectionId: 123,
                    sessionId: 456,
                  ),
                ),
              ],
              child: Consumer(
                builder: (context, ref, child) {
                  final controller =
                      ref.watch(editControllerProvider.notifier);
                  collectionId = controller.subtitleCollectionId;
                  sessionId = controller.sessionId;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(collectionId, 123);
      expect(sessionId, 456);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edit-line controller uses configuration from nested ProviderScope',
    (tester) async {
      int? sessionId;
      bool? isNewSubtitle;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProviderScope(
              overrides: [
                editLineConfigurationProvider.overrideWithValue(
                  const EditLineConfiguration(
                    subtitleCollectionId: 12,
                    lineIndex: 3,
                    sessionId: 789,
                    isNewSubtitle: true,
                    isEditMode: true,
                  ),
                ),
              ],
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(editLineControllerProvider);
                  sessionId = state.sessionId;
                  isNewSubtitle = state.isNewSubtitle;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(sessionId, 789);
      expect(isNewSubtitle, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source-view controller uses configuration from nested ProviderScope',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      String? filePath;
      String? displayName;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProviderScope(
              overrides: [
                sourceViewConfigProvider.overrideWithValue(
                  const SourceViewConfig(
                    filePath: '/tmp/scoped-test.srt',
                    displayName: 'scoped-test.srt',
                    fileContent:
                        '1\n00:00:00,000 --> 00:00:01,000\nHello\n',
                  ),
                ),
              ],
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(sourceViewControllerProvider);
                  filePath = state.filePath;
                  displayName = state.displayName;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(filePath, '/tmp/scoped-test.srt');
      expect(displayName, 'scoped-test.srt');
      expect(tester.takeException(), isNull);
    },
  );

}
