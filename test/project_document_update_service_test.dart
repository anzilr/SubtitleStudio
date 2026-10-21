import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/core/file_access/project_document_update_service.dart';
import 'package:subtitle_studio/services/project_file_service.dart';

final class _FakeStore implements ProjectDocumentUpdateStorage {
  _FakeStore({this.isAndroid = false, this.isIos = false,
      this.isWindows = false, this.succeed = true});
  @override
  final bool isAndroid;
  @override
  final bool isIos;
  @override
  final bool isWindows;
  final bool succeed;
  final calls = <String>[];
  String? lastPath;
  String? lastText;
  @override
  Future<bool> writeExistingNativeFile(String path, String text) async {
    calls.add('native');
    lastPath = path;
    lastText = text;
    return succeed;
  }
  @override
  Future<bool> writeAndroidDocument(String uri, String text) async {
    calls.add('document');
    lastPath = uri;
    lastText = text;
    return succeed;
  }
}

void main() {
  const document = '{"projectVersion":"2.0","text":"മലയാളം"}';

  test('desktop and Windows-native identifiers do not change', () async {
    final store = _FakeStore(isWindows: true);
    final updater = ProjectDocumentUpdateService(storage: store);
    for (final path in [
      r'C:\Studio\project.msone', r'\\server\share\project.msone',
      '/home/editor/project.msone',
    ]) {
      expect(await updater.update(projectFilePath: path, content: document),
          isTrue);
      expect(store.lastPath, path);
      expect(store.lastText, document);
    }
    expect(store.calls, ['native', 'native', 'native']);
  });

  test('file URI decodes percent escapes before accessing local file',
      () async {
    const uri = 'file:///tmp/my%20project.msone';
    final store = _FakeStore();
    expect(await ProjectDocumentUpdateService(storage: store)
        .update(projectFilePath: uri, content: document), isTrue);
    expect(store.calls, ['native']);
    expect(store.lastPath, '/tmp/my project.msone');
  });

  test('Android SAF update writes to the original URI only', () async {
    const uri = 'content://com.example.documents/document/a%3Ab.msone';
    final store = _FakeStore(isAndroid: true);
    expect(await ProjectDocumentUpdateService(storage: store)
        .update(projectFilePath: uri, content: document), isTrue);
    expect(store.calls, ['document']);
    expect(store.lastPath, uri);
  });

  test('SAF on another platform and iOS existing files require Save As',
      () async {
    const uri = 'content://com.example.documents/document/x.msone';
    final nonAndroid = _FakeStore();
    expect(await ProjectDocumentUpdateService(storage: nonAndroid)
        .update(projectFilePath: uri, content: document), isFalse);
    expect(nonAndroid.calls, isEmpty);
    final ios = _FakeStore(isIos: true);
    expect(await ProjectDocumentUpdateService(storage: ios)
        .update(projectFilePath: '/ios/project.msone', content: document),
        isFalse);
    expect(ios.calls, isEmpty);
  });

  test('iOS project document update refuses native, file URI and SAF writes',
      () async {
    final ios = _FakeStore(isIos: true);
    final updater = ProjectDocumentUpdateService(storage: ios);
    for (final location in [
      '/private/var/mobile/Documents/project.msone',
      'file:///private/var/mobile/Documents/project.msone',
      'content://provider.example/document/project.msone',
    ]) {
      expect(await updater.update(
        projectFilePath: location, content: document), isFalse);
    }
    expect(ios.calls, isEmpty);
  });

  test('malformed, remote and opaque locators fail without any writes',
      () async {
    final store = _FakeStore(isAndroid: true);
    final updater = ProjectDocumentUpdateService(storage: store);
    for (final locator in [
      '', '  ', 'content://', 'https://host/path/file.msone?secret=1',
      'rtsp://host/a.msone', 'saf:provider-key',
    ]) {
      expect(await updater.update(
        projectFilePath: locator, content: document), isFalse);
    }
    expect(store.calls, isEmpty);
  });

  test('provider or missing-native failures request Save As', () async {
    final store = _FakeStore(isAndroid: true, succeed: false);
    final updater = ProjectDocumentUpdateService(storage: store);
    expect(await updater.update(
      projectFilePath: '/missing/original.msone', content: document), isFalse);
    expect(await updater.update(
      projectFilePath: 'content://provider/document/original.msone',
      content: document), isFalse);
    expect(store.calls, ['native', 'document']);
  });

  test('ProjectFileService delegates without changing public callers',
      () async {
    final store = _FakeStore();
    expect(await ProjectFileService.updateExistingProject(
      content: document, projectFilePath: '/sample/old.msone',
      updater: ProjectDocumentUpdateService(storage: store),
    ), isTrue);
    expect(store.calls, ['native']);
    expect(store.lastText, document);
  });

  test('real native project is updated; absent original never created',
      () async {
    final dir = await Directory.systemTemp.createTemp('cp88_project_file_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final existing = dir.path + Platform.pathSeparator + 'existing.msone';
    await File(existing).writeAsString('before');
    expect(await ProjectFileService.updateExistingProject(
      content: document, projectFilePath: existing,
    ), isTrue);
    expect(await File(existing).readAsString(), document);
    final missing = dir.path + Platform.pathSeparator + 'missing.msone';
    expect(await ProjectFileService.updateExistingProject(
      content: document, projectFilePath: missing,
    ), isFalse);
    expect(await File(missing).exists(), isFalse);
  });
}
