part of '../settings_sheet.dart';

extension _SettingsGeminiSection on _SettingsSheetState {
  Widget _buildGeminiSettingsSection() {
    return Column(
      children: [
        // Gemini AI Settings Section
        ListTile(
          leading: const Icon(Icons.auto_awesome, color: Colors.deepPurple),
          title: const Text('Gemini AI Settings'),
          subtitle: const Text('Configure AI explanation features (accessible in dictionary menu)'),
        ),
        
        // Gemini API Key Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _geminiApiKeyController,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: 'Enter your Gemini API key',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vpn_key, color: Colors.deepPurple),
                  suffixIcon: _geminiApiKey != null && _geminiApiKey!.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () async {
                            _geminiApiKeyController.clear();
                            await PreferencesModel.setGeminiApiKey(null);
                            _setSettingsState(() {
                              _geminiApiKey = null;
                            });
                            if (widget.onSettingsChanged != null) {
                              widget.onSettingsChanged!();
                            }
                            if (mounted) {
                              SnackbarHelper.showSuccess(
                                context,
                                'Gemini API key removed',
                              );
                            }
                          },
                        )
                      : null,
                ),
                obscureText: true,
                onChanged: (value) async {
                  await PreferencesModel.setGeminiApiKey(value.isEmpty ? null : value);
                  _setSettingsState(() {
                    _geminiApiKey = value.isEmpty ? null : value;
                  });
                  if (widget.onSettingsChanged != null) {
                    widget.onSettingsChanged!();
                  }
                  // Refresh available models when API key changes
                  if (value.isNotEmpty) {
                    GeminiModelsService.clearCache();
                    _fetchAvailableModels();
                  }
                },
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse('https://aistudio.google.com');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (mounted) {
                      SnackbarHelper.showError(
                        context,
                        'Could not open browser. Please visit aistudio.google.com manually.',
                      );
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Get your API key from ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'aistudio.google.com',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Gemini Model Selection
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                children: [
                  const Icon(Icons.model_training, color: Colors.purple, size: 24),
                  const SizedBox(width: 16),
                  const Text(
                    'AI Model',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  if (_isLoadingModels) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Dropdown Row
              Row(
                children: [
                  Expanded(
                    child: _availableModels.isEmpty
                        ? OutlinedButton.icon(
                            onPressed: _fetchAvailableModels,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Models'),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _geminiModel.startsWith('models/') 
                                ? _geminiModel 
                                : 'models/$_geminiModel',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _availableModels.map((model) {
                              final displayName = model.displayName ?? 
                                  GeminiModelsService.getModelDisplayName(model.name ?? '');
                              return DropdownMenuItem<String>(
                                value: model.name,
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                await PreferencesModel.setGeminiModel(value);
                                _setSettingsState(() {
                                  _geminiModel = value;
                                });
                                if (widget.onSettingsChanged != null) {
                                  widget.onSettingsChanged!();
                                }
                              }
                            },
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const Divider(),
      ],
    );
  }
}
