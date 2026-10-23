import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/screens/home/services/session_activity_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionActivityStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = SessionActivityStore();
  });

  test('records and loads last-opened timestamps', () async {
    final first = DateTime.utc(2026, 9, 27, 10);
    final second = DateTime.utc(2026, 9, 27, 11);

    await store.markOpened(10, openedAt: first);
    await store.markOpened(20, openedAt: second);

    final result = await store.loadLastOpened();

    expect(result[10], first.millisecondsSinceEpoch);
    expect(result[20], second.millisecondsSinceEpoch);
  });

  test('prunes activity for deleted or unavailable sessions', () async {
    await store.markOpened(10, openedAt: DateTime.utc(2026, 9, 27, 10));
    await store.markOpened(20, openedAt: DateTime.utc(2026, 9, 27, 11));

    final result = await store.loadLastOpened(validSessionIds: {20});
    final persisted = await store.loadLastOpened();

    expect(result.keys, {20});
    expect(persisted.keys, {20});
  });

  test('removeSession deletes only the requested activity entry', () async {
    await store.markOpened(10);
    await store.markOpened(20);

    await store.removeSession(10);

    final result = await store.loadLastOpened();
    expect(result.containsKey(10), isFalse);
    expect(result.containsKey(20), isTrue);
  });

  test('rejects invalid session IDs', () async {
    expect(
      () => store.markOpened(0),
      throwsArgumentError,
    );
    expect(
      () => store.markOpened(-1),
      throwsArgumentError,
    );
  });

  test('recovers safely from malformed persisted activity JSON', () async {
    SharedPreferences.setMockInitialValues({
      'session_last_opened_v1': '{not valid json',
    });

    expect(await store.loadLastOpened(), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_last_opened_v1'), isNull);
  });
}
