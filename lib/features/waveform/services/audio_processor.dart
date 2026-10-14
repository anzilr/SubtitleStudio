import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/services/zoom_buffer_generator.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_cache_identity.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_processing_metrics.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_peak_cache.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_cache_coordinator.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_peak_cache_janitor.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_ffmpeg_plan.dart';
import 'package:subtitle_studio/utils/ffmpeg_helper.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_preferences_repository.dart';

/// Service for processing audio files into waveform data
class AudioProcessor {
  final WaveformPreferencesRepository _preferences;
  /// Build-time experiment switch; production defaults to eager zoom buffers.
  final bool useTiledZoom;
  WaveformProcessingMetrics? lastProcessingMetrics;
  int _requestEpoch = 0;
  static int _nextTemporaryId = 0;
  Process? _activeDesktopProcess;
  int? _activeNativeSessionId;

  /// Cancel only this instance's FFmpeg work, not unrelated media sessions.
  void cancelActive() {
    _requestEpoch++;
    _activeDesktopProcess?.kill();
    final sessionId = _activeNativeSessionId;
    if (sessionId != null) {
      unawaited(FFmpegKit.cancel(sessionId));
    }
    _activeNativeSessionId = null;
  }

  AudioProcessor(
    this._preferences, {
    this.useTiledZoom = const bool.fromEnvironment(
      'MS_ONE_TILED_WAVEFORM', defaultValue: false),
  });

  /// Process audio file and generate waveform with zoom levels
  /// If subtitleCollectionId is provided, will check for cached data and save new data
  /// If audioTrackId is provided, will extract that specific audio track
  Future<WaveformBuffer> processAudioFile(
    String audioFilePath, {
    Function(double)? onProgress,
    int? subtitleCollectionId,
    String? audioTrackId,
  }) async {
    cancelActive();
    final epoch = _requestEpoch;
    final stopwatch = Stopwatch()..start();
    try {
      if (kDebugMode) {
        print('AudioProcessor: Starting audio processing for: $audioFilePath');
      }

      WaveformData waveformData;

      // The experimental renderer uses a compact, source-scoped peak cache.
      // PCM extraction still writes a temporary raw file, but it is reduced
      // in bounded chunks and deleted without ever loading full PCM bytes.
      if (useTiledZoom) {
        waveformData = await _loadOrBuildPeakData(
          audioFilePath,
          subtitleCollectionId: subtitleCollectionId,
          audioTrackId: audioTrackId,
          onProgress: onProgress,
        );
      } else if (subtitleCollectionId != null) {
      // Check for cached waveform data if subtitle collection ID is provided
        final temporaryDirectory = await getTemporaryDirectory();
        final expectedPath = await WaveformCacheIdentity.pcmPath(
          temporaryDirectory: temporaryDirectory.path,
          subtitleCollectionId: subtitleCollectionId,
          sourcePath: audioFilePath,
          audioTrackId: audioTrackId,
        );
        final cache = await _preferences.getWaveformCache(
          subtitleCollectionId,
        );
        if (cache != null) {
          final pcmPath = cache.pcmPath;
          final pcmFile = File(pcmPath);
          
          final existingBytes = await pcmFile.exists()
              ? await pcmFile.length() : -1;
          if (WaveformCacheIdentity.metadataValid(
            actualPath: pcmPath,
            expectedPath: expectedPath,
            byteLength: existingBytes,
            totalSamples: cache.totalSamples,
            channels: cache.channels,
            sampleRate: cache.sampleRate,
          )) {
            if (kDebugMode) {
              print('AudioProcessor: Loading from cached PCM file: $pcmPath');
            }
            
            // Load from cached PCM
            onProgress?.call(0.1);
            waveformData = await _loadFromCachedPCM(
              pcmPath,
              cache.sampleRate,
              cache.totalSamples,
              cache.channels,
            );
            onProgress?.call(0.2);
            
            if (kDebugMode) {
              print('AudioProcessor: Successfully loaded from cache');
            }
          } else {
            if (kDebugMode) {
              print('AudioProcessor: Cached PCM file not found, will regenerate');
            }
            // Cache is invalid, clear it
            await _preferences.clearWaveformCache(subtitleCollectionId);
            
            // Extract and cache new PCM
            waveformData = await _extractAndCachePCM(
              audioFilePath, subtitleCollectionId, onProgress, audioTrackId,
              expectedPath,
            );
          }
        } else {
          // No cache exists, extract and save
          waveformData = await _extractAndCachePCM(
              audioFilePath, subtitleCollectionId, onProgress, audioTrackId,
              expectedPath,
            );
        }
      } else {
        // No subtitle collection ID provided, process without caching
        if (Platform.isWindows || Platform.isLinux) {
          await _checkFFmpegAvailability();
        }
        
        onProgress?.call(0.05);
        waveformData = await _extractAudioToPCM(audioFilePath, audioTrackId: audioTrackId);
        onProgress?.call(0.15);
      }

      if (epoch != _requestEpoch) {
        throw StateError('Waveform load was cancelled.');
      }
      final sourceMicroseconds = stopwatch.elapsedMicroseconds;
      // Step 2: Downsample (20% of total work)
      if (kDebugMode) print('AudioProcessor: Step 2 - Downsampling...');
      final processedData = useTiledZoom
          ? waveformData // Already reduced in bounded PCM chunks.
          : await _downsampleAudioAsync(waveformData);
      if (kDebugMode) print('AudioProcessor: Downsampling complete');
      onProgress?.call(0.35);

      final downsampleMicroseconds = stopwatch.elapsedMicroseconds;
      // Step 3: Generate zoom levels (60% of total work)
      if (kDebugMode) {
        print('AudioProcessor: Step 3 - ' +
            (useTiledZoom ? 'Generating zoom metadata...' : 'Generating zoom levels...'));
      }
      final zoomLevels = await _generateZoomLevelsInIsolate(
        processedData, 
        (zoomProgress) {
          // Map zoom progress (0.0-1.0) to overall progress (0.35-0.95)
          final overallProgress = 0.35 + (zoomProgress * 0.6);
          if (kDebugMode) print('AudioProcessor: Progress: ${(overallProgress * 100).toStringAsFixed(1)}%');
          onProgress?.call(overallProgress);
        },
      );
      
      if (kDebugMode) print('AudioProcessor: Zoom levels complete');
      onProgress?.call(0.95);

      final zoomMicroseconds = stopwatch.elapsedMicroseconds;
      // Step 4: Create buffer (5% of total work)
      if (kDebugMode) print('AudioProcessor: Step 4 - Creating buffer...');
      final buffer = WaveformBuffer(
        rawData: processedData,
        zoomLevels: zoomLevels,
        defaultZoomIndex: zoomLevels.length ~/ 2,
      );

      stopwatch.stop();
      final metrics = WaveformProcessingMetrics(
        sourceAcquisition: Duration(microseconds: sourceMicroseconds),
        downsampling: Duration(
            microseconds: downsampleMicroseconds - sourceMicroseconds),
        zoomGeneration: Duration(
            microseconds: zoomMicroseconds - downsampleMicroseconds),
        total: stopwatch.elapsed,
        decodedSamples: waveformData.totalSamples * waveformData.channels,
        displaySamples: processedData.totalSamples * processedData.channels,
        zoomPixels: zoomLevels.fold<int>(0,
            (count, level) => count + level.materializedPixels),
      );
      lastProcessingMetrics = metrics;
      if (kDebugMode) {
        print('AudioProcessor: Processing complete: ' + metrics.toString());
      }
      if (epoch != _requestEpoch) {
        throw StateError('Waveform load was cancelled.');
      }
      onProgress?.call(1.0);
      return buffer;
    } catch (e) {
      if (kDebugMode) {
        print('AudioProcessor: Error processing audio: $e');
      }
      rethrow;
    }
  }


  /// Compact peak cache is intentionally independent of the legacy PCM
  /// Isar metadata; no schema migration or media-cache reinterpretation.
  Future<WaveformData> _loadOrBuildPeakData(
    String sourcePath, {
    required int? subtitleCollectionId,
    required String? audioTrackId,
    required Function(double)? onProgress,
  }) async {
    final requestEpoch = _requestEpoch;
    void checkActive() {
      if (requestEpoch != _requestEpoch) {
        throw StateError('Waveform peak request was cancelled.');
      }
    }

    final temp = await getTemporaryDirectory();
    checkActive();
    final key = await WaveformCacheIdentity.pcmPath(
      temporaryDirectory: temp.path,
      subtitleCollectionId: subtitleCollectionId ?? 0,
      sourcePath: sourcePath,
      audioTrackId: audioTrackId,
    );
    checkActive();
    final cachePath = key.replaceFirst(RegExp(r'\.raw$'), '.pk1');
    final cacheFile = File(cachePath);
    final persistent = !sourcePath.startsWith('content://');

    // Coordinate even across distinct AudioProcessor instances in this
    // isolate; jobs for different audio files are not needlessly serialized.
    return WaveformCacheCoordinator.shared.runExclusive(cachePath, () async {
      checkActive(); // The request may have been superseded while queued.
      // Expired caches and abandoned staging files are pruned without
      // touching this destination or unrelated media/legacy PCM files.
      await const WaveformPeakCacheJanitor().clean(
        temp,
        protectedPaths: {cachePath},
      );
      checkActive();
      if (persistent && await cacheFile.exists()) {
        try {
          onProgress?.call(0.1);
          final cached = await WaveformPeakCache.load(cacheFile);
          checkActive();
          onProgress?.call(0.2);
          return cached;
        } on FileSystemException {
          // Regenerate if the recorded cache is no longer accessible.
        } on FormatException {
          // Reject truncated/corrupted or mismatched peak caches.
        }
        checkActive();
        if (await cacheFile.exists()) await cacheFile.delete();
      }

      checkActive();
      final output = await _extractAudioToPCM(
        sourcePath,
        audioTrackId: audioTrackId,
        reduceToPeaks: true,
        peakCachePath: cachePath,
      );
      checkActive();
      onProgress?.call(0.2);
      // SAF content can change without exposing a version; do not retain
      // this cache beyond the single successful decode.
      if (!persistent && await cacheFile.exists()) {
        await cacheFile.delete();
      }
      return output;
    });
  }

  /// Extract audio and cache the PCM file for future use
  Future<WaveformData> _extractAndCachePCM(
    String audioFilePath,
    int subtitleCollectionId,
    Function(double)? onProgress,
    String? audioTrackId,
    String cacheOutputPath,
  ) async {
    if (Platform.isWindows || Platform.isLinux) {
      await _checkFFmpegAvailability();
    }

    onProgress?.call(0.05);
    
    // Extract audio to PCM (this saves the file before returning)
    final waveformData = await _extractAudioToPCM(
      audioFilePath, 
      cacheForCollection: subtitleCollectionId,
      audioTrackId: audioTrackId,
      cacheOutputPath: cacheOutputPath,
    );
    
    onProgress?.call(0.15);
    return waveformData;
  }

  /// Load waveform data from cached PCM file
  Future<WaveformData> _loadFromCachedPCM(
    String pcmPath,
    int sampleRate,
    int totalSamples,
    int channels,
  ) async {
    final file = File(pcmPath);
    final bytes = await file.readAsBytes();
    if (channels != 1 || sampleRate != 44100 ||
        bytes.isEmpty || bytes.length.isOdd ||
        bytes.length != totalSamples * 2) {
      throw const FormatException('Invalid cached PCM format/length.');
    }
    final samples = _decodePcm16Le(bytes);
    
    if (kDebugMode) {
      print('AudioProcessor: Loaded ${samples.length} samples from cache');
    }
    
    return WaveformData(
      channels: channels,
      sampleRate: sampleRate,
      totalSamples: samples.length,
      rawSamples: [samples],
    );
  }

  /// Prepare zoom data on the UI isolate (native extraction is separate).
  /// Experimental tiled mode creates metadata only: no full-track
  /// WaveformSample buffers or extra square-root scaling pass.
  Future<List<ZoomLevel>> _generateZoomLevelsInIsolate(
    WaveformData data,
    Function(double)? onProgress,
  ) async {
    return ZoomBufferGenerator(_preferences).prepareZoomLevels(
      data,
      tiled: useTiledZoom,
      onProgress: onProgress,
    );
  }

  /// Downsample audio asynchronously
  Future<WaveformData> _downsampleAudioAsync(WaveformData data) async {
    // Run compute-intensive downsampling
    return _downsampleAudio(data);
  }

  /// Convert SAF URI to FFmpeg-compatible parameter for reading (Android only)
  Future<String> _getSafReadableParameter(String filePath) async {
    if (Platform.isAndroid && filePath.startsWith('content://')) {
      try {
        final safParameter = await FFmpegKitConfig.getSafParameterForRead(filePath);
        if (safParameter != null) {
          if (kDebugMode) {
            print('AudioProcessor: Converted SAF URI to FFmpeg parameter: $safParameter');
          }
          return safParameter;
        }
      } catch (e) {
        if (kDebugMode) {
          print('AudioProcessor: Error converting SAF URI: $e, using original path');
        }
      }
    }
    return filePath;
  }

  /// Check if FFmpeg is available on the system
  Future<void> _checkFFmpegAvailability() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      if (result.exitCode != 0) {
        throw Exception('FFmpeg is not properly installed');
      }
      
      if (kDebugMode) {
        print('AudioProcessor: FFmpeg is available');
      }
    } catch (e) {
      throw Exception(
        'FFmpeg is not available on this system. '
        'Please install FFmpeg and ensure it is in your PATH.\n\n'
        'Installation instructions:\n'
        '• Windows: Download from ffmpeg.org or use: winget install ffmpeg\n'
        '• Linux: sudo apt install ffmpeg (Ubuntu/Debian)\n\n'
        'Error: $e'
      );
    }
  }

  /// Extract audio from file using FFmpeg and convert to PCM
  /// If cacheForCollection is provided, saves the PCM file for future use
  /// If audioTrackId is provided, extracts that specific audio track
  Future<WaveformData> _extractAudioToPCM(
    String audioFilePath, {
    int? cacheForCollection,
    String? audioTrackId,
    String? cacheOutputPath,
    bool reduceToPeaks = false,
    String? peakCachePath,
  }) async {
    String? generatedOutputPath;
    try {
      final extractionEpoch = _requestEpoch;
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final outputPath = cacheOutputPath ??
          (tempDir.path + Platform.pathSeparator + 'waveform_temp_' +
              DateTime.now().microsecondsSinceEpoch.toString() + '_' +
              (++_nextTemporaryId).toString() + '.raw');
      generatedOutputPath = outputPath;

      if (kDebugMode) {
        print('AudioProcessor: Extracting audio to PCM: $outputPath');
        if (cacheForCollection != null) {
          print('AudioProcessor: Will cache for collection ID: $cacheForCollection');
        }
      }

      // Use FFmpegHelper to extract audio
      // We need to use FFmpeg command directly for raw PCM extraction
      final normalizedPath = FFmpegHelper.normalizePath(audioFilePath);
      
      // Build FFmpeg command for PCM extraction
      // -ac 1: mono output (single channel)
      // -ar 44100: 44.1kHz sample rate
      // -f s16le: 16-bit signed little-endian PCM
      // -y: overwrite output file

      if (kDebugMode) {
        print('AudioProcessor: Executing FFmpeg on ${Platform.operatingSystem}');
      }

      // Execute FFmpeg command based on platform
      if (Platform.isWindows || Platform.isLinux) {
        final plan = WaveformFfmpegPlan(
          inputPath: normalizedPath,
          outputPath: outputPath,
          selectedTrackId: audioTrackId,
        );
        final args = plan.arguments();
        if (kDebugMode) {
          print('AudioProcessor: Audio ordinal: ' +
              WaveformFfmpegPlan.audioOrdinal(audioTrackId).toString());
        }

        final process = await Process.start('ffmpeg', args);
        _activeDesktopProcess = process;
        if (extractionEpoch != _requestEpoch) {
          process.kill();
        }
        final stdoutDone = process.stdout.drain<void>();
        final stderrDone = process.stderr.transform(utf8.decoder).join();
        final exitCode = await process.exitCode;
        await stdoutDone;
        final stderr = await stderrDone;
        if (identical(_activeDesktopProcess, process)) {
          _activeDesktopProcess = null;
        }
        if (extractionEpoch != _requestEpoch) {
          throw StateError('Waveform extraction was cancelled.');
        }
        if (exitCode != 0) {
          throw Exception('FFmpeg failed with exit code $exitCode: $stderr');
        }
      } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        // Mobile/macOS platforms: Use FFmpegKit
        final inputPath = await _getSafReadableParameter(normalizedPath);
        
        final plan = WaveformFfmpegPlan(
          inputPath: inputPath,
          outputPath: outputPath,
          selectedTrackId: audioTrackId,
        );
        final command = plan.ffmpegKitCommand();

        if (kDebugMode) {
          print('AudioProcessor: FFmpegKit command: $command');
        }
        
        final completed = Completer<void>();
        final session = await FFmpegKit.executeAsync(command, (_) {
          if (!completed.isCompleted) completed.complete();
        });
        _activeNativeSessionId = session.getSessionId();
        if (extractionEpoch != _requestEpoch) {
          await FFmpegKit.cancel(session.getSessionId());
        }
        await completed.future;
        if (_activeNativeSessionId == session.getSessionId()) {
          _activeNativeSessionId = null;
        }
        if (extractionEpoch != _requestEpoch) {
          throw StateError('Waveform extraction was cancelled.');
        }
        final returnCode = await session.getReturnCode();

        // No implicit retry: wrong-language track would corrupt the cache.
        if (returnCode == null || !returnCode.isValueSuccess()) {
          final logs = await session.getLogs();
          final logMessages = logs.map((log) => log.getMessage()).join('\n');
          throw Exception('FFmpegKit failed with code ${returnCode?.getValue()}: $logMessages');
        }
      } else {
        throw UnsupportedError(
          'Waveform generation is not supported on ${Platform.operatingSystem}.'
        );
      }

      if (extractionEpoch != _requestEpoch) {
        throw StateError('Waveform extraction was cancelled.');
      }
      if (kDebugMode) {
        print('AudioProcessor: FFmpeg extraction successful');
      }

      // Read raw PCM data
      final file = File(outputPath);
      if (!await file.exists()) {
        throw Exception('FFmpeg failed to create output file');
      }

      if (reduceToPeaks) {
        try {
          if (peakCachePath == null) {
            throw ArgumentError('Missing compact peak cache path.');
          }
          return await WaveformPeakCache.build(
            pcmFile: file, cacheFile: File(peakCachePath),
            isCancelled: () => extractionEpoch != _requestEpoch);
        } finally {
          if (await file.exists()) await file.delete();
        }
      }
      final bytes = await file.readAsBytes();
      if (kDebugMode) {
        print('AudioProcessor: Read ${bytes.length} bytes of PCM data');
      }

      if (bytes.isEmpty || bytes.length.isOdd) {
        throw const FormatException('Truncated or empty PCM extraction.');
      }
      final samples = _decodePcm16Le(bytes);

      // Use mono (1 channel)
      const channels = 1;
      const sampleRate = 44100;
      final channelSamples = <Int16List>[samples]; // Single channel

      // Save cache information if requested
      if (cacheForCollection != null) {
        await _preferences.saveWaveformCache(
          subtitleCollectionId: cacheForCollection,
          pcmPath: outputPath,
          sampleRate: sampleRate,
          totalSamples: samples.length,
          channels: channels,
        );
        
        if (kDebugMode) {
          print('AudioProcessor: Waveform cache saved for collection $cacheForCollection');
        }
      } else {
        // Clean up temporary file if not caching
        await file.delete();
      }

      if (kDebugMode) {
        print('AudioProcessor: Successfully extracted ${samples.length} samples (mono)');
      }

      return WaveformData(
        channels: channels,
        sampleRate: sampleRate,
        totalSamples: channelSamples[0].length,
        rawSamples: channelSamples,
      );
    } catch (e) {
      // Never preserve a half-written temp PCM file on failed extraction,
      // rejected track selection, cache corruption or user cancellation.
      if (generatedOutputPath != null &&
          (reduceToPeaks || cacheOutputPath == null)) {
        final output = File(generatedOutputPath);
        if (await output.exists()) await output.delete();
      }
      if (kDebugMode) {
        print('AudioProcessor: Error extracting audio: $e');
      }
      rethrow;
    }
  }

  /// Decode FFmpeg's little-endian signed 16-bit PCM on any host.
  static Int16List _decodePcm16Le(Uint8List bytes) {
    if (bytes.length.isOdd) {
      throw const FormatException('Odd number of PCM bytes.');
    }
    if (Endian.host == Endian.little) {
      return Int16List.view(
          bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
    }
    final view = ByteData.sublistView(bytes);
    final samples = Int16List(bytes.lengthInBytes ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little);
    }
    return samples;
  }

  /// Downsample audio to reduce data size (~3000 samples/sec max)
  WaveformData _downsampleAudio(WaveformData input) {
    const maxSamplesPerSec = 3000;

    if (input.sampleRate <= maxSamplesPerSec) {
      return input; // No downsampling needed
    }

    final sampleShift = _calculateSampleShift(input.sampleRate, maxSamplesPerSec);
    final newSampleRate = input.sampleRate >> sampleShift;
    final frameSize = 1 << sampleShift;

    if (kDebugMode) {
      print('AudioProcessor: Downsampling from ${input.sampleRate}Hz to ${newSampleRate}Hz');
    }

    final newChannelSamples = <Int16List>[];

    for (var ch = 0; ch < input.channels; ch++) {
      final oldSamples = input.rawSamples[ch];
      final newLength = oldSamples.length ~/ frameSize;
      final newSamples = Int16List(newLength);

      for (var i = 0; i < newLength; i++) {
        var sum = 0;
        final start = i * frameSize;
        final end = (start + frameSize < oldSamples.length)
            ? start + frameSize
            : oldSamples.length;

        // Average samples in frame
        for (var j = start; j < end; j++) {
          sum += oldSamples[j];
        }

        newSamples[i] = (sum / (end - start)).round();
      }

      newChannelSamples.add(newSamples);
    }

    return WaveformData(
      channels: input.channels,
      sampleRate: newSampleRate,
      totalSamples: newChannelSamples[0].length,
      rawSamples: newChannelSamples,
    );
  }

  /// Calculate sample shift for downsampling
  static int _calculateSampleShift(int currentRate, int targetRate) {
    var shift = 0;
    var rate = currentRate;
    while (rate > targetRate) {
      rate >>= 1;
      shift++;
    }
    return shift;
  }

  /// Cleanup resources
  void dispose() {
    cancelActive();
  }
}
