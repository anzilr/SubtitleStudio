import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/source_view/source_view_saf_grant_repository.dart';

final class _FakeSafGrantStore implements SourceViewSafGrantStore {
  final Map<String, String> values = {};
  final List<String> events = [];

  @override
  Future<String?> read(String key) async {
    events.add('read');
    return values[key];
  }

  @override
  Future<void> write(String key, String uri) async {
    events.add('write');
    values[key] = uri;
  }

  @override
  Future<void> remove(String key) async {
    events.add('remove');
    values.remove(key);
  }
}

void main() {
  const path = '/data/user/0/studio/cache/source.srt';
  const original = 'content://test.documents/document/selected%3Asrt';
  const other = 'content://test.documents/document/other%3Asrt';

  test('preserves legacy preference key and existing native-cache grant',
      () async {
    final store = _FakeSafGrantStore();
    final key = SourceViewSafGrantRepositoryImpl.legacyKey(path);
    expect(key, 'saf_uri_$path');
    store.values[key] = original;

    final service = SourceViewSafGrantRepositoryImpl(store: store);
    expect(await service.resolve(filePath: path), original);
    expect(store.events, ['read']);
    expect(store.values[key], original);
  });

  test('explicit user-selected grant overrides stale saved preference',
      () async {
    final store = _FakeSafGrantStore();
    final key = SourceViewSafGrantRepositoryImpl.legacyKey(path);
    store.values[key] = other;
    final service = SourceViewSafGrantRepositoryImpl(store: store);

    expect(await service.resolve(
      filePath: path, providedUri: original,
    ), original);
    expect(store.values[key], original);
    expect(store.events, ['write'],
        reason: 'Do not revive stale metadata when a fresh URI is supplied');
  });

  test('direct content URI resolves itself without any saved metadata',
      () async {
    final store = _FakeSafGrantStore();
    final service = SourceViewSafGrantRepositoryImpl(store: store);

    expect(await service.resolve(filePath: original), original);
    expect(store.events, ['read']);
    expect(store.values, isEmpty);
  });

  test('mismatched legacy URI cannot redirect a direct document', () async {
    final store = _FakeSafGrantStore();
    final key = SourceViewSafGrantRepositoryImpl.legacyKey(original);
    store.values[key] = other;
    final service = SourceViewSafGrantRepositoryImpl(store: store);

    expect(await service.resolve(filePath: original), original);
    expect(store.values.containsKey(key), isFalse);
    expect(store.events, ['read', 'remove']);
  });

  test('corrupt and empty stored grants are pruned without redirection',
      () async {
    for (final invalid in ['content://', 'file:///tmp/foo.srt',
      'https://example.org/other', '']) {
      final store = _FakeSafGrantStore();
      final key = SourceViewSafGrantRepositoryImpl.legacyKey(path);
      store.values[key] = invalid;
      final service = SourceViewSafGrantRepositoryImpl(store: store);
      expect(await service.resolve(filePath: path), isNull);
      expect(store.values, isEmpty);
      expect(store.events, ['read', 'remove']);
    }
  });

  test('a mismatched explicit document grant is rejected before any write',
      () async {
    final store = _FakeSafGrantStore();
    final key = SourceViewSafGrantRepositoryImpl.legacyKey(original);
    store.values[key] = other;
    final service = SourceViewSafGrantRepositoryImpl(store: store);

    await expectLater(
      service.resolve(filePath: original, providedUri: other),
      throwsFormatException,
    );
    expect(store.values[key], other);
    expect(store.events, isEmpty);
  });

  test('invalid caller grant is not persisted for native file', () async {
    final store = _FakeSafGrantStore();
    final service = SourceViewSafGrantRepositoryImpl(store: store);
    await expectLater(
      service.resolve(filePath: path,
          providedUri: 'https://not-a-document.example/uri'),
      throwsFormatException,
    );
    expect(store.values, isEmpty);
  });

  test('direct document can persist its own explicit grant unchanged',
      () async {
    final store = _FakeSafGrantStore();
    final service = SourceViewSafGrantRepositoryImpl(store: store);
    expect(await service.resolve(
      filePath: original, providedUri: original,
    ), original);
    expect(store.values['saf_uri_$original'], original);
  });

  test('distinct file locators retain separate legacy preference identities',
      () async {
    final store = _FakeSafGrantStore();
    final service = SourceViewSafGrantRepositoryImpl(store: store);
    const otherFile = '/data/user/0/studio/cache/other.srt';

    await service.resolve(filePath: path, providedUri: original);
    await service.resolve(filePath: otherFile, providedUri: other);
    expect(await service.resolve(filePath: path), original);
    expect(await service.resolve(filePath: otherFile), other);
    expect(store.values.length, 2);
  });
}
