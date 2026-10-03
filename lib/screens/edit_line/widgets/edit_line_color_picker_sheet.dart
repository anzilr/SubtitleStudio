import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/colour_picker_widget.dart';

Future<bool?> showEditLineColorPickerSheet({
  required BuildContext context,
  required TextEditingController controller,
  required List<Color> colorHistory,
  required VoidCallback onApply,
}) {
  final colorPickerKey = GlobalKey<ColorPickerWithTextEditingState>();

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Scaffold(
        backgroundColor: Theme.of(sheetContext).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Text Color Editor',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.of(sheetContext).pop(false),
            icon: const Icon(Icons.close),
          ),
          elevation: 1,
        ),
        body: Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 80,
          ),
          child: ColorPickerWithTextEditing(
            key: colorPickerKey,
            controller: controller,
            initialSelection: controller.selection,
            initialColor: Colors.white,
            colorHistory: colorHistory,
            showApplyButton: false,
          ),
        ),
        floatingActionButton: Container(
          width: MediaQuery.of(sheetContext).size.width - 32,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: FloatingActionButton.extended(
            onPressed: () {
              colorPickerKey.currentState?.applyChanges();
              onApply();
              Navigator.of(sheetContext).pop(true);
            },
            backgroundColor: const Color(0xFF4A90E2),
            foregroundColor: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            label: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, size: 24),
                SizedBox(width: 12),
                Text(
                  'Apply Color',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
      );
    },
  );
}
