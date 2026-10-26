import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/time_parser.dart';
import 'package:subtitle_studio/operations/subtitle_sync_operations.dart'; // For formatDuration
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/operations/srt_effect_frames.dart';

class SubtitleEffectOperations {
  /// Generates an SRT-compatible timed cue sequence for the additional text
  /// effects. Every preview frame is also an exported cue frame.
  static Future<List<SubtitleLine>> generateSrtEffect({
    required SubtitleLine originalLine,
    required String effect,
    required String color,
    String unit = 'word',
    String alternateColor = 'FFFF00',
    double endDelay = 0,
  }) async {
    final start = parseTimeString(originalLine.startTime).inMilliseconds;
    final end = parseTimeString(originalLine.endTime).inMilliseconds;
    final duration = end - start;
    final available = duration - (endDelay * 1000).round();
    if (duration <= 0 || available <= 0) return [];
    final frames = SrtEffectFrames.build(
      effect: effect,
      text: originalLine.edited ?? originalLine.original,
      color: color,
      unit: unit,
      alternateColor: alternateColor,
      availableMilliseconds: available,
    );
    if (frames.isEmpty) return [];
    return [
      for (var i = 0; i < frames.length; i++)
        SubtitleLine()
          ..index = originalLine.index + i
          ..original = originalLine.original
          ..edited = frames[i]
          ..startTime = SubtitleSyncOperations.formatDuration(Duration(
            milliseconds: start + (i * available / frames.length).round()))
          ..endTime = SubtitleSyncOperations.formatDuration(Duration(
            milliseconds: i == frames.length - 1 ? end :
                start + ((i + 1) * available / frames.length).round()))
          ..marked = originalLine.marked,
    ];
  }
  /// Builds the forward delta sequence for replacing one subtitle line with
  /// the generated effect lines.
  ///
  /// These deltas describe the forward replacement operation. Persistence
  /// and history commits are owned by SubtitleRepository.
  static List<SubtitleLineDelta> buildEffectDeltas({
    required SubtitleLine originalLine,
    required int originalLineIndex,
    required List<SubtitleLine> effectLines,
  }) {
    final deltas = <SubtitleLineDelta>[
      SubtitleLineDelta()
        ..changeType = 'delete'
        ..lineIndex = originalLineIndex
        ..beforeState = CheckpointStateReducer.copyLine(originalLine)
        ..afterState = null,
    ];

    for (var i = 0; i < effectLines.length; i++) {
      deltas.add(
        SubtitleLineDelta()
          ..changeType = 'add'
          ..lineIndex = originalLineIndex + i
          ..beforeState = null
          ..afterState = CheckpointStateReducer.copyLine(effectLines[i]),
      );
    }

    return deltas;
  }

  /// Generate typewriter effect by creating multiple subtitle lines
  /// Each line shows progressively more characters with precise timing
  static Future<List<SubtitleLine>> generateTypewriterEffect({
    required SubtitleLine originalLine,
    required String color,
    double endDelay = 0.0, // End delay in seconds
  }) async {
    final text = originalLine.edited ?? originalLine.original;
    final cleanText = text.replaceAll(RegExp(r'<[^>]*>'), ''); // Remove existing HTML tags
    
    if (cleanText.trim().isEmpty) return [];
    
    final startTime = parseTimeString(originalLine.startTime);
    final endTime = parseTimeString(originalLine.endTime);
    final totalDuration = endTime.inMilliseconds - startTime.inMilliseconds;
    
    // Calculate end delay in milliseconds
    final endDelayMs = (endDelay * 1000).round();
    final availableDuration = totalDuration - endDelayMs;
    
    if (availableDuration <= 0) return []; // Not enough time for effect
    
    final List<SubtitleLine> effectLines = [];
    // One visible glyph can contain many Unicode code points (Malayalam
    // conjuncts, vowel signs, emoji sequences). Never reveal half a glyph.
    final clusters = cleanText.characters.toList();
    // Limit flashes to ~16 per second; dense scripts must remain readable.
    final frameCount = math.min(clusters.length,
        math.max(1, availableDuration ~/ 60));
    final millisecondsPerFrame = availableDuration / frameCount;

    for (int i = 1; i <= frameCount; i++) {
      final visibleClusters = (i * clusters.length / frameCount).ceil();
      final partialText = clusters.take(visibleClusters).join('');
      final coloredText = '<font color="#$color">$partialText</font>';
      
      final lineStartTime = startTime.inMilliseconds + ((i - 1) * millisecondsPerFrame).round();
      final lineEndTime = startTime.inMilliseconds + (i * millisecondsPerFrame).round();
      
      final adjustedEndTime = (i == frameCount) ? endTime.inMilliseconds : lineEndTime;
      
      final newLine = SubtitleLine()
        ..index = originalLine.index + i - 1
        ..original = originalLine.original
        ..edited = coloredText
        ..startTime = SubtitleSyncOperations.formatDuration(Duration(milliseconds: lineStartTime))
        ..endTime = SubtitleSyncOperations.formatDuration(Duration(milliseconds: adjustedEndTime))
        ..marked = originalLine.marked;
      
      effectLines.add(newLine);
    }
    
    return effectLines;
  }
  
  /// Generate karaoke effect by creating multiple subtitle lines
  /// Each line highlights progressively more text
  static Future<List<SubtitleLine>> generateKaraokeEffect({
    required SubtitleLine originalLine,
    required String color,
    String effectType = 'word', // 'word' or 'character'
    double endDelay = 0.0, // End delay in seconds
    bool hasTextSelection = false, // Whether user selected specific text
    int selectionStart = 0, // Start position of selection
    int selectionEnd = 0, // End position of selection
    String? selectedText, // The selected text
    String? fullText, // The full text with selection
  }) async {
    // Use the provided full text if available, otherwise use original line text
    final sourceText = fullText ?? (originalLine.edited ?? originalLine.original);
    final cleanText = sourceText.replaceAll(RegExp(r'<[^>]*>'), ''); // Remove existing HTML tags
    
    if (cleanText.trim().isEmpty) return [];
    
    // If there's a text selection, only apply effect to that part
    String textToEffect;
    String beforeSelection = '';
    String afterSelection = '';
    
    if (hasTextSelection && selectedText != null && selectedText.isNotEmpty) {
      // Flutter selections use UTF-16 offsets. Expand any incomplete offsets
      // outward to grapheme boundaries so a Malayalam sign is never detached.
      final workingText = fullText ?? cleanText;
      final start = _graphemeBoundary(workingText, selectionStart, end: false);
      final end = _graphemeBoundary(workingText, selectionEnd, end: true);
      if (start >= end) return [];
      beforeSelection = workingText.substring(0, start);
      textToEffect = workingText.substring(start, end);
      afterSelection = workingText.substring(end);
    } else {
      // Apply effect to entire text
      textToEffect = cleanText;
    }
    
    if (textToEffect.trim().isEmpty) return [];
    
    final startTime = parseTimeString(originalLine.startTime);
    final endTime = parseTimeString(originalLine.endTime);
    final totalDuration = endTime.inMilliseconds - startTime.inMilliseconds;
    
    // Calculate end delay in milliseconds
    final endDelayMs = (endDelay * 1000).round();
    final availableDuration = totalDuration - endDelayMs;
    
    if (availableDuration <= 0) return []; // Not enough time for effect
    
    final List<SubtitleLine> effectLines = [];
    
    // Store UTF-16 end offsets of complete graphemes or whole words. Using
    // offsets rather than split/join also preserves every space and newline.
    final endpoints = <int>[];
    if (effectType == 'character') {
      var offset = 0;
      for (final cluster in textToEffect.characters) {
        offset += cluster.length;
        endpoints.add(offset);
      }
    } else {
      for (final match in RegExp(r'\S+', unicode: true).allMatches(textToEffect)) {
        endpoints.add(match.end);
      }
    }
    if (endpoints.isEmpty) return [];
    final frameCount = math.min(endpoints.length,
        math.max(1, availableDuration ~/ 60));
    final timePerFrame = availableDuration / frameCount;

    for (int i = 1; i <= frameCount; i++) {
      final endpoint = endpoints[(i * endpoints.length / frameCount).ceil() - 1];
      final highlighted = textToEffect.substring(0, endpoint);
      final remaining = textToEffect.substring(endpoint);
      final karaokeText = '$beforeSelection<font color="#$color">$highlighted</font>'
          '$remaining$afterSelection';
      
      final lineStartTime = startTime.inMilliseconds + ((i - 1) * timePerFrame).round();
      final lineEndTime = startTime.inMilliseconds + (i * timePerFrame).round();
      
      // For the last segment, extend to show full text until actual end time
      final adjustedEndTime = (i == frameCount) ? endTime.inMilliseconds : lineEndTime;
      
      final newLine = SubtitleLine()
        ..index = originalLine.index + i - 1
        ..original = originalLine.original
        ..edited = karaokeText
        ..startTime = SubtitleSyncOperations.formatDuration(Duration(milliseconds: lineStartTime))
        ..endTime = SubtitleSyncOperations.formatDuration(Duration(milliseconds: adjustedEndTime))
        ..marked = originalLine.marked;
      
      effectLines.add(newLine);
    }
    
    return effectLines;
  }

  static int _graphemeBoundary(String text, int rawOffset, {required bool end}) {
    final target = rawOffset.clamp(0, text.length);
    var previous = 0;
    for (final cluster in text.characters) {
      final next = previous + cluster.length;
      if (target == previous || target == next) return target;
      if (target < next) return end ? next : previous;
      previous = next;
    }
    return text.length;
  }

}
