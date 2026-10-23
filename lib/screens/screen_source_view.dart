// Source View compatibility facade.
//
// The implementation is Riverpod-based and lives in source_view_screen_host.dart.
// Keeping this public class avoids changing every navigation call site at once.
export 'package:subtitle_studio/screens/source_view/source_view_screen_host.dart'
    show SourceViewScreenHost;

import 'package:subtitle_studio/screens/source_view/source_view_screen_host.dart';

class SourceViewScreen extends SourceViewScreenHost {
  const SourceViewScreen({
    super.key,
    required super.filePath,
    super.displayName,
    super.safUri,
    super.fileContent,
  });
}
