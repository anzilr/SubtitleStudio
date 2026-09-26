// Subtitle Studio v3 - Log Management Widget
// 
// This widget provides comprehensive log management functionality for debugging
// and error tracking. It integrates with the app's logging system to provide
// users and developers with tools to:
// - View log statistics and file information
// - Export logs for debugging purposes
// - Share logs via email and messaging platforms
// // - Clear log files when needed
// - Copy log directory paths for manual access
//
// Key Features for iOS Port:
// // - Use iOS document picker for export functionality
// - Implement iOS-specific file management
// - Replace overlay snackbars with iOS toast notifications

import 'dart:io';                              // File system operations
import 'package:flutter/material.dart';       // Flutter UI framework
import 'package:flutter/services.dart';       // Clipboard and system services
import 'package:path_provider/path_provider.dart'; // App directory access
// Cross-platform sharing
import '../utils/app_logger.dart';            // Application logging system

/// A comprehensive widget for managing application logs and debugging information
/// 
/// This widget serves as a central hub for log management with the following capabilities:
/// 
/// **Core Features:**
/// - Real-time log statistics display (file count, total size, date ranges)
/// - Export logs to timestamped files for debugging
/// - Share logs via system sharing interface
/// /// - Bulk log file cleanup functionality
/// - Copy log directory path to clipboard
/// 
/// **Developer Integration:**
/// /// - Structured log export with metadata
/// - Context-aware error reporting
/// - Progress indicators for long-running operations
/// 
/// **User Experience:**
/// - Custom overlay notifications that work above modal sheets
/// - Loading states for all operations
/// - Confirmation dialogs for destructive actions
/// - Accessible design with proper focus management
/// 
/// **iOS Port Considerations:**
/// /// - Use NSFileManager for file operations
/// - Implement iOS document provider for log access
/// - Replace overlay notifications with iOS toast equivalents
class LogManagementWidget extends StatefulWidget {
  const LogManagementWidget({super.key});

  @override
  State<LogManagementWidget> createState() => _LogManagementWidgetState();
}

/// State management class for LogManagementWidget
/// 
/// Handles all log management operations including statistics loading,
/// file operations, network communications, and user interface updates.
/// 
/// **State Variables:**
/// - `_logStats`: Current log file statistics (count, size, date ranges)
/// - `_logFiles`: List of available log files for operations
/// - `_isLoading`: Loading state indicator for UI feedback
/// - `_lastExportPath`: Cached path of last exported log file
/// 
/// **Key Operations:**
/// - Log statistics loading and refreshing
/// - File export with timestamp generation
/// - Telegram API integration for bug reporting
/// - File cleanup with confirmation dialogs
/// - Clipboard operations for path sharing
/// 
/// **Error Handling:**
/// - All operations wrapped in try-catch blocks
/// - Comprehensive logging of errors with context
/// - User-friendly error messages via overlay notifications
/// - Graceful degradation when operations fail
class _LogManagementWidgetState extends State<LogManagementWidget> {
  /// Current log file statistics including count, size, and date information
  /// Structure: {totalFiles, totalSizeReadable, newestLog, oldestLog}
  Map<String, dynamic>? _logStats;
  
  /// List of log files available for operations (export, cleanup, etc.)
  List<File> _logFiles = [];
  
  /// Loading state indicator for UI feedback during async operations
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadLogStats();
  }

  Future<void> _loadLogStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load stats and files without generating additional log entries
      final stats = await AppLogger.instance.getLogStats();
      final files = await AppLogger.instance.getLogFiles();
      
      setState(() {
        _logStats = stats;
        _logFiles = files;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      
      await AppLogger.instance.error('Failed to load log statistics: $e', stackTrace: stackTrace, context: 'LogManagementWidget._loadLogStats');
      
      if (mounted) {
        _showSnackBar(
          'Failed to load log statistics: $e',
          Colors.red,
        );
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Export logs without generating additional log entries during the process
      final exportPath = await AppLogger.instance.exportLogsToFile();
      
      setState(() {
        _isLoading = false;
      });

      // Refresh log statistics to reflect any changes
      await _loadLogStats();

      if (mounted) {
        _showSnackBar(
          'Logs exported successfully!\nPath: $exportPath',
          Colors.green,
          duration: 5,
        );
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      
      await AppLogger.instance.error('Failed to export logs: $e', stackTrace: stackTrace, context: 'LogManagementWidget._exportLogs');
      
      if (mounted) {
        _showSnackBar('Failed to export logs: $e', Colors.red, duration: 5);
      }
    }
  }

  
  
  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text(
          'Are you sure you want to delete all log files? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Get and delete all log files
        final logFiles = await AppLogger.instance.getLogFiles();
        
        for (final file in logFiles) {
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            // Silent cleanup - don't log failures during cleanup
          }
        }
        
        // Also delete exported files from documents directory
        try {
          final documentsDir = await getApplicationDocumentsDirectory();
          if (await documentsDir.exists()) {
            final exportFiles = await documentsDir
                .list()
                .where((entity) => entity is File && entity.path.contains('MSoneSubEditor_Logs_'))
                .cast<File>()
                .toList();
            
            for (final file in exportFiles) {
              try {
                await file.delete();
              } catch (e) {
                // Silent cleanup - don't log failures during cleanup
              }
            }
          }
        } catch (e) {
          // Silent cleanup - don't log failures during cleanup
        }
        
        // Clear app logger and reinitialize
        await AppLogger.instance.clearLogs();
        
        setState(() {
          _logStats = null;
          _logFiles = [];
          _lastExportPath = null;
        });
        
        await _loadLogStats();
        
        if (mounted) {
          _showSnackBar('All log files cleared successfully', Colors.green);
        }
      } catch (e, stackTrace) {
        setState(() {
          _isLoading = false;
        });
        
        await AppLogger.instance.error('Failed to clear logs: $e', stackTrace: stackTrace, context: 'LogManagementWidget._clearLogs');
        
        if (mounted) {
          _showSnackBar('Failed to clear logs: $e', Colors.red);
        }
      }
    }
  }

  Future<void> _copyLogPath() async {
    try {
      if (_logFiles.isNotEmpty) {
        final logDirPath = _logFiles.first.parent.path;
        await Clipboard.setData(ClipboardData(text: logDirPath));
        
        if (mounted) {
          _showSnackBar('Path copied: $logDirPath', Colors.green, duration: 3);
        }
      } else {
        const message = 'No log files found';
        
        if (mounted) {
          _showSnackBar(message, Colors.orange);
        }
      }
    } catch (e, stackTrace) {
      await AppLogger.instance.error('Failed to copy log path: $e', stackTrace: stackTrace, context: 'LogManagementWidget._copyLogPath');
      
      if (mounted) {
        _showSnackBar('Failed to copy path: $e', Colors.red);
      }
    }
  }

  /// Show SnackBar that works properly in modal sheets
  void _showSnackBar(String message, Color backgroundColor, {int duration = 4}) {
    // Get the overlay state from the root navigator to show snackbar above modal
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  backgroundColor == Colors.red ? Icons.error : 
                  backgroundColor == Colors.green ? Icons.check_circle :
                  backgroundColor == Colors.orange ? Icons.warning :
                  Icons.info,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Remove the overlay after specified duration
    Future.delayed(Duration(seconds: duration), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
          
          if (_logStats != null && !_isLoading) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Log Statistics',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh Statistics',
                  onPressed: _loadLogStats,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatRow('Total Log Files', '${_logStats!['totalFiles'] ?? 0}'),
            _buildStatRow('Total Size', _logStats!['totalSizeReadable'] ?? 'Unknown'),
            if (_logStats!['newestLog'] != null)
              _buildStatRow(
                'Latest Log',
                DateTime.parse(_logStats!['newestLog']).toLocal().toString().split('.').first,
              ),
            if (_logStats!['oldestLog'] != null)
              _buildStatRow(
                'Oldest Log',
                DateTime.parse(_logStats!['oldestLog']).toLocal().toString().split('.').first,
              ),
          ],
          
          const SizedBox(height: 16),
          
          if (!_isLoading) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  debugPrint('Export button pressed - calling _exportLogs');
                  await _exportLogs();
                },
                icon: const Icon(Icons.file_download),
                label: const Text('Export Logs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Share Log File button - commented out for future use
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton.icon(
            //     onPressed: _shareLogFile,
            //     icon: const Icon(Icons.share),
            //     label: const Text('Share Log File'),
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: Colors.green,
            //       foregroundColor: Colors.white,
            //       padding: const EdgeInsets.symmetric(vertical: 12),
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyLogPath,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Path'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearLogs,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          
          Text(
            'Logs help developers troubleshoot issues. Use "Export Logs" to create a '
            'comprehensive report, or "Send" to report bugs directly to the developer.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contact Information Section - commented out for future use
          // Container(
          //   padding: const EdgeInsets.all(12),
          //   decoration: BoxDecoration(
          //     color: Colors.blue.withOpacity(0.05),
          //     borderRadius: BorderRadius.circular(8),
          //     border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1.5),
          //   ),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Text(
          //         'Developer Contact Information',
          //         style: Theme.of(context).textTheme.titleSmall?.copyWith(
          //           fontWeight: FontWeight.bold,
          //         ),
          //       ),
          //       const SizedBox(height: 8),
          //       
          //       // Email
          //       Row(
          //         children: [
          //           Icon(Icons.email, color: Colors.grey[600], size: 16),
          //           const SizedBox(width: 8),
          //           const Text('Email: '),
          //           Expanded(
          //             child: GestureDetector(
          //               onTap: () => _copyToClipboard('quadbitlab@gmail.com', 'Email'),
          //               child: Container(
          //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //                 decoration: BoxDecoration(
          //                   color: Colors.blue.withOpacity(0.1),
          //                   borderRadius: BorderRadius.circular(4),
          //                   border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
          //                 ),
          //                 child: Row(
          //                   mainAxisSize: MainAxisSize.min,
          //                   children: [
          //                     const Text(
          //                       'quadbitlab@gmail.com',
          //                       style: TextStyle(
          //                         color: Colors.blue,
          //                         fontWeight: FontWeight.w500,
          //                       ),
          //                     ),
          //                     const SizedBox(width: 4),
          //                     Icon(Icons.copy, size: 14, color: Colors.blue[600]),
          //                   ],
          //                 ),
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //       const SizedBox(height: 8),
          //       
          //       // Telegram
          //       Row(
          //         children: [
          //           Icon(Icons.telegram, color: Colors.grey[600], size: 16),
          //           const SizedBox(width: 8),
          //           const Text('Telegram: '),
          //           Expanded(
          //             child: GestureDetector(
          //               onTap: () => _copyToClipboard('@anzilr', 'Telegram ID'),
          //               child: Container(
          //                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //                 decoration: BoxDecoration(
          //                   color: Colors.blue.withOpacity(0.1),
          //                   borderRadius: BorderRadius.circular(4),
          //                   border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
          //                 ),
          //                 child: Row(
          //                   mainAxisSize: MainAxisSize.min,
          //                   children: [
          //                     const Text(
          //                       '@anzilr',
          //                       style: TextStyle(
          //                         color: Colors.blue,
          //                         fontWeight: FontWeight.w500,
          //                       ),
          //                     ),
          //                     const SizedBox(width: 4),
          //                     Icon(Icons.copy, size: 14, color: Colors.blue[600]),
          //                   ],
          //                 ),
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //       
          //       const SizedBox(height: 8),
          //       Text(
          //         'Tap on the contact information above to copy to clipboard.',
          //         style: Theme.of(context).textTheme.bodySmall?.copyWith(
          //           color: Colors.grey[500],
          //           fontSize: 11,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
