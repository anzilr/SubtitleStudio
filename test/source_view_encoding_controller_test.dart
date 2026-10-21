import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/source_view/source_view_controller.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_access.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_target.dart';
import 'package:subtitle_studio/screens/source_view/source_view_saf_grant_repository.dart';
import 'package:subtitle_studio/screens/source_view/source_view_state.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';

const _srtHeader = '1\r\n00:00:01,000 --> 00:00:02,000\r\n';

class _MemorySourceFiles implements SourceViewFileAccess {
  _MemorySourceFiles(this.original);

  final Uint8List original;
  Uint8List? lastWrite;
  Uint8List? lastSaveAsWrite;
  int reads = 0;
  int createRequests = 0;

  @override
  Future<Uint8List> read(SourceViewFileTarget source) async {
    reads++;
    return Uint8List.fromList(original);
  }

  @override
  Future<SourceViewSaveDestination?> write(
      SourceViewFileTarget source, Uint8List bytes) async {
    lastWrite = Uint8List.fromList(bytes);
    return SourceViewSaveDestination.nativeFile;
  }

  @override
  Future<SourceViewCreatedDocument?> createDocument({
    required String fileName,
    required String mimeType,
  }) async {
    createRequests++;
    return const SourceViewCreatedDocument(
      uri: 'content://documents/tree/new-file',
      displayPath: 'saved.srt',
    );
  }

  @override
  Future<bool> writeCreatedDocument(
      SourceViewCreatedDocument document, Uint8List bytes) async {
    lastSaveAsWrite = Uint8List.fromList(bytes);
    return true;
  }
}

class _NoSavedGrant implements SourceViewSafGrantRepository {
  @override
  Future<String?> resolve({required String filePath, String? providedUri}) async =>
      providedUri;
}

/// Minimal independent Windows-1251 fixture. No native method channel needed.
class _CyrillicFixtureBackend implements SubtitleCharsetBackend {
  const _CyrillicFixtureBackend();

  @override
  Future<bool> available(String name) async => name == 'windows-1251';

  @override
  Future<String> decode(String name, Uint8List bytes) async =>
      String.fromCharCodes(bytes.map((value) {
        if (value == 0xDF) return 0x042F; // Я
        if (value < 0x80) return value;
        throw const FormatException('Unknown fixture byte');
      }));

  @override
  Future<Uint8List> encode(String name, String text) async =>
      Uint8List.fromList(text.runes.map((rune) {
        if (rune == 0x042F) return 0xDF;
        if (rune < 0x80) return rune;
        throw const FormatException('Unknown fixture character');
      }).toList());
}

Future<({ProviderContainer container, SourceViewController controller,
    SourceViewState first})> _open(
  _MemorySourceFiles files, {
  SubtitleExtendedEncodingService codec =
      const SubtitleExtendedEncodingService(),
}) async {
  final container = ProviderContainer(overrides: [
    sourceViewConfigProvider.overrideWithValue(
      const SourceViewConfig(filePath: '/sample/subtitle.srt')),
    sourceViewFileAccessProvider.overrideWithValue(files),
    sourceViewSafGrantRepositoryProvider.overrideWithValue(_NoSavedGrant()),
    sourceViewEncodingServiceProvider.overrideWithValue(codec),
  ]);
  final loaded = Completer<SourceViewState>();
  final subscription = container.listen<SourceViewState>(
    sourceViewControllerProvider,
    (previous, next) {
      if (!next.isLoading && !loaded.isCompleted) loaded.complete(next);
    },
    fireImmediately: true,
  );
  addTearDown(() {
    subscription.close();
    container.dispose();
  });
  return (
    container: container,
    controller: container.read(sourceViewControllerProvider.notifier),
    first: await loaded.future.timeout(const Duration(seconds: 5)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Source View Save retains UTF-8 BOM, Malayalam, and CRLF exactly',
      () async {
    final sourceText = '${_srtHeader}മലയാളം 😀\r\n';
    final original = SubtitleTextCodec.encode(
        sourceText, encoding: 'UTF-8 BOM');
    final files = _MemorySourceFiles(original);
    final session = await _open(files);
    expect(session.first.encodingName, 'UTF-8 BOM');
    expect(session.controller.rawSourceText, sourceText);

    await session.controller.saveFile();
    expect(files.lastWrite, orderedEquals(original));

    session.controller.updateRawSourceText(sourceText.replaceAll('😀', '🌍'));
    await session.controller.saveFile();
    expect(utf8.decode(files.lastWrite!.sublist(3)),
        sourceText.replaceAll('😀', '🌍'));
    expect(files.lastWrite!.take(3), [0xEF, 0xBB, 0xBF]);
    expect(session.container.read(sourceViewControllerProvider)
        .hasUnsavedChanges, isFalse);
  });

  test('Source View Save As retains UTF-16BE BOM and original line endings',
      () async {
    final sourceText = '${_srtHeader}مرحبا മലയാളം\r\n\r\n';
    final original = SubtitleTextCodec.encode(
        sourceText, encoding: 'UTF-16BE BOM');
    final files = _MemorySourceFiles(original);
    final session = await _open(files);
    expect(session.first.encodingName, 'UTF-16BE BOM');
    expect(session.controller.rawSourceText, sourceText);
    await session.controller.saveAsFile();
    expect(files.createRequests, 1);
    expect(files.lastSaveAsWrite, orderedEquals(original));
    expect(files.lastWrite, isNull);
  });

  test('legacy bytes require explicit encoding instead of Latin-1 guessing',
      () async {
    final sourceText = '${_srtHeader}“Café”\r\n';
    final original = SubtitleTextCodec.encode(
        sourceText, encoding: 'Windows-1252');
    final files = _MemorySourceFiles(original);
    final session = await _open(files);
    expect(session.first.isInitialized, isFalse);
    expect(session.first.errorMessage, contains('encoding'));
    expect(files.lastWrite, isNull);

    await session.controller.reopenWithEncoding('Windows-1252');
    expect(session.container.read(sourceViewControllerProvider).encodingName,
        'Windows-1252');
    expect(session.controller.rawSourceText, sourceText);
    await session.controller.saveFile();
    expect(files.lastWrite, orderedEquals(original));
    expect(files.reads, 2);
  });

  test('changing charset never discards unsaved raw text', () async {
    final files = _MemorySourceFiles(
        SubtitleTextCodec.encode('${_srtHeader}Hello\n', encoding: 'UTF-8'));
    final session = await _open(files);
    session.controller.updateRawSourceText('${_srtHeader}New line\n');
    final readsBefore = files.reads;
    await session.controller.reopenWithEncoding('ISO-8859-1');
    expect(files.reads, readsBefore);
    expect(session.controller.rawSourceText, contains('New line'));
    expect(session.container.read(sourceViewControllerProvider).encodingName,
        'UTF-8');
    expect(session.container.read(sourceViewControllerProvider).hasUnsavedChanges,
        isTrue);
  });

  test('unrepresentable text cannot overwrite file or create Save As document',
      () async {
    final original = SubtitleTextCodec.encode(
        '${_srtHeader}Café\r\n', encoding: 'ISO-8859-1');
    final files = _MemorySourceFiles(original);
    final session = await _open(files);
    // Latin-1 is intentionally ambiguous. The first attempt must refuse it.
    expect(session.first.errorMessage, isNotNull);
    await session.controller.reopenWithEncoding('ISO-8859-1');
    session.controller.updateRawSourceText('${_srtHeader}മലയാളം\r\n');
    await session.controller.saveFile();
    expect(files.lastWrite, isNull);
    expect(session.container.read(sourceViewControllerProvider).hasUnsavedChanges,
        isTrue);
    await session.controller.saveAsFile();
    expect(files.createRequests, 0);
    expect(files.lastSaveAsWrite, isNull);
  });

  test('extended native charset uses the same import/export codec', () async {
    final original = Uint8List.fromList([
      ...ascii.encode(_srtHeader), 0xDF, 0x0D, 0x0A,
    ]);
    final files = _MemorySourceFiles(original);
    final session = await _open(files,
      codec: const SubtitleExtendedEncodingService(
          backend: _CyrillicFixtureBackend()),
    );
    expect(session.first.errorMessage, isNotNull);
    await session.controller.reopenWithEncoding('Windows-1251');
    expect(session.controller.rawSourceText, '${_srtHeader}Я\r\n');
    await session.controller.saveFile();
    expect(files.lastWrite, orderedEquals(original));
  });
}
