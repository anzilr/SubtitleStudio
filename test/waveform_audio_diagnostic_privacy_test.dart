import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_preferences_repository.dart';
import 'package:subtitle_studio/features/waveform/services/audio_processor.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';

class _UnusedPreferences implements WaveformPreferencesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingProcessor extends AudioProcessor {
  final Object failure;
  _FailingProcessor(this.failure) : super(_UnusedPreferences());

  @override
  Future<WaveformBuffer> processAudioFile(
    String audioFilePath, {
    Function(double)? onProgress,
    void Function(Duration)? onDecodedAudioTime,
    int? subtitleCollectionId,
    String? audioTrackId,
  }) async {
    throw failure;
  }
}

void main() {
  const privateLocator = '/private/secret_media_marker/holiday.mkv';

  test('waveform controller redacts unexpected filesystem failures', () async {
    final container = ProviderContainer(overrides: [
      waveformAudioProcessorProvider.overrideWithValue(
        _FailingProcessor(const FileSystemException(
          'Permission denied: secret_media_marker', privateLocator,
        )),
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(waveformControllerProvider.notifier)
        .dispatch(const LoadAudioFile(privateLocator));
    final state = container.read(waveformControllerProvider);
    expect(state, isA<WaveformError>());
    final failure = state as WaveformError;
    expect(failure.message, contains('Check media access'));
    expect(failure.message, isNot(contains('secret_media_marker')));
    expect(failure.message, isNot(contains(privateLocator)));
    // The source locator remains intact for retry; only diagnostics change.
    expect(failure.filePath, privateLocator);
  });

  test('only explicit path-free FFmpeg failures retain recovery advice',
      () async {
    const safeMessage = 'FFmpeg audio extraction failed (exit code 1). '
        'Check the selected audio track and file access.';
    final container = ProviderContainer(overrides: [
      waveformAudioProcessorProvider.overrideWithValue(
        _FailingProcessor(const WaveformProcessingFailure(safeMessage)),
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(waveformControllerProvider.notifier)
        .dispatch(const LoadAudioFile(privateLocator));
    final state = container.read(waveformControllerProvider) as WaveformError;
    expect(state.message, contains(safeMessage));
    expect(state.message, isNot(contains(privateLocator)));
  });

  test('waveform native diagnostic boundary never includes raw media data', () {
    final processor = File('lib/features/waveform/services/audio_processor.dart')
        .readAsStringSync();
    final controller = File(
      'lib/features/waveform/providers/waveform_controller.dart',
    ).readAsStringSync();
    final section = File('lib/features/waveform/widgets/waveform_section.dart')
        .readAsStringSync();
    final editing = File('lib/features/waveform/widgets/waveform_editing.dart')
        .readAsStringSync();

    for (final unsafeTrace in <String>[
      'Starting audio processing for:',
      'Loading from cached PCM file:',
      'Extracting audio to PCM: \$outputPath',
      'FFmpegKit command:',
      'session.getLogs()',
      'utf8.decoder).join()',
      'FFmpeg failed with exit code \$exitCode: \$stderr',
      'Error processing audio: \$e',
      'Error extracting audio: \$e',
    ]) {
      expect(processor, isNot(contains(unsafeTrace)), reason: unsafeTrace);
    }
    expect(processor, contains('process.stderr.drain<void>()'));
    expect(controller, isNot(contains('Failed to load audio: \${e.toString()}')));
    expect(controller, isNot(contains('zoom levels: \$error')));
    expect(section, isNot(contains('Failed to load audio: \$e')));
    expect(editing, isNot(contains('Error updating time: \$e')));
  });
}
