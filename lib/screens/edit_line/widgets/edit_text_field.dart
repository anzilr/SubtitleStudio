import 'package:flutter/material.dart';
import 'package:subtitle_studio/widgets/custom_text_render.dart';
import 'package:subtitle_studio/themes/studio_cue_field.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';

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
    final tokens = StudioDesignTokens.of(context);
    return Text(
      '$count chars',
      style: TextStyle(
        fontSize: 11,
        color: hasLongLine ? tokens.dangerText : tokens.mutedText,
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
        StudioCueFieldSurface(
          child: widget.isRawEnabled
              ? CustomHtmlText(
                  htmlContent:
                      widget.controller.text.replaceAll('\n', '<br>'),
                  textAlign: TextAlign.center,
                  defaultStyle: StudioCueFieldStyle.text(context),
                )
              : TextField(
                  controller: widget.controller,
                  undoController: widget.undoController,
                  keyboardType: TextInputType.multiline,
                  readOnly: widget.readOnly,
                  maxLines: null,
                  expands: true,
                  decoration: StudioCueFieldStyle.decoration(padding: const EdgeInsets.fromLTRB(8, 8, 30, 8)),
                  style: StudioCueFieldStyle.text(context),
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
            style: StudioCueFieldStyle.label(context),
          ),
        ),
        Positioned(
          bottom: 1,
          left: 4,
          child: Text(
            widget.indexText,
            style: StudioCueFieldStyle.index(context),
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
                color: StudioDesignTokens.of(context).primaryAction,
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
                  color: StudioDesignTokens.of(context).primaryAction,
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
                  color: StudioDesignTokens.of(context).primaryAction,
                  tooltip: 'Paste Original',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
