import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:file_selector/file_selector.dart' as fs;
import 'package:subtitle_studio/utils/platform_file_handler.dart';
import 'package:subtitle_studio/utils/saf_file_handler.dart';
import 'package:subtitle_studio/utils/saf_path_converter.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/services/file_picker_preferences_repository.dart';
import 'package:subtitle_studio/core/file_access/studio_picked_file_reference.dart';

/// Platform-specific file picker utilities using SAF on Android
/// 
/// This utility provides a unified interface for file and folder picking across different platforms:
/// - Android: Uses Storage Access Framework (SAF) for secure file access
/// - Windows: Uses file_selector for native path-based file/folder dialogs
/// - Linux, macOS: Retain the existing file_picker dialog behavior
/// - iOS: Uses file_picker for native iOS file access
class FilePickerSAF {
  /// Choose a desktop file destination without creating or replacing it.
  ///
  /// The caller must perform the actual write and ask for confirmation before
  /// replacing an existing file. Android SAF and iOS document-provider saves
  /// require their own byte-based paths and must not use this method.
  static Future<String?> pickDesktopSaveLocation({
    required String fileName,
    required String extension,
    @visibleForTesting Future<String?> Function()? pickPath,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError('Path-only Save As is supported on desktop only.');
    }
    final suffix = (extension.startsWith('.')
            ? extension.substring(1)
            : extension)
        .toLowerCase();
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(suffix) ||
        !fileName.toLowerCase().endsWith('.$suffix')) {
      throw ArgumentError.value(fileName, 'fileName', 'Expected a .$suffix file.');
    }

    final selected = pickPath != null
        ? await pickPath()
        : (await fs.getSaveLocation(
            suggestedName: fileName,
            acceptedTypeGroups: [
              fs.XTypeGroup(
                label: '${suffix.toUpperCase()} files',
                extensions: [suffix],
              ),
            ],
          ))?.path;
    if (selected == null || selected.isEmpty) return null;
    if (!File(selected).isAbsolute ||
        !selected.toLowerCase().endsWith('.$suffix')) {
      throw FormatException('Choose an absolute .$suffix file path.');
    }
    return selected;
  }
  static String? _lastUsedDirectory;
  static FilePickerPreferencesRepository? _preferencesRepository;

  /// Inject persistence after Isar initialization.
  ///
  /// The picker API stays static during the file-access refactor, while its
  /// database dependency is explicit and replaceable.
  static void configurePreferences(
    FilePickerPreferencesRepository repository,
  ) {
    _preferencesRepository = repository;
    _lastUsedDirectory = null;
  }

  @visibleForTesting
  static void resetPreferencesForTesting() {
    _preferencesRepository = null;
    _lastUsedDirectory = null;
  }

  static Future<void> _initLastUsedDirectory() async {
    if (_lastUsedDirectory == null) {
      _lastUsedDirectory =
          await _preferencesRepository?.getLastUsedDirectory();
    }
  }

  static Future<void> _persistLastUsedDirectory() async {
    await _preferencesRepository?.setLastUsedDirectory(_lastUsedDirectory);
  }
  
  /// Pick a single file with platform-specific implementation
  /// 
  /// [context] - BuildContext for navigation and theming
  /// [title] - Title shown in the picker dialog (desktop only)
  /// [allowedExtensions] - List of allowed file extensions (e.g., ['.srt', '.txt'])
  /// [pickText] - Text shown on the pick/select button (not used on Android SAF)
  /// 
  /// Returns the selected file path or null if cancelled
  static Future<String?> pickFile({
    required BuildContext context,
    required String title,
    List<String>? allowedExtensions,
    String? pickText,
  }) async {
    if (Platform.isAndroid) {
      // Use SAF on Android
      return _pickFileAndroid(
        context: context,
        allowedExtensions: allowedExtensions,
      );
    } else {
      // Desktop and iOS - use file_picker
      return _pickFileDesktop(
        title: title,
        allowedExtensions: allowedExtensions,
      );
    }
  }

  /// Pick a folder with platform-specific implementation
  /// 
  /// [context] - BuildContext for navigation and theming
  /// [title] - Title shown in the picker dialog
  /// [pickText] - Text shown on the pick/select button
  /// 
  /// Returns the selected folder path or null if cancelled
  static Future<String?> pickFolder({
    required BuildContext context,
    required String title,
    String? pickText,
  }) async {
    if (Platform.isAndroid) {
      // On Android with SAF, we can't pick folders directly
      // Users save individual files instead
      if (context.mounted) {
        SnackbarHelper.showSnackBar(
          context,
          'On Android, files are saved individually using the system save dialog.',
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        );
      }
      return null;
    } else {
      // Desktop and iOS - use file_picker
      return _pickFolderDesktop(title: title);
    }
  }

  /// Pick a single file with URI-only mode (no content reading)
  /// This is useful for large files like videos to avoid OutOfMemoryError
  /// 
  /// [context] - BuildContext for navigation and theming
  /// [title] - Title shown in the picker dialog (desktop only)
  /// [allowedExtensions] - List of allowed file extensions (e.g., ['.mp4', '.mkv'])
  /// [pickText] - Text shown on the pick/select button (not used on Android SAF)
  /// 
  /// Returns a SafFileInfo object with URI and display path (content will be null)
  static Future<SafFileInfo?> pickFileUriOnly({
    required BuildContext context,
    required String title,
    List<String>? allowedExtensions,
    String? pickText,
  }) async {
    if (Platform.isAndroid) {
      // Use SAF URI-only mode on Android
      return _pickFileUriOnlyAndroid(
        context: context,
        allowedExtensions: allowedExtensions,
      );
    } else {
      // Desktop and iOS - fall back to regular file picker and return SafFileInfo
      final path = await _pickFileDesktop(
        title: title,
        allowedExtensions: allowedExtensions,
      );
      if (path != null) {
        // For desktop, we can return the path as both URI and displayPath
        return SafFileInfo(
          uri: path,
          displayPath: path,
          content: null,
        );
      }
      return null;
    }
  }

  /// Pick a file with both display path and SAF URI information
  /// This is useful for subtitle files where we need both pieces of info
  /// 
  /// [context] - BuildContext for navigation and theming
  /// [title] - Title shown in the picker dialog (desktop only)
  /// [allowedExtensions] - List of allowed file extensions (e.g., ['.srt', '.vtt'])
  /// 
  /// Returns a Map with 'displayPath' and 'safUri' keys, or null if cancelled
  static Future<Map<String, dynamic>?> pickFileWithInfo({
    required BuildContext context,
    required String title,
    List<String>? allowedExtensions,
  }) async {
    if (Platform.isAndroid) {
      // Use SAF on Android
      try {
        final mimeTypes = _extensionsToMimeTypes(allowedExtensions);
        final fileInfo = await PlatformFileHandler.readFile(mimeTypes: mimeTypes);
        
        if (fileInfo != null) {
          // Preserve displayPath for legacy callers; use accessLocator for
          // file access/persistence instead of the synthetic SAF path.
          final selection = fileInfo.pickedReference;
          if (kDebugMode) {
            debugPrint('FilePickerSAF: Android document selected');
          }
          return selection.toLegacyPickerInfo(fileInfo.content);
        }
        return null;
      } catch (e) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Unable to select file');
        }
        return null;
      }
    } else {
      // Desktop and iOS - use file_picker
      final path = await _pickFileDesktop(
        title: title,
        allowedExtensions: allowedExtensions,
      );
      if (path != null) {
        // Read content for desktop
        try {
          final file = File(path);
          final bytes = await file.readAsBytes();
          final selection = StudioPickedFileReference.fromPicker(
            accessLocator: path, displayPath: path, isFromSaf: false);
          return selection.toLegacyPickerInfo(bytes);
        } catch (e) {
          if (context.mounted) {
            SnackbarHelper.showError(context, 'Unable to read selected file');
          }
          return null;
        }
      }
      return null;
    }
  }

  /// Android SAF file picker implementation
  static Future<String?> _pickFileAndroid({
    required BuildContext context,
    List<String>? allowedExtensions,
  }) async {
    try {
      // Convert file extensions to MIME types for SAF
      final mimeTypes = _extensionsToMimeTypes(allowedExtensions);
      
      final fileInfo = await PlatformFileHandler.readFile(mimeTypes: mimeTypes);
      
      if (fileInfo != null) {
        // For Android SAF, we return the corrected display path for UI purposes
        // The SAF URI will be handled separately in the import process
        final correctedPath = SafPathConverter.normalizePath(fileInfo.safUri ?? fileInfo.path);
        
        if (kDebugMode) {
          debugPrint('FilePickerSAF: legacy Android document selected');
        }
        return correctedPath;
      }
      
      return null;
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          'Unable to select file',
        );
      }
      return null;
    }
  }

  /// Android SAF file picker implementation for URI-only mode (no content reading)
  static Future<SafFileInfo?> _pickFileUriOnlyAndroid({
    required BuildContext context,
    List<String>? allowedExtensions,
  }) async {
    try {
      // Convert file extensions to MIME types for SAF
      final mimeTypes = _extensionsToMimeTypes(allowedExtensions);
      
      // openFile uses Android's URI-only picker without loading file bytes.
      final fileInfo = await SafFileHandler.openFile(
        mimeTypes: mimeTypes,
      );
      
      return fileInfo;
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(
          context,
          'Unable to select file',
        );
      }
      return null;
    }
  }

  /// Native Windows picker; retain the existing plugin on other platforms
  static Future<String?> _pickFileDesktop({
    required String title,
    List<String>? allowedExtensions,
  }) async {
    try {
      await _initLastUsedDirectory();

      final String? filePath;
      if (Platform.isWindows) {
        final extensions = allowedExtensions
            ?.map((extension) => extension.replaceFirst('.', ''))
            .where((extension) => extension.isNotEmpty)
            .toList();
        final picked = await fs.openFile(
          initialDirectory: _lastUsedDirectory,
          acceptedTypeGroups: extensions == null || extensions.isEmpty
              ? const []
              : [fs.XTypeGroup(label: title, extensions: extensions)],
        );
        filePath = picked?.path;
      } else {
        // Preserve iOS and Unix file-provider behavior with single-file picking.
        final result = await fp.FilePicker.pickFile(
          dialogTitle: title,
          type: allowedExtensions != null ? fp.FileType.custom : fp.FileType.any,
          allowedExtensions: allowedExtensions
              ?.map((extension) => extension.replaceFirst('.', ''))
              .toList(),
          initialDirectory: _lastUsedDirectory,
        );
        filePath = result?.path;
      }

      if (filePath == null || filePath.isEmpty) return null;
      _lastUsedDirectory = File(filePath).parent.path;
      await _persistLastUsedDirectory();
      return filePath;
    } catch (e) {
      debugPrint('FilePickerSAF: desktop selection failed (${e.runtimeType})');
      return null;
    }
  }

  /// Native Windows folder picker with persisted last-used directory
  static Future<String?> _pickFolderDesktop({
    required String title,
  }) async {
    try {
      await _initLastUsedDirectory();

      final selectedDirectory = Platform.isWindows
          ? await fs.getDirectoryPath(initialDirectory: _lastUsedDirectory)
          : await fp.FilePicker.getDirectoryPath(
              dialogTitle: title,
              initialDirectory: _lastUsedDirectory,
            );

      // Canceling the dialog must not erase the last successful location.
      if (selectedDirectory == null || selectedDirectory.isEmpty) return null;
      _lastUsedDirectory = selectedDirectory;
      await _persistLastUsedDirectory();
      return selectedDirectory;
    } catch (e) {
      debugPrint('FilePickerSAF: folder selection failed (${e.runtimeType})');
      return null;
    }
  }

  /// Convert file extensions to MIME types for Android SAF
  static List<String> _extensionsToMimeTypes(List<String>? extensions) {
    if (extensions == null || extensions.isEmpty) {
      return ['*/*'];
    }

    final mimeTypes = <String>[];
    
    for (final ext in extensions) {
      final cleanExt = ext.toLowerCase().replaceFirst('.', '');
      
      switch (cleanExt) {
        case 'srt':
          mimeTypes.addAll(['application/x-subrip', 'text/plain']);
          break;
        case 'vtt':
          mimeTypes.addAll(['text/vtt', 'text/plain']);
          break;
        case 'ass':
        case 'ssa':
          mimeTypes.add('text/plain');
          break;
        case 'msone':
          mimeTypes.addAll(['application/octet-stream', 'text/plain']);
          break;
        case 'json':
          mimeTypes.addAll(['application/json', 'text/plain']);
          break;
        case 'txt':
          mimeTypes.add('text/plain');
          break;
        case 'mp4':
        case 'mkv':
        case 'avi':
        case 'mov':
        case 'm4v':
        case 'webm':
        case 'wmv':
        case 'flv':
          mimeTypes.add('video/*');
          break;
        default:
          mimeTypes.add('*/*');
          break;
      }
    }
    
    // Remove duplicates - don't add '*/*' fallback as it shows all files
    final uniqueMimeTypes = mimeTypes.toSet().toList();
    
    return uniqueMimeTypes;
  }
}

/// Convenience class for specific file operations using SAF
class FilePickerConvenience {
  
  /// Pick an SRT subtitle file. Other formats remain read-only research
  /// until their metadata-preserving editor/export paths are implemented.
  static Future<String?> pickSubtitleFile({
    required BuildContext context,
  }) async {
    return FilePickerSAF.pickFile(
      context: context,
      title: 'Select Subtitle File',
      allowedExtensions: ['.srt'],
      pickText: 'Select Subtitle',
    );
  }

  /// Pick a subtitle file with both display path and SAF URI information
  /// Returns a Map with 'displayPath' and 'safUri' keys, or null if cancelled
  static Future<Map<String, dynamic>?> pickSubtitleFileWithInfo({
    required BuildContext context,
  }) async {
    return FilePickerSAF.pickFileWithInfo(
      context: context,
      title: 'Select Subtitle File',
      allowedExtensions: ['.srt'],
    );
  }
  
  /// Pick an MSone project file
  static Future<String?> pickMsoneFile({
    required BuildContext context,
  }) async {
    return FilePickerSAF.pickFile(
      context: context,
      title: 'Select MSone Project',
      allowedExtensions: ['.msone'], // Only show .msone files for project import
      pickText: 'Select Project',
    );
  }
  
  /// Pick a video file
  static Future<String?> pickVideoFile({
    required BuildContext context,
  }) async {
    // Use URI-only mode for video files to avoid OutOfMemoryError
    final fileInfo = await FilePickerSAF.pickFileUriOnly(
      context: context,
      title: 'Select Video File',
      allowedExtensions: ['.mp4', '.mkv', '.avi', '.mov', '.m4v', '.webm', '.wmv', '.flv'],
      pickText: 'Select Video',
    );
    
    if (fileInfo == null) return null;
    try {
      return fileInfo.pickedReference(isFromSaf: Platform.isAndroid)
          .accessLocator;
    } on FormatException {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Unable to access selected video');
      }
      return null;
    }
  }
  
  /// Pick a video file with both URI and display name information
  static Future<Map<String, String?>?> pickVideoFileWithInfo({
    required BuildContext context,
  }) async {
    // Use URI-only mode for video files to avoid OutOfMemoryError
    final fileInfo = await FilePickerSAF.pickFileUriOnly(
      context: context,
      title: 'Select Video File',
      allowedExtensions: ['.mp4', '.mkv', '.avi', '.mov', '.m4v', '.webm', '.wmv', '.flv'],
      pickText: 'Select Video',
    );
    
    if (fileInfo != null) {
      late final String locator;
      try {
        locator = fileInfo.pickedReference(isFromSaf: Platform.isAndroid)
            .accessLocator;
      } on FormatException {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Unable to access selected video');
        }
        return null;
      }
      // Fix the display path using proper SAF URI conversion
      final correctedPath = Platform.isAndroid
          ? SafPathConverter.normalizePath(locator)
          : fileInfo.displayPath;
      
      if (kDebugMode) {
          debugPrint('FilePickerConvenience: video selected');
      }
      
      return {
        'uri': locator,
        'accessLocator': locator, // True storage URI, not displayPath.
        'displayPath': correctedPath, // Presentation-only legacy hint
        'displayName': fileInfo.fileName, // This extracts just the filename
      };
    }
    
    return null;
  }
  
  /// Pick export folder (desktop only, on Android shows explanation)
  static Future<String?> pickExportFolder({
    required BuildContext context,
  }) async {
    return FilePickerSAF.pickFolder(
      context: context,
      title: 'Select Project Directory',
      pickText: 'Select Folder',
    );
  }
  
  /// Save a file using platform-appropriate method
  static Future<String?> saveFile({
    required BuildContext context,
    String? content,
    Uint8List? bytes,
    required String fileName,
    String mimeType = 'text/plain',
    String? existingFilePath,
  }) async {
    if (Platform.isAndroid) {
      // Use SAF on Android for new file save dialog
      try {
        final fileInfo = await PlatformFileHandler.saveNewFile(
          content: content,
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        );
        
        return fileInfo?.path;
      } catch (e) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Error saving file: $e');
        }
        return null;
      }
    } else {
      // On desktop, calling code should handle save dialog
      // This is a placeholder for the actual implementation
      throw UnsupportedError('Desktop save dialog should be handled by calling code');
    }
  }
}
