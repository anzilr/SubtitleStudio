import 'package:flutter/material.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';

class BottomModalSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onAddLine;
  final VoidCallback onDelete;
  final VoidCallback onSelect;
  final VoidCallback onCopy;
  final VoidCallback onMark;
  final VoidCallback? onEffects;
  final VoidCallback? onShowInMarkedLines; // New callback for "Show in Marked Lines"
  final bool isMarked;

  const BottomModalSheet({
    super.key,
    required this.onEdit,
    required this.onAddLine,
    required this.onDelete,
    required this.onSelect,
    required this.onCopy,
    required this.onMark,
    required this.isMarked,
    this.onEffects,
    this.onShowInMarkedLines,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: StudioDesignTokens.of(context).surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            // bottom: 16.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            // Action Cards
            _buildActionCard(
              context: context,
              icon: Icons.edit,
              title: "Edit",
              description: "Modify subtitle text and timing",
              themeColor: StudioDesignTokens.of(context).primaryAction,
              onTap: onEdit,
            ),
            const SizedBox(height: 8),
            
            _buildActionCard(
              context: context,
              icon: Icons.add,
              title: "Add Line",
              description: "Insert a new subtitle after this one",
              themeColor: StudioDesignTokens.of(context).primaryAction,
              onTap: onAddLine,
            ),
            const SizedBox(height: 8),
            
            _buildActionCard(
              context: context,
              icon: Icons.select_all,
              title: "Select",
              description: "Add to current selection",
              themeColor: StudioDesignTokens.of(context).primaryAction,
              onTap: onSelect,
            ),
            const SizedBox(height: 8),
            
            _buildActionCard(
              context: context,
              icon: Icons.copy,
              title: "Copy",
              description: "Copy subtitle to clipboard",
              themeColor: StudioDesignTokens.of(context).primaryAction,
              onTap: onCopy,
            ),
            const SizedBox(height: 8),
            
            _buildActionCard(
              context: context,
              icon: isMarked ? Icons.bookmark_remove : Icons.bookmark_add,
              title: isMarked ? "Unmark" : "Mark Line",
              description: isMarked ? "Remove bookmark from this line" : "Bookmark this line for easy access",
              themeColor: isMarked
                  ? StudioDesignTokens.of(context).mutedText
                  : StudioDesignTokens.of(context).primaryAction,
              onTap: onMark,
            ),
            const SizedBox(height: 8),
            
            // Show "Show in Marked Lines" option only if line is marked
            if (isMarked && onShowInMarkedLines != null)
              _buildActionCard(
                context: context,
                icon: Icons.bookmark_border,
                title: "Show in Marked Lines",
                description: "Open marked lines sheet and highlight this line",
                themeColor: StudioDesignTokens.of(context).primaryAction,
                onTap: onShowInMarkedLines!,
              ),
            if (isMarked && onShowInMarkedLines != null) const SizedBox(height: 8),
            
            if (onEffects != null)
              _buildActionCard(
                context: context,
                icon: Icons.auto_awesome,
                title: "Add Effects (Beta)",
                description: "Apply typewriter or karaoke effects",
                themeColor: StudioDesignTokens.of(context).primaryAction,
                onTap: onEffects!,
              ),
            if (onEffects != null) const SizedBox(height: 8),
            
            _buildActionCard(
              context: context,
              icon: Icons.delete,
              title: "Delete",
              description: "Remove this subtitle permanently",
              themeColor: StudioDesignTokens.of(context).dangerText,
              onTap: onDelete,
            ),
            
            const SizedBox(height: 12),
          ],
        ),
      ),
        )
    ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    final tokens = StudioDesignTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudioRadius.card),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: tokens.fieldSurface,
                  borderRadius: BorderRadius.circular(StudioRadius.input),
                ),
                child: Icon(
                  icon,
                  color: themeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.mutedText,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
