import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_saf_input.dart';

void main() {
  test('Android SAF URI uses an authorized FFmpegKit input parameter',
      () async {
    final seen = <String>[];
    final input = await WaveformSafInput.resolve(
      'content://media/example',
      android: true,
      safParameterForRead: (uri) async {
        seen.add(uri);
        return 'saf:authorized-input';
      },
    );
    expect(seen, ['content://media/example']);
    expect(input, 'saf:authorized-input');
  });

  test('ordinary paths and non-Android inputs never request an SAF handle',
      () async {
    Future<String?> unused(String uri) =>
        throw StateError('SAF must not run for $uri');
    expect(await WaveformSafInput.resolve('/tmp/media.mkv',
        android: true, safParameterForRead: unused), '/tmp/media.mkv');
    expect(await WaveformSafInput.resolve('C:\\\\video.mkv',
        android: false, safParameterForRead: unused), 'C:\\\\video.mkv');
    expect(await WaveformSafInput.resolve('content://other/provider',
        android: false, safParameterForRead: unused),
        'content://other/provider');
  });

  test('null, blank and revoked SAF grants fail closed without leaking URI',
      () async {
    const uri = 'content://private.provider/secret-document';
    for (final provider in <Future<String?> Function(String)>[
      (_) async => null,
      (_) async => ' ',
      (_) async => throw const FileSystemException('Grant revoked'),
    ]) {
      try {
        await WaveformSafInput.resolve(uri,
            android: true, safParameterForRead: provider);
        fail('Unresolved SAF document must not reach FFmpeg');
      } on FileSystemException catch (error) {
        expect(error.message, contains('select the file again'));
        expect(error.toString(), isNot(contains(uri)));
      }
    }
  });
}
