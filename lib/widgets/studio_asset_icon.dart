import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared, theme-aware SVGs for toolbar, menu and sheet icons.
/// Original artwork is retained unchanged in assets/.
abstract final class StudioAssetIcons {
  static const olam = 'assets/olam_dictionary_icon.svg';
  static const urban = 'assets/urban_dictionary_icon.svg';
  static const projectSettings = 'assets/project_settings.svg';
  static const amplitudeIncrease = 'assets/vertical_amplitude_zoom_in.svg';
  static const amplitudeDecrease = 'assets/vertical_amplitude_zoom_out.svg';
  static const showWaveform = 'assets/show_waveform.svg';
  static const hideWaveform = 'assets/hide_waveform.svg';
  static const showVideo = 'assets/show_video.svg';
  static const hideVideo = 'assets/hide_video.svg';
  static const resumeSubtitleFlow = 'assets/resume_subtitle_flow.svg';
  static const pauseSubtitleFlow = 'assets/pause_subtitle_flow.svg';
  static const markedLinesSheet = 'assets/marked_lines_sheet.svg';
}

class StudioAssetIcon extends StatelessWidget {
  const StudioAssetIcon(this.asset, {super.key, this.size = 24, this.color});

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    colorFilter: ColorFilter.mode(
      color ?? Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}
