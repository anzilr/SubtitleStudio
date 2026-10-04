import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/home/models/session_summary.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final SessionSummary summary;
  final bool isLastEdited;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SessionCard({
    super.key,
    required this.session,
    required this.summary,
    required this.isLastEdited,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Card(
        elevation: isLastEdited ? 6 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isLastEdited
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                const SizedBox(height: 8),
                Flexible(child: _buildInfo(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: summary.isMsoneSubtitle
              ? SvgPicture.asset(
                  'assets/msone.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Colors.blue,
                    BlendMode.srcIn,
                  ),
                )
              : Icon(
                  Icons.subtitles,
                  color: colorScheme.secondary.withValues(alpha: 0.9),
                  size: 18,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.fileName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLastEdited) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ],
                  if (session.projectFilePath?.isNotEmpty == true) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Has project file',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.folder_special,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: colorScheme.error,
                      size: 18,
                    ),
                    iconSize: 18,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: const EdgeInsets.all(12),
                    tooltip: 'Delete Session',
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    session.editMode ? Icons.edit : Icons.translate,
                    size: 14,
                    color: colorScheme.secondary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    session.editMode ? 'Edit Mode' : 'Translation Mode',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context) {
    final totalLines = summary.totalLines;
    final editedLines = summary.editedLines;
    final progress = totalLines > 0 ? editedLines / totalLines : 0.0;
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = colorScheme.secondary.withValues(alpha: 0.95);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!session.editMode) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: iconColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icon: Icons.format_list_numbered,
                  label: 'Lines',
                  value: '${summary.totalLines}',
                ),
              ),
              const _InfoDivider(),
              Expanded(
                child: _InfoItem(
                  icon: Icons.edit_note,
                  label: 'Edited',
                  value: '${summary.editedLines}',
                ),
              ),
              const _InfoDivider(),
              Expanded(
                child: _InfoItem(
                  icon: Icons.my_location,
                  label: 'Last Line',
                  value: '${summary.lastEditedIndex}',
                ),
              ),
              const _InfoDivider(),
              Expanded(
                child: _InfoItem(
                  icon: Icons.language,
                  label: 'Languages',
                  value: summary.languageCodes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final iconSize = (availableWidth * 0.15).clamp(12.0, 18.0);
        final valueFontSize = (availableWidth * 0.12).clamp(10.0, 14.0);
        final labelFontSize = (availableWidth * 0.09).clamp(8.0, 11.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.95),
            ),
            SizedBox(height: (availableWidth * 0.02).clamp(2.0, 4.0)),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: valueFontSize,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                      fontSize: labelFontSize,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dividerHeight =
            (constraints.maxHeight * 0.6).clamp(20.0, 35.0);
        return Container(
          height: dividerHeight,
          width: 1,
          color:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 4),
        );
      },
    );
  }
}
