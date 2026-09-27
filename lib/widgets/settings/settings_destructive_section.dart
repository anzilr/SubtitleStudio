part of '../settings_sheet.dart';

extension _SettingsDestructiveSection on _SettingsSheetState {
  Widget _buildDestructiveSettingsSection() {
    return Column(
      children: [
        // Clear Preferences Button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: ElevatedButton(
              onPressed: () async {
                // Confirmation dialog
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Settings'),
                    content: const Text('Are you sure you want to reset all settings to default values?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Reset', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                
                if (result == true) {
                  _geminiApiKeySaveTimer?.cancel();
                  _geminiApiKeySaveTimer = null;
                  GeminiModelsService.clearCache();

                  await _preferencesRepository.clearAllPreferences();
                  await _loadSettings(); // Reload settings after clearing
                  if (widget.onSettingsChanged != null) {
                    widget.onSettingsChanged!();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset All Settings'),
            ),
          ),
        ),
        
        // Clear All Data Button
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Center(
            child: ElevatedButton.icon(
              onPressed: () async {
                // Show comprehensive warning dialog
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => Dialog(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.delete_forever, color: Colors.red[700], size: 32),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Clear All Data',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 2),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber, color: Colors.red, size: 24),
                                      SizedBox(width: 8),
                                      Text(
                                        'WARNING',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'This action will permanently delete:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text('• All subtitle files and editing sessions'),
                                  Text('• All app settings and preferences'),
                                  Text('• Edit history and checkpoints'),
                                  Text('• Video preferences and associations'),
                                  Text('• Cached waveform data'),
                                  Text('• All temporary files'),
                                  SizedBox(height: 12),
                                  Text(
                                    'Dictionary data will be preserved.',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'This action cannot be undone!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    backgroundColor: Colors.red[700],
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Clear All Data'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                
                if (result == true && mounted) {
                  _geminiApiKeySaveTimer?.cancel();
                  _geminiApiKeySaveTimer = null;
                  GeminiModelsService.clearCache();

                  // Store navigator for safe navigation after async
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Clearing all data...'),
                        ],
                      ),
                    ),
                  );
                  
                  try {
                    // Clear all application data
                    await ref
                        .read(appDataMaintenanceRepositoryProvider)
                        .clearAllApplicationData();
                    
                    if (!mounted) return;
                    
                    // Close loading dialog
                    navigator.pop();
                    
                    // Show success message
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('All data cleared successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Reload settings to show defaults
                    await _loadSettings();
                    
                    // Notify parent about changes
                    if (widget.onSettingsChanged != null) {
                      widget.onSettingsChanged!();
                    }
                    
                    // Close settings sheet and navigate to home
                    navigator.pop();
                    
                    // Navigate to home screen (clear stack)
                    navigator.pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    
                    // Close loading dialog
                    navigator.pop();
                    
                    // Show error message
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not clear all application data. Please try again.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear All Data'),
            ),
          ),
        ),
      ],
    );
  }
}
