part of '../settings_sheet.dart';

extension _SettingsWaveformSection on _SettingsSheetState {
  Widget _buildWaveformSettingsSection() {
    return Column(
      children: [
        // Waveform Settings Section
        ExpansionTile(
          key: _waveformSectionKey,
          leading: const Icon(Icons.graphic_eq, color: Colors.purple),
          title: const Text('Waveform Settings'),
          subtitle: const Text('Configure waveform zoom detail and performance'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Warning Card
            Card(
              color: Colors.orange.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Changing these settings may affect performance. Higher values = more detail but slower processing.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Max Pixels for Detailed View
            ListTile(
              title: const Text('Max Zoom Detail (pixels)'),
              subtitle: Text('Current: $_waveformMaxPixels pixels\nDefault: 500,000 • Higher = More zoom levels'),
              trailing: SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _waveformMaxPixelsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onFieldSubmitted: (value) async {
                    final newValue = int.tryParse(value);
                    if (newValue != null && newValue >= 100000 && newValue <= 5000000) {
                      await PreferencesModel.setWaveformMaxPixels(newValue);
                      _setSettingsState(() {
                        _waveformMaxPixels = newValue;
                      });
                      if (widget.onSettingsChanged != null) {
                        widget.onSettingsChanged!();
                      }
                    } else {
                      _waveformMaxPixelsController.text = _waveformMaxPixels.toString();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Value must be between 100,000 and 5,000,000')),
                      );
                    }
                  },
                ),
              ),
            ),
            
            // Sample Rate Factor
            ListTile(
              title: const Text('Sample Rate Factor'),
              subtitle: Text('Current: $_waveformSampleRateFactor\nDefault: 16 • Lower = More audio detail'),
              trailing: SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _waveformSampleRateFactorController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onFieldSubmitted: (value) async {
                    final newValue = int.tryParse(value);
                    if (newValue != null && newValue >= 1 && newValue <= 64) {
                      await PreferencesModel.setWaveformSampleRateFactor(newValue);
                      _setSettingsState(() {
                        _waveformSampleRateFactor = newValue;
                      });
                      if (widget.onSettingsChanged != null) {
                        widget.onSettingsChanged!();
                      }
                    } else {
                      _waveformSampleRateFactorController.text = _waveformSampleRateFactor.toString();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Value must be between 1 and 64')),
                      );
                    }
                  },
                ),
              ),
            ),
            
            // Zoom Multiplier
            ListTile(
              title: const Text('Zoom Multiplier'),
              subtitle: Text('Current: ${_waveformZoomMultiplier.toStringAsFixed(2)}\nDefault: 1.35 • Lower = More zoom steps'),
              trailing: SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _waveformZoomMultiplierController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onFieldSubmitted: (value) async {
                    final newValue = double.tryParse(value);
                    if (newValue != null && newValue >= 1.1 && newValue <= 3.0) {
                      await PreferencesModel.setWaveformZoomMultiplier(newValue);
                      _setSettingsState(() {
                        _waveformZoomMultiplier = newValue;
                      });
                      _waveformZoomMultiplierController.text = newValue.toStringAsFixed(2);
                      if (widget.onSettingsChanged != null) {
                        widget.onSettingsChanged!();
                      }
                    } else {
                      _waveformZoomMultiplierController.text = _waveformZoomMultiplier.toStringAsFixed(2);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Value must be between 1.1 and 3.0')),
                      );
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            Text(
              'Note: Waveform cache will be cleared on next video load to apply changes.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            // Reset to Defaults Button
            ElevatedButton.icon(
              onPressed: () async {
                // Reset to default values
                await PreferencesModel.setWaveformMaxPixels(500000);
                await PreferencesModel.setWaveformSampleRateFactor(16);
                await PreferencesModel.setWaveformZoomMultiplier(1.35);
                
                _setSettingsState(() {
                  _waveformMaxPixels = 500000;
                  _waveformSampleRateFactor = 16;
                  _waveformZoomMultiplier = 1.35;
                  _waveformMaxPixelsController.text = '500000';
                  _waveformSampleRateFactorController.text = '16';
                  _waveformZoomMultiplierController.text = '1.35';
                });
                
                if (widget.onSettingsChanged != null) {
                  widget.onSettingsChanged!();
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Waveform settings reset to defaults'),
                    backgroundColor: Color(0xFF323232),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.restore),
              label: const Text('Reset to Defaults'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        
        const Divider(),
      ],
    );
  }
}
