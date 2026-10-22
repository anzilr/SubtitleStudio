import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/history_reference_naming.dart';

void main() {
  test('branch and bookmark names follow portable history naming rules', () {
    expect(HistoryReferenceNaming.isValid('refs/heads/review-fixes', 'branch'),
        isTrue);
    expect(HistoryReferenceNaming.isValid('refs/heads/review/part_2', 'branch'),
        isTrue);
    expect(HistoryReferenceNaming.isValid('refs/bookmarks/before-final',
        'bookmark'), isTrue);
    expect(HistoryReferenceNaming.isValid('HEAD', 'head'), isTrue);
    expect(HistoryReferenceNaming.isValid('refs/heads/Review Notes', 'branch'),
        isFalse);
    expect(HistoryReferenceNaming.isValid('refs/heads/part..lock', 'branch'),
        isFalse);
    expect(HistoryReferenceNaming.isValid('refs/heads/review//next', 'branch'),
        isFalse);
    expect(HistoryReferenceNaming.isValid('refs/heads/review', 'bookmark'),
        isFalse);
  });

  test('validation explains names that cannot be saved', () {
    expect(HistoryReferenceNaming.validationError(
        'refs/heads/My New Branch', 'branch'),
        contains('hyphens or underscores instead of spaces'));
    expect(HistoryReferenceNaming.validationError('refs/heads/', 'branch'),
        contains('Enter a name'));
    expect(HistoryReferenceNaming.validationError(
        'refs/heads/review?', 'branch'), contains('letters, numbers'));
    expect(HistoryReferenceNaming.validationError(
        'refs/heads/${List.filled(181, 'a').join()}', 'branch'),
        contains('too long'));
  });
}
