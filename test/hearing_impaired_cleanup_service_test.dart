import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/services/hearing_impaired_cleanup_service.dart';

SubtitleLine _line({
  required int index,
  required String original,
  String? edited,
  bool marked = false,
  String? comment,
  bool resolved = false,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = original
    ..edited = edited
    ..marked = marked
    ..comment = comment
    ..resolved = resolved;
}

void main() {
  group('HearingImpairedCleanupService.buildPlan', () {
    test('reports deletes and modifications accurately', () {
      final plan = HearingImpairedCleanupService.buildPlan([
        _line(index: 1, original: '[door slams]'),
        _line(index: 2, original: 'JOHN: Hello'),
        _line(index: 3, original: 'Keep this'),
      ]);

      expect(plan.result.originalCount, 3);
      expect(plan.result.removedCount, greaterThanOrEqualTo(1));
      expect(plan.result.remainingCount, plan.cleanedLines.length);
      expect(
        plan.deltas.where((delta) => delta.changeType == 'delete').length,
        plan.result.removedCount,
      );
    });

    test('preserves comment metadata in modified delta snapshots', () {
      final plan = HearingImpairedCleanupService.buildPlan([
        _line(
          index: 1,
          original: 'JOHN: Hello',
          marked: true,
          comment: 'review',
          resolved: true,
        ),
      ]);

      final modify = plan.deltas.single;
      expect(modify.changeType, 'modify');
      expect(modify.beforeState?.marked, isTrue);
      expect(modify.beforeState?.comment, 'review');
      expect(modify.beforeState?.resolved, isTrue);
      expect(modify.afterState?.marked, isTrue);
      expect(modify.afterState?.comment, 'review');
      expect(modify.afterState?.resolved, isTrue);
    });
  });
}
