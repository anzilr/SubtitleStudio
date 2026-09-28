import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';

final subtitleRepositoryProvider = Provider<SubtitleRepository>((ref) {
  return SubtitleRepository(ref.watch(isarProvider));
});
