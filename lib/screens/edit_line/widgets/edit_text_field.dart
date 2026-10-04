import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/custom_text_render.dart';

class CharacterCountWidget extends StatelessWidget {
  final int count;
  final bool hasLongLine;

  const CharacterCountWidget({
    super.key,
    required this.count,
    required this.hasLongLine,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count chars',
      style: TextStyle(
        fontSize: 11,
        color: hasLongLine
            ? Colors.red
            : Colors.white.withValues(alpha: 0.5),
        fontWeight: hasLongLine ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class OptimizedTextField extends StatefulWidget {
  final TextEditingController controller;
  final UndoHistoryController undoController;
  final bool readOnly;
  final String title;
  final Widget characterCountWidget;
  final String indexText;
  final bool isRawEnabled;
  final bool showEditButton;
  final bool showPasteButton;
  final bool isEditingEnabled;

  const OptimizedTextField({
    super.key,
    required this.controller,
    required this.undoController,
    required this.readOnly,
    required this.title,
    required this.characterCountWidget,
    required this.indexText,
    required this.isRawEnabled,
    required this.showEditButton,
    required this.showPasteButton,
    required this.isEditingEnabled,
  });

  @override
  State<OptimizedTextField> createState() => _OptimizedTextFieldState();
}

class _OptimizedTextFieldState extends State<OptimizedTextField> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 100,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            border: Border.all(
              color: const Color(0xFF0A9396),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.isRawEnabled
              ? CustomHtmlText(
                  htmlContent:
                      widget.controller.text.replaceAll('\n', '<br>'),
                  textAlign: TextAlign.center,
                  defaultStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                )
              : TextField(
                  controller: widget.controller,
                  undoController: widget.undoController,
                  keyboardType: TextInputType.multiline,
                  readOnly: widget.readOnly,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(8, 8, 30, 8),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFFFFFFF),
                  ),
                  scrollPhysics: const BouncingScrollPhysics(),
                  autocorrect: false,
                  enableSuggestions: true,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  textInputAction: TextInputAction.newline,
                  enableIMEPersonalizedLearning: true,
                  enableInteractiveSelection: true,
                  showCursor: true,
                ),
        ),
        Positioned(
          bottom: 1,
          right: 4,
          child: widget.characterCountWidget,
        ),
        Positioned(
          top: 1,
          left: 4,
          child: Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(100, 255, 255, 255),
              fontSize: 12,
            ),
          ),
        ),
        Positioned(
          bottom: 1,
          left: 4,
          child: Text(
            widget.indexText,
            style: const TextStyle(
              color: Color.fromARGB(125, 255, 255, 255),
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ),
        Positioned(
          top: 1,
          right: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                padding: EdgeInsets.zero,
                onPressed: () {},
                icon: const Icon(Icons.copy, size: 16),
                color: const Color(0xFFCA6702),
              ),
              if (widget.showEditButton)
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                  icon: const Icon(Icons.edit, size: 16),
                  color: widget.isEditingEnabled
                      ? const Color(0xFFBB3E03)
                      : const Color(0xFFCA6702),
                  tooltip: 'Toggle Edit Mode',
                ),
              if (widget.showPasteButton)
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                  icon: const Icon(Icons.paste, size: 16),
                  color: const Color(0xFFCA6702),
                  tooltip: 'Paste Original',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
