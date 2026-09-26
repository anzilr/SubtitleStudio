import 'package:get/get.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Observable subtitle list used by the legacy Editor rendering path.
///
/// This controller is kept behavior-compatible while the Editor is migrated
/// away from mixed state management. Keeping it outside screen_edit.dart makes
/// the remaining GetX dependency explicit and easier to remove later.
class SubtitleController extends GetxController {
  final subtitleLines = <SubtitleLine>[].obs;

  void updateSubtitleLine(int index, SubtitleLine newLine) {
    subtitleLines[index] = newLine;
  }

  void setSubtitleLines(List<SubtitleLine> lines) {
    subtitleLines.value = lines;
  }
}
