import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/screens/source_view/source_view_state.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_target.dart';
import 'package:subtitle_studio/models/subtitle_entry.dart';
import 'package:subtitle_studio/utils/app_logger.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_access.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';

/// Riverpod controller for Source View state
/// 
/// Encapsulates Source View business logic and state transitions. It handles:
/// - File loading with encoding detection
/// - Content editing and change tracking
/// - Save operations with multiple fallback strategies
/// - SAF URI management and persistence
/// - Error handling with user-friendly messages
/// 
/// State Flow:
/// 1. Initial loading state
/// 2. Load file content (SAF or direct file access)
/// 3. Parse SRT content into subtitle entries
/// 4. Handle content changes and track modifications
/// 5. Save with robust fallback strategies
/// 6. Provide appropriate user feedback
class SourceViewConfig {
  final String filePath;
  final String? displayName;
  final String? safUri;
  final String? fileContent;

  const SourceViewConfig({
    required this.filePath,
    this.displayName,
    this.safUri,
    this.fileContent,
  });
}

/// Configuration is overridden by SourceViewScreenHost's nested ProviderScope
/// so each opened source file receives an isolated controller instance.
final sourceViewConfigProvider = Provider<SourceViewConfig>((ref) {
  throw StateError(
    'sourceViewConfigProvider must be overridden for each source view route.',
  );
});

final sourceViewControllerProvider =
    NotifierProvider<SourceViewController, SourceViewState>(
  SourceViewController.new,
  dependencies: [sourceViewConfigProvider],
);

class SourceViewController extends Notifier<SourceViewState> {
  String? _rawSourceText;
  String? get rawSourceText => _rawSourceText;

  void updateRawSourceText(String text) {
    _rawSourceText = text;
    markContentChanged();
  }
  bool _disposed = false;

  @override
  SourceViewState build() {
    final config = ref.watch(sourceViewConfigProvider);
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
    });

    unawaited(Future.microtask(() => _initialize(config.fileContent)));

    return SourceViewState.initial(
      filePath: config.filePath,
      displayName: config.displayName,
      safUri: config.safUri,
    );
  }

  void _setState(SourceViewState nextState) {
    if (!_disposed) {
      state = nextState;
    }
  }

  String get _logFileName {
    final displayName = state.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    // Never derive log names from Android document IDs, token-bearing URLs
    // or local user home directories. The UI still retains its display name.
    return 'subtitle-file';
  }

  Map<String, dynamic> get _safeLogContext => {
        'fileName': _logFileName,
        'hasSafUri': state.safUri?.isNotEmpty == true,
      };

  /// Initialize the source view controller
  Future<void> _initialize(String? preloadedContent) async {
    await AppLogger.instance.info('SourceViewController: Initializing');
    if (_disposed) return;

    await _checkForExistingSafUri();
    if (_disposed) return;

    await _loadFileContent(preloadedContent);
  }

  /// Check shared preferences for existing SAF URI information for this file path
  Future<void> _checkForExistingSafUri() async {
    try {
      await AppLogger.instance.info('Checking saved SAF access for $_logFileName');
      
      final prefs = await SharedPreferences.getInstance();
      final key = 'saf_uri_${state.filePath}';
      final storedSafUri = prefs.getString(key);
      
      if (storedSafUri != null) {
        _setState(state.copyWith(safUri: storedSafUri));
        await AppLogger.instance.info('Found saved SAF access for $_logFileName');
      } else if (state.safUri != null) {
        await AppLogger.instance.info('Using provided SAF access for $_logFileName');
        // Store this SAF URI in preferences for future use
        await _storeSafUriInPreferences();
      }
      
    } catch (e) {
      await AppLogger.instance.error(
        'Error checking saved SAF access',
        extra: {'errorType': e.runtimeType.toString(), ..._safeLogContext},
      );
      // Continue with provided SAF URI or null
    }
  }
  
  /// Store the SAF URI information in shared preferences for future access
  Future<void> _storeSafUriInPreferences() async {
    if (state.safUri == null) return;
    
    try {
      await AppLogger.instance.info('Storing SAF URI in shared preferences for future access');
      
      final prefs = await SharedPreferences.getInstance();
      final key = 'saf_uri_${state.filePath}';
      await prefs.setString(key, state.safUri!);
      
      await AppLogger.instance.info('Saved SAF access metadata for $_logFileName');
    } catch (e) {
      await AppLogger.instance.error(
        'Error storing SAF access metadata',
        extra: {'errorType': e.runtimeType.toString(), ..._safeLogContext},
      );
    }
  }

  /// Load file content from storage with encoding detection
  Future<void> _loadFileContent(String? preloadedContent) async {
    try {
      _setState(state.toLoading());

      String content;
      Encoding encoding = utf8;
      
      if (preloadedContent != null) {
        // Use pre-loaded content (from SAF file selection)
        content = preloadedContent;
        encoding = utf8; // Assume UTF-8 for pre-loaded content
        await AppLogger.instance.info('Using preloaded content: ${content.length} chars');
      } else {
        // The platform adapter owns SAF, native fallback and revoked grants.
        // The controller only chooses a typed, validated source identity.
        final target = SourceViewFileTarget.resolve(
          filePath: state.filePath,
          safUri: state.safUri,
        );
        final bytes = await ref.read(sourceViewFileAccessProvider).read(target);
        if (_disposed) return;

        // Try to detect encoding (simple detection - UTF-8 first, then fallback)
        try {
          content = utf8.decode(bytes);
          encoding = utf8;
        } catch (e) {
          // If UTF-8 fails, try Latin-1 as fallback
          content = latin1.decode(bytes);
          encoding = latin1;
        }
      }
      
      // Keep the source's actual whitespace and line endings for raw editing.
      _rawSourceText = content;
      // Parse SRT content into subtitle entries
      await AppLogger.instance.info('Parsing SRT content: ${content.length} chars');
      final entries = _parseSrtContent(content);
      await AppLogger.instance.info('Parsed ${entries.length} subtitle entries');
      
      _setState(state.toLoaded(entries: entries, encoding: encoding));
      await AppLogger.instance.info('Loaded source view for $_logFileName');
      
    } catch (e) {
      _setState(state.toError('Could not load this subtitle file.'));
      await AppLogger.instance.error(
        'Error loading file in source view: $e',
        context: 'SourceViewController._loadFileContent',
        extra: _safeLogContext,
      );
    }
  }

  /// Parse SRT content using the shared tolerant parser.
  List<SubtitleEntry> _parseSrtContent(String content) {
    final parsed = SubtitleParser.parseSrt(content);

    final entries = parsed
        .map(
          (line) => SubtitleEntry(
            index: line.index.toString(),
            // Source View writes SRT; normalize the shared parser's dot
            // milliseconds back to the conventional SRT comma form.
            startTime: line.startTime.replaceAll('.', ','),
            endTime: line.endTime.replaceAll('.', ','),
            text: line.text,
          ),
        )
        .toList(growable: false);

    AppLogger.instance.info(
      'Source View parsed ${entries.length} subtitle entries',
    );
    return entries;
  }

  /// Handle content changes by updating a specific subtitle entry
  void updateSubtitleEntry(int index, SubtitleEntry updatedEntry) {
    if (index < 0 || index >= state.subtitleEntries.length) {
      AppLogger.instance.warning('Invalid subtitle entry index: $index');
      return;
    }

    // Check if the content actually changed to prevent unnecessary updates
    final currentEntry = state.subtitleEntries[index];
    if (currentEntry == updatedEntry) {
      return; // No change, skip update
    }

    final updatedEntries = List<SubtitleEntry>.from(state.subtitleEntries);
    updatedEntries[index] = updatedEntry;
    
    _setState(state.toContentChanged(entries: updatedEntries));
  }

  /// Handle changes to subtitle entry index
  void updateSubtitleIndex(int entryIndex, String newIndex) {
    final currentEntry = state.subtitleEntries[entryIndex];
    final updatedEntry = currentEntry.copyWith(index: newIndex);
    updateSubtitleEntry(entryIndex, updatedEntry);
  }

  /// Handle changes to subtitle entry start time
  void updateSubtitleStartTime(int entryIndex, String newStartTime) {
    final currentEntry = state.subtitleEntries[entryIndex];
    final updatedEntry = currentEntry.copyWith(startTime: newStartTime);
    updateSubtitleEntry(entryIndex, updatedEntry);
  }

  /// Handle changes to subtitle entry end time
  void updateSubtitleEndTime(int entryIndex, String newEndTime) {
    final currentEntry = state.subtitleEntries[entryIndex];
    final updatedEntry = currentEntry.copyWith(endTime: newEndTime);
    updateSubtitleEntry(entryIndex, updatedEntry);
  }

  /// Handle changes to subtitle entry text
  void updateSubtitleText(int entryIndex, String newText) {
    final currentEntry = state.subtitleEntries[entryIndex];
    final updatedEntry = currentEntry.copyWith(text: newText);
    updateSubtitleEntry(entryIndex, updatedEntry);
  }

  /// Simple method to mark content as changed (for performance optimization)
  /// Used by direct object mutation approach like EditScreen
  void markContentChanged() {
    // Simply update the current state with hasUnsavedChanges = true
    // This is much more performant than unnecessary full-list processing
    if (!state.hasUnsavedChanges) {
      _setState(state.toContentChanged(entries: state.subtitleEntries));
    }
  }

  /// Reload file content
  Future<void> reloadFile() async {
    await _loadFileContent(null);
  }

  /// Save current file content back to storage with original encoding
  Future<void> saveFile() async {
    try {
      _setState(state.toSaving());
      
      final content = _rawSourceText ?? state.toSrtContent();
      
      // Encode using the detected encoding
      final bytes = Uint8List.fromList(state.fileEncoding.encode(content));
      final target = SourceViewFileTarget.resolve(
        filePath: state.filePath,
        safUri: state.safUri,
      );
      // SAF permission checks and native fallback belong to the adapter;
      // it never treats a document URI as a filesystem path.
      final destination = await ref.read(sourceViewFileAccessProvider)
          .write(target, bytes);
      if (_disposed) return;
      final saveSuccessful = destination != null;

      // Handle save results
      if (saveSuccessful) {
        String successMessage;
        if (destination == SourceViewSaveDestination.androidDocument) {
          successMessage = 'File saved to original location ✓';
        } else if (destination == SourceViewSaveDestination.nativeFile &&
            target.androidDocumentUri != null) {
          successMessage = 'File saved to app cache (original location unavailable)';
        } else {
          successMessage = 'File saved successfully';
        }
        
        _setState(state.toSaveSuccess(successMessage));
        await AppLogger.instance.info('=== SAVE COMPLETED SUCCESSFULLY ===');
      } else {
        await AppLogger.instance.warning('All save strategies failed');
        _setState(state.toSaveError('Unable to save file. All save strategies failed.'));
      }
      
    } catch (e) {
      _setState(state.toSaveError('Could not save the subtitle file.'));
      await AppLogger.instance.error(
        'Error saving file in source view: $e',
        context: 'SourceViewController.saveFile',
        extra: _safeLogContext,
      );
    }
  }

  /// Save file to a new location using SAF
  Future<void> saveAsFile() async {
    try {
      _setState(state.toSaving());
      
      // Get the current file name as a default
      final currentFileName = state.filePath.split('/').last;
      
      // Ensure the file has .srt extension and proper name
      String fileName;
      if (currentFileName.toLowerCase().endsWith('.srt')) {
        fileName = currentFileName;
      } else {
        // Remove any existing extension and add .srt
        final nameWithoutExt = currentFileName.replaceAll(RegExp(r'\.[^.]*$'), '');
        fileName = '$nameWithoutExt.srt';
      }
      
      await AppLogger.instance.info('Save As filename: $fileName');
      
      // Use SAF to create a new document
      final fileAccess = ref.read(sourceViewFileAccessProvider);
      final safInfo = await fileAccess.createDocument(
        fileName: fileName,
        mimeType: '*/*',
      );
      if (_disposed) return;
      
      if (safInfo == null) {
        // User cancelled the save dialog
        await AppLogger.instance.info('Save As cancelled by user');
        _setState(state.copyWith(isSaving: false));
        return;
      }
      
      await AppLogger.instance.info('Save As location selected');
      
      final content = state.toSrtContent();
      
      if (content.isEmpty) {
        _setState(state.toSaveError('No content to save. The file appears to be empty.'));
        await AppLogger.instance.warning('Save As aborted: no content available');
        return;
      }
      
      // Always use UTF-8 encoding for new files
      final encoder = utf8;
      final bytes = encoder.encode(content);
      await AppLogger.instance.info('Save As encoded bytes length: ${bytes.length}');
      
      // Save to the new location
      final writeResult = await fileAccess.writeCreatedDocument(
        safInfo, Uint8List.fromList(bytes),
      );
      if (_disposed) return;
      
      if (writeResult) {
        await AppLogger.instance.info('Save As completed successfully');
        _setState(state.toSaveSuccess('File saved to: ${safInfo.displayPath}'));
      } else {
        _setState(state.toSaveError('Failed to write file content'));
      }
      
    } catch (e) {
      _setState(state.toSaveError('Could not save the subtitle file to that location.'));
      await AppLogger.instance.error(
        'Error saving file as in source view: $e',
        context: 'SourceViewController.saveAsFile',
        extra: _safeLogContext,
      );
    }
  }

  /// Clear any error or save messages
  void clearMessages() {
    _setState(state.copyWith(
      errorMessage: null,
      saveMessage: null,
    ));
  }
}