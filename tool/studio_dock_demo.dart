import 'package:flutter/material.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';

/// Development-only demo: no project database or native media is opened.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Standalone demo initializes native hotkeys; widget tests do not.
  await MSoneHotkeyManager.initialize();
  runApp(const StudioDockDemoApp());
}

class StudioDockDemoApp extends StatelessWidget {
  const StudioDockDemoApp({super.key});

  static const sampleCues = <StudioDockCue>[
    StudioDockCue(id: 1, start: '00:00:08,200', end: '00:00:11,400',
      original: 'The city always looks different at night.',
      edited: 'The city always looks different at night.'),
    StudioDockCue(id: 2, start: '00:00:12,100', end: '00:00:15,800',
      original: 'Especially when there is nowhere to go.',
      edited: 'Especially when there is nowhere to go.'),
    StudioDockCue(id: 3, start: '00:00:17,300', end: '00:00:20,500',
      original: 'I thought we had more time.',
      edited: 'I thought we had more time.'),
    StudioDockCue(id: 4, start: '00:00:21,800', end: '00:00:24,700',
      original: 'The last train left an hour ago.',
      edited: 'The last train left an hour ago.'),
    StudioDockCue(id: 5, start: '00:00:26,100', end: '00:00:29,300',
      original: 'Meet me where the lights end.',
      edited: 'Meet me where the lights end.', marked: true),
    StudioDockCue(id: 6, start: '00:00:30,000', end: '00:00:33,900',
      original: 'Every road leads somewhere.',
      edited: 'Every road leads somewhere.'),
    StudioDockCue(id: 7, start: '00:00:35,500', end: '00:00:38,600',
      original: 'Not every story has an ending.',
      edited: 'Not every story has an ending.'),
    StudioDockCue(id: 8, start: '00:00:40,200', end: '00:00:43,700',
      original: 'We could begin again.',
      edited: 'We could begin again.'),
    StudioDockCue(id: 9, start: '00:00:44,900', end: '00:00:48,000',
      original: 'Are you coming with me?',
      edited: 'Are you coming with me?'),
    StudioDockCue(id: 10, start: '00:00:50,500', end: '00:00:53,600',
      original: 'Only if we take the long way.',
      edited: 'Only if we take the long way.'),
    StudioDockCue(id: 11, start: '00:00:56,900', end: '00:01:00,000',
      original: 'It is almost midnight.',
      edited: 'It is almost midnight.'),
    StudioDockCue(id: 12, start: '00:01:01,200', end: '00:01:04,700',
      original: 'Then let us not waste another minute.',
      edited: 'Then let us not waste another minute.'),
  ];

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2A9D8F);
    return MaterialApp(
      title: 'SubtitleStudio • Studio Dock demo',
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
      home: const StudioDockWorkspace(
        initialCues: sampleCues,
        initialSelectedCueId: 5,
      ),
    );
  }
}
