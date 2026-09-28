import 'dart:convert';

/// Validated representation of one SubtitleStudio project document.
///
/// This is intentionally a compatibility boundary: existing import persistence
/// still consumes the legacy map shape, while new code can use typed accessors.
/// The codec performs structural validation without changing project-version
/// compatibility policy.
class ProjectDocument {
  final String version;
  final Map<String, dynamic> session;
  final Map<String, dynamic> subtitleCollection;
  final List<dynamic> checkpoints;
  final Map<String, dynamic> metadata;
  final String? createdAt;
  final String? exportedAt;
  final String? appVersion;
  final Map<String, dynamic> _raw;

  const ProjectDocument._({
    required this.version,
    required this.session,
    required this.subtitleCollection,
    required this.checkpoints,
    required this.metadata,
    required this.createdAt,
    required this.exportedAt,
    required this.appVersion,
    required Map<String, dynamic> raw,
  }) : _raw = raw;

  int get totalLines {
    final lines = subtitleCollection['lines'];
    return lines is List ? lines.length : 0;
  }

  String? get originalFileUri {
    final value = subtitleCollection['originalFileUri'];
    return value is String && value.isNotEmpty ? value : null;
  }

  Map<String, dynamic> toLegacyMap() => Map<String, dynamic>.from(_raw);
}

class ProjectDocumentCodec {
  const ProjectDocumentCodec._();

  static ProjectDocument decode(String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (e) {
      throw FormatException('Invalid .msone JSON: ${e.message}');
    }

    if (decoded is! Map) {
      throw const FormatException('Invalid .msone file: root must be an object.');
    }

    final raw = Map<String, dynamic>.from(decoded);

    final versionValue = raw['version'];
    if (versionValue is! String || versionValue.trim().isEmpty) {
      throw const FormatException(
        'Invalid .msone file: missing project version.',
      );
    }

    final sessionValue = raw['session'];
    if (sessionValue is! Map) {
      throw const FormatException(
        'Invalid .msone file: missing session data.',
      );
    }

    final collectionValue = raw['subtitleCollection'];
    if (collectionValue is! Map) {
      throw const FormatException(
        'Invalid .msone file: missing subtitle collection.',
      );
    }

    final session = Map<String, dynamic>.from(sessionValue);
    final subtitleCollection = Map<String, dynamic>.from(collectionValue);

    final lines = subtitleCollection['lines'];
    if (lines is! List) {
      throw const FormatException(
        'Invalid .msone file: subtitle lines must be a list.',
      );
    }

    final checkpointsValue = raw['checkpoints'];
    if (checkpointsValue != null && checkpointsValue is! List) {
      throw const FormatException(
        'Invalid .msone file: checkpoints must be a list.',
      );
    }

    final metadataValue = raw['metadata'];
    if (metadataValue != null && metadataValue is! Map) {
      throw const FormatException(
        'Invalid .msone file: metadata must be an object.',
      );
    }

    return ProjectDocument._(
      version: versionValue,
      session: session,
      subtitleCollection: subtitleCollection,
      checkpoints: checkpointsValue is List
          ? List<dynamic>.from(checkpointsValue)
          : const <dynamic>[],
      metadata: metadataValue is Map
          ? Map<String, dynamic>.from(metadataValue)
          : const <String, dynamic>{},
      createdAt: raw['createdAt'] is String ? raw['createdAt'] as String : null,
      exportedAt:
          raw['exportedAt'] is String ? raw['exportedAt'] as String : null,
      appVersion:
          raw['appVersion'] is String ? raw['appVersion'] as String : null,
      raw: raw,
    );
  }

  static String encode(Map<String, dynamic> document) => jsonEncode(document);
}
