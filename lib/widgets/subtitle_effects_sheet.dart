import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/operations/srt_effect_frames.dart';
import '../utils/time_parser.dart';

class SubtitleEffectsSheet extends StatefulWidget {
  final List<int> selectedIndices;
  final Function(String effectType, Map<String, dynamic> effectConfig) onApplyEffect;
  final List<SubtitleLine>? subtitleLines; // Optional: for single line effects
  final int? subtitleCollectionId; // Optional: for database operations
  final String? lineText; // Optional: for single line text selection

  const SubtitleEffectsSheet({
    super.key,
    required this.selectedIndices,
    required this.onApplyEffect,
    this.subtitleLines,
    this.subtitleCollectionId,
    this.lineText,
  });

  @override
  State<SubtitleEffectsSheet> createState() => _SubtitleEffectsSheetState();
}

class _SubtitleEffectsSheetState extends State<SubtitleEffectsSheet> with SingleTickerProviderStateMixin {
  String _selectedEffect = 'karaoke';
  Color _karaokeColor = Colors.yellow;
  Color _typewriterColor = Colors.white;
  Color _alternateColor = Colors.amber;
  double _endDelay = 0.0; // End delay in seconds (0.0 to 1.0)
  String _karaokeEffectType = 'word'; // 'word' or 'character'
  String _movingKaraokeUnit = 'word';
  bool _isProcessing = false;
  // Preview animation
  late AnimationController _previewController;
  double _previewProgress = 0.0; // 0.0 - 1.0 across the animation part
  bool _isPreviewPlaying = false;
  Duration _lineDuration = const Duration(seconds: 3); // total available duration (from subtitle times)
  Duration _animDuration = const Duration(seconds: 3); // duration used for the animated reveal (subtracting endDelay)
  Duration _endDelayDuration = Duration.zero;
  Timer? _postDelayTimer;
  
  // Text selection for karaoke effect
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    // Initialize text controller with the line text if available
    final initialText = widget.lineText ?? '';
    _textController = TextEditingController(text: initialText);
    _previewController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..addListener(() {
        setState(() {
          _previewProgress = _previewController.value;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Keep full text visible for endDelay, then stop
          if (_endDelayDuration > Duration.zero) {
            _postDelayTimer?.cancel();
            _postDelayTimer = Timer(_endDelayDuration, () {
              setState(() => _isPreviewPlaying = false);
            });
          } else {
            setState(() => _isPreviewPlaying = false);
          }
        }
      });
    _recomputePreviewDurations();
  }

  @override
  void dispose() {
  _previewController.dispose();
  _postDelayTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic color variables for adaptive theming
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = onSurfaceColor.withValues(alpha: 0.6);
    final borderColor = onSurfaceColor.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Add Effects",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Apply visual effects to ${widget.selectedIndices.length} selected subtitle${widget.selectedIndices.length > 1 ? 's' : ''}",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: mutedColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "This is a beta feature. Use with caution.",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Consistent compact choices for all SRT text effects.
              Text('Choose an effect',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final choice in const [
                  ('karaoke', 'Karaoke', Icons.music_note),
                  ('typewriter', 'Typewriter', Icons.keyboard),
                  ('wordReveal', 'Word reveal', Icons.subject),
                  ('movingKaraoke', 'Moving karaoke', Icons.music_note),
                  ('activeTypewriter', 'Active character', Icons.keyboard_alt),
                  ('backspace', 'Backspace', Icons.backspace_outlined),
                  ('lineReveal', 'Line reveal', Icons.segment),
                  ('colorTransition', 'Color transition', Icons.palette_outlined),
                  ('blinkFlash', 'Blink / Flash', Icons.flash_on_outlined),
                  ('rainbowText', 'Rainbow text', Icons.gradient_outlined),
                  ('scrambleReveal', 'Scramble reveal', Icons.shuffle_rounded),
                  ('spotlightKaraoke', 'Spotlight karaoke', Icons.highlight_alt_rounded),
                  ('typewriterCursor', 'Typewriter + cursor', Icons.edit_note_rounded),
                  ('centerOutReveal', 'Center-out reveal', Icons.center_focus_strong_rounded),
                ])
                  ChoiceChip(
                    key: ValueKey('srt-effect-${choice.$1}'),
                    label: Text(choice.$2),
                    avatar: Icon(choice.$3, size: 16),
                    selected: _selectedEffect == choice.$1,
                    onSelected: (_) => setState(() {
                      _selectedEffect = choice.$1;
                      _previewController.stop();
                      _previewController.value = 0;
                      _isPreviewPlaying = false;
                    }),
                  ),
              ]),

              const SizedBox(height: 24),

              // Effect Configuration Section
              if (_selectedEffect == 'karaoke') _buildKaraokeConfig(isDark, onSurfaceColor, mutedColor, borderColor),
              if (_selectedEffect == 'typewriter') _buildTypewriterConfig(isDark, onSurfaceColor, mutedColor, borderColor),
              if (SrtEffectFrames.supported.contains(_selectedEffect))
                _buildNewEffectConfig(),

              const SizedBox(height: 24),

              // Preview
              _buildPreviewCard(),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: onSurfaceColor,
                          side: BorderSide(
                            color: onSurfaceColor.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close,
                              size: 20,
                              color: onSurfaceColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Cancel",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: onSurfaceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _applyEffect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Apply",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
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

  Widget _buildKaraokeConfig(bool isDark, Color onSurfaceColor, Color mutedColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Karaoke Configuration",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Text Selection Field (only show if we have line text)
        if (widget.lineText != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.text_format,
                      color: onSurfaceColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Text Selection",
                      style: TextStyle(
                        color: onSurfaceColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Select part of the text to apply effect only to that selection",
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  // readOnly: true,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    color: onSurfaceColor,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: "Select text to apply karaoke effect...",
                    hintStyle: TextStyle(
                      color: mutedColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (text) {
                    // Text changed - selection state is handled in _applyEffect
                  },
                  onTap: () {
                    // User tapped - selection state is handled in _applyEffect
                  },
                ),
                const SizedBox(height: 8),
                if (_textController.selection.start != _textController.selection.end)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _karaokeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Selected: \"${_textController.selection.textInside(_textController.text)}\"",
                      style: TextStyle(
                        color: onSurfaceColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (_textController.selection.start == _textController.selection.end && _textController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Effect will be applied to entire text",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Color Selection
        Container(
          decoration: BoxDecoration(
            color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _karaokeColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
            ),
            title: Text(
              "Highlight Color",
              style: TextStyle(
                color: onSurfaceColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              "Choose the karaoke highlight color",
              style: TextStyle(
                color: mutedColor,
              ),
            ),
            trailing: Icon(
              Icons.color_lens,
              color: onSurfaceColor,
            ),
            onTap: _showKaraokeColorPicker,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Effect Type Selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.text_fields,
                    color: onSurfaceColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Effect Type",
                    style: TextStyle(
                      color: onSurfaceColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _karaokeEffectType,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _karaokeEffectType = value);
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                         type: MaterialType.transparency,
                         child: RadioListTile<String>(
                        title: Text(
                          "Word",
                          style: TextStyle(color: onSurfaceColor),
                        ),
                        subtitle: Text(
                          "Highlight word by word",
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                        value: 'word',
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                         ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                         type: MaterialType.transparency,
                         child: RadioListTile<String>(
                        title: Text(
                          "Character",
                          style: TextStyle(color: onSurfaceColor),
                        ),
                        subtitle: Text(
                          "Highlight character by character",
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                        value: 'character',
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                         ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // End Delay Configuration
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: onSurfaceColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "End Delay",
                    style: TextStyle(
                      color: onSurfaceColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${(_endDelay * 1000).round()}ms - Show full text before end",
                style: TextStyle(
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Theme.of(context).primaryColor,
                  inactiveTrackColor: borderColor,
                  thumbColor: Theme.of(context).primaryColor,
                  overlayColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _endDelay,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  onChanged: (value) => setState(() => _endDelay = value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypewriterConfig(bool isDark, Color onSurfaceColor, Color mutedColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Typewriter Configuration",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Color Selection
        Container(
          decoration: BoxDecoration(
            color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _typewriterColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
            ),
            title: Text(
              "Text Color",
              style: TextStyle(
                color: onSurfaceColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              "Choose the typewriter text color",
              style: TextStyle(
                color: mutedColor,
              ),
            ),
            trailing: Icon(
              Icons.color_lens,
              color: onSurfaceColor,
            ),
            onTap: _showTypewriterColorPicker,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // End Delay Configuration
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: onSurfaceColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "End Delay",
                    style: TextStyle(
                      color: onSurfaceColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${(_endDelay * 1000).round()}ms - Show full text before end",
                style: TextStyle(
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Theme.of(context).primaryColor,
                  inactiveTrackColor: borderColor,
                  thumbColor: Theme.of(context).primaryColor,
                  overlayColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _endDelay,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  onChanged: (value) => setState(() => _endDelay = value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showKaraokeColorPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        Color selectedColor = _karaokeColor;
        
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
            final mutedColor = onSurfaceColor.withValues(alpha: 0.6);
            
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selectedColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.palette,
                              color: selectedColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Karaoke Highlight Color",
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Choose the color for highlighted text",
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Color Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: onSurfaceColor.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Preview",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                              ),
                              children: [
                                TextSpan(
                                  text: "Highlighted ",
                                  style: TextStyle(color: selectedColor, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: "normal text",
                                  style: TextStyle(color: onSurfaceColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Color Picker
                    SizedBox(
                      height: 300,
                      child: SingleChildScrollView(
                        child: ColorPicker(
                          color: selectedColor,
                          onColorChanged: (color) => setState(() => selectedColor = color),
                          pickersEnabled: const <ColorPickerType, bool>{
                            ColorPickerType.primary: false,
                            ColorPickerType.accent: false,
                            ColorPickerType.wheel: true,
                          },
                          enableShadesSelection: true,
                          showColorCode: true,
                          showMaterialName: true,
                          showRecentColors: true,
                          maxRecentColors: 8,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: onSurfaceColor,
                                side: BorderSide(
                                  color: onSurfaceColor.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: onSurfaceColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                this.setState(() => _karaokeColor = selectedColor);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedColor,
                                foregroundColor: selectedColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Select Color",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTypewriterColorPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        Color selectedColor = _typewriterColor;
        
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
            final mutedColor = onSurfaceColor.withValues(alpha: 0.6);
            
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selectedColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.text_format,
                              color: selectedColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Typewriter Text Color",
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Choose the color for typewriter text",
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Color Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: onSurfaceColor.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Preview",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Sample typewriter text",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: selectedColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Color Picker
                    SizedBox(
                      height: 300,
                      child: SingleChildScrollView(
                        child: ColorPicker(
                          color: selectedColor,
                          onColorChanged: (color) => setState(() => selectedColor = color),
                          pickersEnabled: const <ColorPickerType, bool>{
                            ColorPickerType.primary: false,
                            ColorPickerType.accent: false,
                            ColorPickerType.wheel: true,
                          },
                          enableShadesSelection: true,
                          showColorCode: true,
                          showMaterialName: true,
                          showRecentColors: true,
                          maxRecentColors: 8,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: onSurfaceColor,
                                side: BorderSide(
                                  color: onSurfaceColor.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: onSurfaceColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                this.setState(() => _typewriterColor = selectedColor);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedColor,
                                foregroundColor: selectedColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Select Color",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _recomputePreviewDurations() {
    // If subtitleLines provided, use first selected line to compute durations
    if (widget.subtitleLines != null && widget.subtitleLines!.isNotEmpty) {
      final line = widget.subtitleLines!.first;
      try {
        final start = parseTimeString(line.startTime);
        final end = parseTimeString(line.endTime);
        _lineDuration = end - start;
      } catch (e) {
        _lineDuration = const Duration(seconds: 3);
      }
    } else {
      // Otherwise infer duration from UI defaults
      _lineDuration = const Duration(seconds: 3);
    }

    // Compute end delay from _endDelay (value 0.0-1.0 representing seconds up to 1s)
    _endDelayDuration = Duration(milliseconds: (_endDelay * 1000).round());

    // Animation duration is lineDuration minus endDelay (minimum 200ms)
    final raw = _lineDuration - _endDelayDuration;
    _animDuration = raw > const Duration(milliseconds: 200) ? raw : const Duration(milliseconds: 200);

    // Update controller
    _previewController.duration = _animDuration;
    _previewProgress = 0.0;
  }

  Widget _buildNewEffectConfig() {
    final targetColorNeeded = _selectedEffect == 'activeTypewriter' ||
        _selectedEffect == 'colorTransition';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SRT effect settings', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (_selectedEffect == 'rainbowText')
        const Text('Seven bright colors rotate through complete characters. '
            'The palette is built into this effect.')
      else Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Text / highlight color'),
          subtitle: const Text('Uses standard SRT font color tags'),
          trailing: CircleAvatar(backgroundColor: _typewriterColor, radius: 14),
          onTap: _showTypewriterColorPicker,
        ),
      ),
      if (_selectedEffect == 'movingKaraoke') ...[
        const SizedBox(height: 12),
        Text('Move the highlight by',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final choice in const [
            ('word', 'Word'),
            ('character', 'Character / letter'),
          ])
            ChoiceChip(
              key: ValueKey('moving-karaoke-unit-${choice.$1}'),
              label: Text(choice.$2),
              selected: _movingKaraokeUnit == choice.$1,
              onSelected: (_) => setState(() {
                _movingKaraokeUnit = choice.$1;
                _previewController.stop();
                _previewController.value = 0;
                _isPreviewPlaying = false;
              }),
            ),
        ]),
        const SizedBox(height: 8),
        Text('Characters follow complete Unicode graphemes, including '
            'Malayalam combinations and joined emoji.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
      if (targetColorNeeded) ...[
        const Text('Active character / destination color'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final color in [Colors.amber, Colors.tealAccent,
            Colors.redAccent, Colors.blueAccent, Colors.white])
            ChoiceChip(
              label: const Text('●'),
              labelStyle: TextStyle(color: color),
              selected: _alternateColor == color,
              tooltip: 'Select ${color.toARGB32().toRadixString(16)}',
              onSelected: (_) => setState(() => _alternateColor = color),
            ),
        ]),
      ],
      const SizedBox(height: 8),
      Text('End hold: ${_endDelay.toStringAsFixed(1)} seconds'),
      Slider(
        value: _endDelay,
        min: 0, max: 1, divisions: 10,
        onChanged: (value) => setState(() {
          _endDelay = value;
          _recomputePreviewDurations();
        }),
      ),
      Text('Each animation frame becomes a timed subtitle line in the SRT file. '
          'Complete characters stay intact. Longer effects create more '
          'subtitle lines.',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Widget _srtFramePreview(String text) {
    final frames = SrtEffectFrames.build(
      effect: _selectedEffect, text: text,
      unit: _movingKaraokeUnit,
      color: _typewriterColor.toARGB32().toRadixString(16).padLeft(8, '0')
          .substring(2),
      alternateColor: _alternateColor.toARGB32().toRadixString(16)
          .padLeft(8, '0').substring(2),
      availableMilliseconds: _animDuration.inMilliseconds,
    );
    if (frames.isEmpty) return const Text('Not enough text or time for this effect');
    final index = (_previewProgress * frames.length).floor()
        .clamp(0, frames.length - 1).toInt();
    final frameText = frames[index];
    final tag = RegExp(r'<font color="#([a-fA-F0-9]{6})">|</font>',
        caseSensitive: false);
    final spans = <InlineSpan>[];
    var current = 0;
    Color? activeColor;
    for (final match in tag.allMatches(frameText)) {
      if (match.start > current) {
        spans.add(TextSpan(text: frameText.substring(current, match.start),
            style: TextStyle(color: activeColor)));
      }
      final rgb = match.group(1);
      activeColor = rgb == null ? null : Color(int.parse('FF$rgb', radix: 16));
      current = match.end;
    }
    if (current < frameText.length) {
      spans.add(TextSpan(text: frameText.substring(current),
          style: TextStyle(color: activeColor)));
    }
    return RichText(text: TextSpan(
      style: Theme.of(context).textTheme.titleMedium,
      children: spans,
    ));
  }

  Widget _buildPreviewCard() {
    final text = _textController.text.isNotEmpty ? _textController.text : (widget.subtitleLines?.first.original ?? 'Sample text for preview');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text('Preview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_formatDuration(_lineDuration), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 12),

          // Animated preview area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03) : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SrtEffectFrames.supported.contains(_selectedEffect)
                ? _srtFramePreview(text)
                : _selectedEffect == 'karaoke'
                    ? _karaokePreview(text) : _typewriterPreview(text),
          ),

          const SizedBox(height: 12),

          // Controls: progress slider and play/pause
          Row(
            children: [
              IconButton(
                icon: Icon(_isPreviewPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  _recomputePreviewDurations();
                  if (_isPreviewPlaying) {
                    _previewController.stop();
                    setState(() => _isPreviewPlaying = false);
                  } else {
                    setState(() => _isPreviewPlaying = true);
                    _previewController.forward(from: 0.0);
                  }
                },
              ),
              Expanded(
                child: Slider(
                  value: _previewProgress.clamp(0.0, 1.0),
                  onChanged: (v) {
                    final pos = v.clamp(0.0, 1.0);
                    setState(() {
                      _previewProgress = pos;
                      _previewController.value = pos;
                      _isPreviewPlaying = false;
                      _previewController.stop();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDuration(_animDuration * _previewProgress), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final ms = d.inMilliseconds;
    final seconds = (ms / 1000).toStringAsFixed(2);
    return '${seconds}s';
  }

  Widget _karaokePreview(String text) {
    // Word endpoints and character endpoints are UTF-16 offsets at complete
    // boundaries. Spaces and newlines remain exactly as authored.
    final endpoints = <int>[];
    if (_karaokeEffectType == 'word') {
      endpoints.addAll(RegExp(r'\S+', unicode: true)
          .allMatches(text).map((match) => match.end));
    } else {
      var offset = 0;
      for (final grapheme in text.characters) {
        offset += grapheme.length;
        endpoints.add(offset);
      }
    }
    final count = (_previewProgress * endpoints.length).floor()
        .clamp(0, endpoints.length).toInt();
    final boundary = count == 0 ? 0 : endpoints[count - 1];
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.titleMedium,
        children: [
          TextSpan(text: text.substring(0, boundary),
              style: TextStyle(color: _karaokeColor)),
          TextSpan(text: text.substring(boundary)),
        ],
      ),
    );
  }

  Widget _typewriterPreview(String text) {
    final clusters = text.characters.toList();
    final revealed = (_previewProgress * clusters.length).floor()
        .clamp(0, clusters.length).toInt();
    final visible = clusters.take(revealed).join();
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
        children: [
          TextSpan(text: visible, style: TextStyle(color: _typewriterColor)),
        ],
      ),
    );
  }

  void _applyEffect() {
    setState(() => _isProcessing = true);

    Map<String, dynamic> effectConfig = {};

    if (_selectedEffect == 'karaoke') {
      // Get text selection info
      final selection = _textController.selection;
      final hasSelection = selection.start != selection.end;
      final selectedText = hasSelection ? selection.textInside(_textController.text) : '';
      
      effectConfig = {
        'color': _karaokeColor.toARGB32().toRadixString(16).padLeft(8, '0'),
        'endDelay': _endDelay,
        'effectType': _karaokeEffectType,
        // Add text selection information
        'hasTextSelection': hasSelection,
        'selectionStart': selection.start,
        'selectionEnd': selection.end,
        'selectedText': selectedText,
        'fullText': _textController.text,
      };
    } else if (_selectedEffect == 'typewriter') {
      effectConfig = {
        'color': _typewriterColor.toARGB32().toRadixString(16).padLeft(8, '0'),
        'endDelay': _endDelay,
      };
    } else if (SrtEffectFrames.supported.contains(_selectedEffect)) {
      effectConfig = {
        'color': _typewriterColor.toARGB32().toRadixString(16).padLeft(8, '0'),
        'alternateColor': _alternateColor.toARGB32()
            .toRadixString(16).padLeft(8, '0'),
        'endDelay': _endDelay,
        if (_selectedEffect == 'movingKaraoke')
          'unit': _movingKaraokeUnit,
      };
    }

    // Call the callback with effect type and configuration
    widget.onApplyEffect(_selectedEffect, effectConfig);

    setState(() => _isProcessing = false);
    // Don't pop here - let the calling method handle navigation
  }
}
