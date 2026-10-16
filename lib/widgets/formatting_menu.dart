import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/colour_picker_widget.dart';
import 'package:subtitle_studio/utils/text_formatting.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';

class FormattingMenu extends StatelessWidget {
  final TextEditingController controller;
  final List<Color> colorHistory;
  final VoidCallback? onColorHistoryUpdate;

  const FormattingMenu({
    super.key, 
    required this.controller,
    required this.colorHistory,
    this.onColorHistoryUpdate,
  });

  void _showColorPicker(BuildContext context) {
    final colorPickerKey = GlobalKey<ColorPickerWithTextEditingState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: StudioDesignTokens.of(context).surface,
          appBar: AppBar(
            title: const Text(
              'Text Color Editor',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
            elevation: 1,
          ),
          body: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80, // Space for floating button
            ),
            child: ColorPickerWithTextEditing(
              key: colorPickerKey,
              controller: controller,
              initialSelection: controller.selection,
              initialColor: Colors.white,
              colorHistory: colorHistory,
              showApplyButton: false, // Hide the apply button from the widget
            ),
          ),
          floatingActionButton: Container(
            width: MediaQuery.of(context).size.width - 32,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: FloatingActionButton.extended(
              onPressed: () {
                // Apply the color changes
                colorPickerKey.currentState?.applyChanges();
                if (onColorHistoryUpdate != null) {
                  onColorHistoryUpdate!();
                }
                Navigator.of(context).pop(true);
              },
              backgroundColor: StudioDesignTokens.of(context).primaryAction,
              foregroundColor: StudioDesignTokens.of(context).onPrimaryAction,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StudioRadius.input),
              ),
              label: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, size: 24),
                  SizedBox(width: 12),
                  Text(
                    "Apply Color",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  void _showClearFormattingDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        final tokens = StudioDesignTokens.of(context);
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(StudioRadius.sheet),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section with cleaning icon and title
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.caution.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(StudioRadius.input),
                        ),
                        child: Icon(
                          Icons.cleaning_services_rounded,
                          color: tokens.caution,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clear All Formatting',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This action cannot be undone',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: tokens.caution,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Warning message in a card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.caution.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(StudioRadius.input),
                    border: Border.all(
                      color: tokens.caution.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: tokens.caution,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Warning',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: tokens.caution,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you sure you want to remove all formatting tags from the text? This will permanently remove all HTML tags, color codes, and styling elements.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: tokens.mutedText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(StudioRadius.input),
                              side: BorderSide(
                                color: tokens.fieldBorder,
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
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
                            controller.text = controller.text
                              .replaceAll(RegExp(r'(<[^>]+>|\{[^}]+\})'), '');
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(StudioRadius.input),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cleaning_services_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Clear All',
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
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.format_size, 
        size: 32,
        color: StudioDesignTokens.of(context).primaryAction,
      ),
      offset: const Offset(0, 8),
      onSelected: (String value) {
        if (value == "color") {
          _showColorPicker(context);
        } else if (value == "clear") {
          _showClearFormattingDialog(context);
        } else {
          toggleTextFormatting(controller: controller, tag: value);
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: "b",
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.format_bold,
                  color: StudioDesignTokens.of(context).primaryAction,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  "Bold",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: "i",
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.format_italic,
                  color: StudioDesignTokens.of(context).primaryAction,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  "Italic",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: "u",
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.format_underline,
                  color: StudioDesignTokens.of(context).primaryAction,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  "Underline",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: "s",
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.format_strikethrough,
                  color: StudioDesignTokens.of(context).primaryAction,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  "Strikethrough",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: "color",
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.palette,
                  color: StudioDesignTokens.of(context).primaryAction,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  "Text Color",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem(
          value: "clear",
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.cleaning_services,
                  color: StudioDesignTokens.of(context).primaryAction,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  "Clear Formatting",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
