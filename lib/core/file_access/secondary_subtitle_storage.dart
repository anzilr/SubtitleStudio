import 'dart:io';

/// Persist embedded subtitle tracks outside disposable OS cache. Do not
/// delete arbitrary user-picked files just because their filename matches.
abstract final class SecondarySubtitleStorage {
  static bool isLegacyEphemeralExtraction(String path) {
    final normalized = path.replaceAll('\\', '/');
    // Only an Android private app directory is an app-owned legacy source.
    return RegExp(
      r'^/data/(?:user/[0-9]+|data)/[a-zA-Z0-9_.]+/(?:code_cache|cache)/extracted_subtitle_',
    ).hasMatch(normalized);
  }

  static bool isOwnedExtraction(
    String path, {
    Directory? supportDirectory,
  }) {
    if (isLegacyEphemeralExtraction(path)) return true;
    if (supportDirectory == null) return false;
    final normalized = path.replaceAll('\\', '/');
    final root = supportDirectory.path.replaceAll('\\', '/');
    return normalized.startsWith(
      '$root/secondary_subtitles/extracted_subtitle_',
    );
  }

  static Future<String> persist({
    required Directory supportDirectory,
    required int collectionId,
    required String content,
    required String extension,
  }) async {
    if (collectionId <= 0) throw ArgumentError.value(collectionId);
    final type = extension.toLowerCase();
    if (!const {'srt', 'vtt', 'ass', 'ssa'}.contains(type)) {
      throw ArgumentError.value(extension, 'extension', 'Unsupported subtitle format');
    }
    final dir = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}secondary_subtitles');
    await dir.create(recursive: true);
    final name =
        'extracted_subtitle_${collectionId}_${DateTime.now().microsecondsSinceEpoch}.$type';
    final target = File('${dir.path}${Platform.pathSeparator}$name');
    final pending = File('${target.path}.writing');
    try {
      await pending.writeAsString(content, flush: true);
      await pending.rename(target.path);
      return target.path;
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  static Future<void> deleteOwnedFileIfPresent(
    String? path, {
    Directory? supportDirectory,
  }) async {
    if (path == null ||
        !isOwnedExtraction(path, supportDirectory: supportDirectory)) {
      return;
    }
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
