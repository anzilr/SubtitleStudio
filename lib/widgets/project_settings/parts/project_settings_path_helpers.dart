part of '../../project_settings_sheet.dart';

extension _ProjectSettingsPathHelpers on _ProjectSettingsSheetState {
  String _detectLanguage() {
    if (_sessionInfo == null) return 'Unknown';
    return _sessionInfo!['languageCodes'] ?? 'EN';
  }

  bool _containsScript(String text, String script) {
    switch (script) {
      case 'Malayalam':
        return RegExp(r'[\u0D00-\u0D7F]').hasMatch(text);
      case 'Hindi':
        return RegExp(r'[\u0900-\u097F]').hasMatch(text);
      case 'Arabic':
        return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
      case 'Chinese':
        return RegExp(r'[\u4E00-\u9FFF]').hasMatch(text);
      case 'Japanese':
        return RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text);
      case 'Korean':
        return RegExp(r'[\uAC00-\uD7AF]').hasMatch(text);
      case 'Russian':
        return RegExp(r'[\u0400-\u04FF]').hasMatch(text);
      default:
        return false;
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    SnackbarHelper.showSnackBar(
      context,
      'Copied to clipboard',
      backgroundColor: Colors.green,
    );
  }

  /// Get display path for project file with proper URI decoding for Android
  String? _getDisplayProjectFilePath() {
    final projectFilePath = widget.session.projectFilePath;
    if (projectFilePath == null) return null;
    
    String displayPath = projectFilePath;
    
    // For Android SAF URIs, decode to show human-readable path
    if (Platform.isAndroid && projectFilePath.startsWith('content://')) {
      try {
        // Use SafPathConverter for correct SAF URI to path conversion
        final decodedPath = SafPathConverter.normalizePath(projectFilePath);
        if (kDebugMode) {
          print('ProjectSettings _getDisplayProjectFilePath: originalPath=$projectFilePath, correctedPath=$decodedPath');
        }
        
        if (decodedPath != projectFilePath && 
            decodedPath.contains('/') && 
            !decodedPath.startsWith('content://')) {
          displayPath = decodedPath;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error decoding project file URI: $e');
        }
      }
    }
    
    // Ensure the path includes the filename - if it doesn't end with .msone, add it
    if (!displayPath.toLowerCase().endsWith('.msone')) {
      // If the path is just a directory, try to append a filename based on the subtitle file
      final baseName = widget.session.fileName.replaceAll(RegExp(r'\.[^.]*$'), ''); // Remove extension
      if (baseName.isNotEmpty) {
        if (displayPath.endsWith('/') || displayPath.endsWith('\\')) {
          displayPath = '$displayPath$baseName.msone';
        } else {
          displayPath = '$displayPath${Platform.isWindows ? '\\' : '/'}$baseName.msone';
        }
      }
    }
    
    return displayPath;
  }

  /// Get display path for video file with proper URI decoding for Android
  String? _getDisplayVideoFilePath() {
    if (_videoPath == null) return null;
    
    String displayPath = _videoPath!;
    
    // For Android SAF URIs, decode to show human-readable path
    if (Platform.isAndroid && _videoPath!.startsWith('content://')) {
      try {
        // Use SafPathConverter for correct SAF URI to path conversion
        final decodedPath = SafPathConverter.normalizePath(_videoPath!);
        if (kDebugMode) {
          print('ProjectSettings _getDisplayVideoFilePath: originalPath=$_videoPath, correctedPath=$decodedPath');
        }
        
        // Check if the decoded path contains a filename (has an extension)
        if (decodedPath.isNotEmpty && !decodedPath.startsWith('content://')) {
          displayPath = decodedPath;
          
          // Clean up malformed paths that contain "primary:" pattern
          if (displayPath.contains('primary:')) {
            if (kDebugMode) {
              print('Found primary: pattern in decoded path, cleaning...');
            }
            
            // Split by "primary:" and take everything after the last occurrence
            final parts = displayPath.split('primary:');
            if (parts.length > 1) {
              displayPath = parts.last; // Take everything after the last "primary:"
              
              // Remove leading slash if present
              if (displayPath.startsWith('/')) {
                displayPath = displayPath.substring(1);
              }
              
              if (kDebugMode) {
                print('Cleaned path after removing primary:: $displayPath');
              }
            }
          }
          
          // If the cleaned path doesn't contain a filename, try to extract it from the original URI
          if (!displayPath.contains('.') || displayPath.endsWith('/') || displayPath.endsWith('\\')) {
            if (kDebugMode) {
              print('Path appears to be missing filename, attempting extraction from URI');
            }
            
            // Try to extract filename from the original URI
            try {
              final uri = Uri.parse(_videoPath!);
              
              // Method 1: Check query parameters for displayName
              final displayName = uri.queryParameters['displayName'];
              if (displayName != null && displayName.contains('.')) {
                if (displayPath.endsWith('/') || displayPath.endsWith('\\')) {
                  displayPath = '$displayPath$displayName';
                } else {
                  displayPath = '$displayPath${Platform.isWindows ? '\\' : '/'}$displayName';
                }
                if (kDebugMode) {
                  print('Added filename from URI displayName: $displayPath');
                }
              } else {
                // Method 2: Check path segments for filename
                if (uri.pathSegments.isNotEmpty) {
                  for (int i = uri.pathSegments.length - 1; i >= 0; i--) {
                    if (uri.pathSegments[i].contains('.')) {
                      final filename = uri.pathSegments[i];
                      if (displayPath.endsWith('/') || displayPath.endsWith('\\')) {
                        displayPath = '$displayPath$filename';
                      } else {
                        displayPath = '$displayPath${Platform.isWindows ? '\\' : '/'}$filename';
                      }
                      if (kDebugMode) {
                        print('Added filename from URI path segments: $displayPath');
                      }
                      break;
                    }
                  }
                }
              }
            } catch (uriError) {
              if (kDebugMode) {
                print('Error extracting filename from URI: $uriError');
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error decoding video file URI: $e');
        }
        // Keep original if decoding fails
        displayPath = _videoPath!;
      }
    }
    
    if (kDebugMode) {
      print('Final video display path: $displayPath');
    }
    
    return displayPath;
  }

  /// Get display path for secondary subtitle file with proper URI decoding for Android
  String? _getDisplaySecondarySubtitlePath() {
    if (_secondarySubtitlePath == null) return null;
    
    String displayPath = _secondarySubtitlePath!;
    
    // For Android SAF URIs, decode to show human-readable path
    if (Platform.isAndroid && _secondarySubtitlePath!.startsWith('content://')) {
      try {
        // Use SafPathConverter for correct SAF URI to path conversion
        final decodedPath = SafPathConverter.normalizePath(_secondarySubtitlePath!);
        if (kDebugMode) {
          print('ProjectSettings _getDisplaySecondarySubtitlePath: originalPath=$_secondarySubtitlePath, correctedPath=$decodedPath');
        }
        
        // Check if the decoded path contains a filename (has an extension)
        if (decodedPath.isNotEmpty && !decodedPath.startsWith('content://')) {
          displayPath = decodedPath;
          
          // Clean up malformed paths that contain "primary:" pattern
          if (displayPath.contains('primary:')) {
            if (kDebugMode) {
              print('Found primary: pattern in decoded path, cleaning...');
            }
            
            // Split by "primary:" and take everything after the last occurrence
            final parts = displayPath.split('primary:');
            if (parts.length > 1) {
              displayPath = parts.last; // Take everything after the last "primary:"
              
              // Remove leading slash if present
              if (displayPath.startsWith('/')) {
                displayPath = displayPath.substring(1);
              }
              
              if (kDebugMode) {
                print('Cleaned path after removing primary:: $displayPath');
              }
            }
          }
          
          // If the cleaned path doesn't contain a filename, try to extract it from the original URI
          if (!displayPath.contains('.') || displayPath.endsWith('/') || displayPath.endsWith('\\')) {
            if (kDebugMode) {
              print('Path appears to be missing filename, attempting extraction from URI');
            }
            
            // Try to extract filename from the original URI
            try {
              final uri = Uri.parse(_secondarySubtitlePath!);
              
              // Method 1: Check query parameters for displayName
              final displayName = uri.queryParameters['displayName'];
              if (displayName != null && displayName.contains('.')) {
                if (displayPath.endsWith('/') || displayPath.endsWith('\\')) {
                  displayPath = '$displayPath$displayName';
                } else {
                  displayPath = '$displayPath${Platform.isWindows ? '\\' : '/'}$displayName';
                }
                if (kDebugMode) {
                  print('Added filename from URI displayName: $displayPath');
                }
              } else {
                // Method 2: Check path segments for filename
                if (uri.pathSegments.isNotEmpty) {
                  for (int i = uri.pathSegments.length - 1; i >= 0; i--) {
                    if (uri.pathSegments[i].contains('.')) {
                      final filename = uri.pathSegments[i];
                      if (displayPath.endsWith('/') || displayPath.endsWith('\\')) {
                        displayPath = '$displayPath$filename';
                      } else {
                        displayPath = '$displayPath${Platform.isWindows ? '\\' : '/'}$filename';
                      }
                      if (kDebugMode) {
                        print('Added filename from URI path segments: $displayPath');
                      }
                      break;
                    }
                  }
                }
              }
            } catch (uriError) {
              if (kDebugMode) {
                print('Error extracting filename from URI: $uriError');
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error decoding secondary subtitle file URI: $e');
        }
        // Keep original if decoding fails
        displayPath = _secondarySubtitlePath!;
      }
    }
    
    if (kDebugMode) {
      print('Final secondary subtitle display path: $displayPath');
    }
    
    return displayPath;
  }

  /// Helper method to extract filename from SAF URI
  /// Opens the file location in the system file manager
  Future<void> _openFileLocation(String filePath) async {
    try {
      if (Platform.isAndroid) {
        _showAndroidFileLocationDialog(filePath);
      } else {
        await _openDesktopFileLocation(filePath);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to open file location for $filePath: $e');
      }
      _showFileLocationErrorDialog(filePath);
    }
  }

  /// Show file location dialog for Android with modern design
  void _showAndroidFileLocationDialog(String filePath) {
    // Determine if this is a SAF URI and get display path
    final bool isSafUri = filePath.startsWith('content://');
    String displayPath = filePath;
    
    if (isSafUri) {
      try {
        // Use SafPathConverter for correct SAF URI to path conversion
        displayPath = SafPathConverter.normalizePath(filePath);
        
        if (kDebugMode) {
          print('AndroidFileLocationDialog: originalPath=$filePath, correctedPath=$displayPath');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error in AndroidFileLocationDialog path conversion: $e');
        }
        // Keep original if decoding fails
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSafUri ? Icons.security : Icons.folder_open,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File Location',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isSafUri ? 'Secure Storage Location' : 'Local File Path',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // File path section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'File Path',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      displayPath,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Information section
              if (isSafUri) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'About Storage Access Framework',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This file is securely managed by Android\'s Storage Access Framework (SAF). '
                        'The location shown above represents the actual file path on your device\'s storage. '
                        'SAF ensures secure access while maintaining proper file permissions.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Direct File Access',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This file is stored in a directly accessible location on your device. '
                        'The path shown above is the exact location where the file resides.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _copyToClipboard(displayPath);
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Path'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle desktop file location opening
  Future<void> _openDesktopFileLocation(String filePath) async {
    final file = File(filePath);
    final directory = file.parent.path;
    
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      // Try to open the parent directory
      final uri = Uri.file(directory);
      await launchUrl(uri);
    }
    
    SnackbarHelper.showSnackBar(
      context,
      'File location opened in file manager',
      backgroundColor: Colors.green,
    );
  }

  /// Show error dialog for file location access
  void _showFileLocationErrorDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with error icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unable to Open Location',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'File manager could not be opened',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // File path section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'File Path',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      filePath,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Error section
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Error Details',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to open this file location. Copy the path and open it manually if needed.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _copyToClipboard(filePath);
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Path'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
