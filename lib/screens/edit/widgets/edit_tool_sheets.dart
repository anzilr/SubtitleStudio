import 'package:flutter/material.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/widgets/banner_configuration_sheet.dart';
import 'package:subtitle_studio/widgets/malayalam_normalization_sheet.dart';
import 'package:subtitle_studio/widgets/settings_sheet.dart';
import 'package:subtitle_studio/widgets/subtitle_sync_sheet.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';

Future<void> showEditorSyncSheet({
  required BuildContext context,
  required List<SubtitleLine> subtitleLines,
  required int subtitleCollectionId,
  required bool isVideoLoaded,
  required GlobalKey<VideoPlayerWidgetState> videoPlayerKey,
  required Future<void> Function() onRefresh,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.7,
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: SubtitleSyncSheet(
          subtitleLines: subtitleLines,
          subtitleId: subtitleCollectionId,
          isVideoLoaded: isVideoLoaded,
          videoPlayerKey: videoPlayerKey,
          onRefresh: () async {
            await onRefresh();
            if (sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
          },
        ),
      );
    },
  );
}

Future<void> showEditorBannerSheet({
  required BuildContext context,
  required int subtitleCollectionId,
  required int sessionId,
  required List<SubtitleLine> subtitleLines,
  required Future<void> Function() onBannersInserted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => BannerConfigurationSheet(
      subtitleCollectionId: subtitleCollectionId,
      sessionId: sessionId,
      subtitleLines: subtitleLines,
      onBannersInserted: onBannersInserted,
    ),
  );
}

Future<void> showEditorNormalizationSheet({
  required BuildContext context,
  required int subtitleCollectionId,
  required List<SubtitleLine> subtitleLines,
  required Future<void> Function() onNormalizationComplete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => MalayalamNormalizationSheet(
      subtitleCollectionId: subtitleCollectionId,
      subtitleLines: subtitleLines,
      onNormalizationComplete: onNormalizationComplete,
    ),
  );
}

Future<void> showEditorSettingsSheet({
  required BuildContext context,
  required Future<void> Function() onSettingsChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SettingsSheet(
      onSettingsChanged: onSettingsChanged,
    ),
  );
}
