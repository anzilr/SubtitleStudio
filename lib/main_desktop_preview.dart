import 'package:flutter/material.dart';
import 'package:subtitle_studio/desktop/workspace/desktop_workspace_preview.dart';

/// Independently launchable desktop *layout preview*.
/// Intentionally bypasses production Isar and media startup while CP88–CP93
/// finish; this entrypoint cannot modify real subtitle or project files.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DesktopWorkspacePreviewApp());
}

class DesktopWorkspacePreviewApp extends StatelessWidget {
  const DesktopWorkspacePreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2A9D8F);
    return MaterialApp(
      title: 'SubtitleStudio • Desktop workspace preview',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101215),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF171A1E),
        ),
        visualDensity: VisualDensity.compact,
      ),
      debugShowCheckedModeBanner: false,
      home: const DesktopWorkspacePreview(),
    );
  }
}
