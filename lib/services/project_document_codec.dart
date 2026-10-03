import 'dart:convert';

Map<String, dynamic> _jsonObject(
  Object? value,
  String errorMessage,
) {
  if (value is! Map) {
    throw FormatException(errorMessage);
  }
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _jsonObjectList(
  Object? value,
  String errorMessage,
) {
  if (value == null) return const <Map<String, dynamic>>[];
  if (value is! List) {
    throw FormatException(errorMessage);
  }

  return value.map((item) {
    if (item is! Map) {
      throw FormatException(errorMessage);
    }
    return Map<String, dynamic>.from(item);
  }).toList(growable: false);
}

class ProjectSessionData {
  final Map<String, dynamic> _json;

  ProjectSessionData._(Map<String, dynamic> json)
      : _json = Map<String, dynamic>.unmodifiable(json);

  factory ProjectSessionData.fromJson(Map<String, dynamic> json) {
    return ProjectSessionData._(json);
  }

  factory ProjectSessionData.create({
    required String fileName,
    required int? lastEditedIndex,
    required bool editMode,
    required String? projectFilePath,
  }) {
    return ProjectSessionData._({
      'fileName': fileName,
      'lastEditedIndex': lastEditedIndex,
      'editMode': editMode,
      'projectFilePath': projectFilePath,
    });
  }

  String? get fileName => _json['fileName'] is String
      ? _json['fileName'] as String
      : null;

  int? get lastEditedIndex =>
      _json['lastEditedIndex'] is int ? _json['lastEditedIndex'] as int : null;

  bool? get editMode =>
      _json['editMode'] is bool ? _json['editMode'] as bool : null;

  String? get projectFilePath => _json['projectFilePath'] is String
      ? _json['projectFilePath'] as String
      : null;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_json);
}

class ProjectSubtitleLineData {
  final Map<String, dynamic> _json;

  ProjectSubtitleLineData._(Map<String, dynamic> json)
      : _json = Map<String, dynamic>.unmodifiable(json);

  factory ProjectSubtitleLineData.fromJson(Map<String, dynamic> json) {
    return ProjectSubtitleLineData._(json);
  }

  factory ProjectSubtitleLineData.create({
    required int index,
    required String startTime,
    required String endTime,
    required String original,
    required String? edited,
    required bool marked,
    required String? comment,
    required bool resolved,
  }) {
    return ProjectSubtitleLineData._({
      'index': index,
      'startTime': startTime,
      'endTime': endTime,
      'original': original,
      'edited': edited,
      'marked': marked,
      'comment': comment,
      'resolved': resolved,
    });
  }

  int? get validIndex =>
      _json['index'] is int ? _json['index'] as int : null;

  int get index => validIndex ?? 0;

  String get startTime =>
      _json['startTime'] is String ? _json['startTime'] as String : '';

  String get endTime =>
      _json['endTime'] is String ? _json['endTime'] as String : '';

  String get original =>
      _json['original'] is String ? _json['original'] as String : '';

  String? get edited =>
      _json['edited'] is String ? _json['edited'] as String : null;

  bool get marked =>
      _json['marked'] is bool ? _json['marked'] as bool : false;

  String? get comment =>
      _json['comment'] is String ? _json['comment'] as String : null;

  bool get resolved =>
      _json['resolved'] is bool ? _json['resolved'] as bool : false;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_json);
}

class ProjectDeltaData {
  final Map<String, dynamic> _json;
  final ProjectSubtitleLineData? beforeState;
  final ProjectSubtitleLineData? afterState;

  ProjectDeltaData._({
    required Map<String, dynamic> json,
    required this.beforeState,
    required this.afterState,
  }) : _json = Map<String, dynamic>.unmodifiable(json);

  factory ProjectDeltaData.fromJson(Map<String, dynamic> json) {
    final before = json['beforeState'];
    final after = json['afterState'];

    return ProjectDeltaData._(
      json: json,
      beforeState: before is Map
          ? ProjectSubtitleLineData.fromJson(
              Map<String, dynamic>.from(before),
            )
          : null,
      afterState: after is Map
          ? ProjectSubtitleLineData.fromJson(
              Map<String, dynamic>.from(after),
            )
          : null,
    );
  }

  factory ProjectDeltaData.create({
    required String changeType,
    required int lineIndex,
    required ProjectSubtitleLineData? beforeState,
    required ProjectSubtitleLineData? afterState,
  }) {
    return ProjectDeltaData._(
      json: {
        'changeType': changeType,
        'lineIndex': lineIndex,
        'beforeState': beforeState?.toJson(),
        'afterState': afterState?.toJson(),
      },
      beforeState: beforeState,
      afterState: afterState,
    );
  }

  String get changeType =>
      _json['changeType'] is String ? _json['changeType'] as String : '';

  int get lineIndex =>
      _json['lineIndex'] is int ? _json['lineIndex'] as int : 0;

  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(_json);
    json['beforeState'] = beforeState?.toJson();
    json['afterState'] = afterState?.toJson();
    return json;
  }
}

class ProjectCheckpointData {
  final Map<String, dynamic> _json;
  final List<ProjectDeltaData> deltas;
  final List<ProjectSubtitleLineData> snapshot;

  ProjectCheckpointData._({
    required Map<String, dynamic> json,
    required this.deltas,
    required this.snapshot,
  }) : _json = Map<String, dynamic>.unmodifiable(json);

  factory ProjectCheckpointData.fromJson(Map<String, dynamic> json) {
    final deltaMaps = _jsonObjectList(
      json['deltas'],
      'Invalid .msone file: checkpoint deltas must be a list of objects.',
    );
    final snapshotMaps = _jsonObjectList(
      json['snapshot'],
      'Invalid .msone file: checkpoint snapshot must be a list of objects.',
    );

    return ProjectCheckpointData._(
      json: json,
      deltas: deltaMaps
          .map(ProjectDeltaData.fromJson)
          .toList(growable: false),
      snapshot: snapshotMaps
          .map(ProjectSubtitleLineData.fromJson)
          .toList(growable: false),
    );
  }

  factory ProjectCheckpointData.create({
    required int id,
    required int sessionId,
    required int subtitleCollectionId,
    required String timestamp,
    required String operationType,
    required String description,
    required int? parentCheckpointId,
    required bool isActive,
    required String checkpointType,
    required String? metadata,
    required List<ProjectDeltaData> deltas,
    required List<ProjectSubtitleLineData> snapshot,
  }) {
    return ProjectCheckpointData._(
      json: {
        'id': id,
        'sessionId': sessionId,
        'subtitleCollectionId': subtitleCollectionId,
        'timestamp': timestamp,
        'operationType': operationType,
        'description': description,
        'parentCheckpointId': parentCheckpointId,
        'isActive': isActive,
        'checkpointType': checkpointType,
        'metadata': metadata,
      },
      deltas: List<ProjectDeltaData>.unmodifiable(deltas),
      snapshot: List<ProjectSubtitleLineData>.unmodifiable(snapshot),
    );
  }

  int? get id => _json['id'] is int ? _json['id'] as int : null;

  int? get sessionId =>
      _json['sessionId'] is int ? _json['sessionId'] as int : null;

  int? get subtitleCollectionId => _json['subtitleCollectionId'] is int
      ? _json['subtitleCollectionId'] as int
      : null;

  String? get timestamp =>
      _json['timestamp'] is String ? _json['timestamp'] as String : null;

  String get operationType => _json['operationType'] is String
      ? _json['operationType'] as String
      : 'unknown';

  String get description =>
      _json['description'] is String ? _json['description'] as String : '';

  int? get parentCheckpointId => _json['parentCheckpointId'] is int
      ? _json['parentCheckpointId'] as int
      : null;

  bool get isActive =>
      _json['isActive'] is bool ? _json['isActive'] as bool : false;

  String get checkpointType => _json['checkpointType'] is String
      ? _json['checkpointType'] as String
      : 'delta';

  String? get metadata =>
      _json['metadata'] is String ? _json['metadata'] as String : null;

  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(_json);
    json['deltas'] = deltas.map((delta) => delta.toJson()).toList();
    json['snapshot'] = snapshot.map((line) => line.toJson()).toList();
    return json;
  }
}

class ProjectSubtitleCollectionData {
  final Map<String, dynamic> _json;
  final List<ProjectSubtitleLineData> lines;

  ProjectSubtitleCollectionData._({
    required Map<String, dynamic> json,
    required this.lines,
  }) : _json = Map<String, dynamic>.unmodifiable(json);

  factory ProjectSubtitleCollectionData.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawLines = json['lines'];
    if (rawLines is! List) {
      throw const FormatException(
        'Invalid .msone file: subtitle lines must be a list.',
      );
    }

    final lineMaps = _jsonObjectList(
      rawLines,
      'Invalid .msone file: subtitle lines must be a list of objects.',
    );

    return ProjectSubtitleCollectionData._(
      json: json,
      lines: lineMaps
          .map(ProjectSubtitleLineData.fromJson)
          .toList(growable: false),
    );
  }

  factory ProjectSubtitleCollectionData.create({
    required String fileName,
    required String? filePath,
    required String? originalFileUri,
    required String encoding,
    required List<ProjectSubtitleLineData> lines,
  }) {
    return ProjectSubtitleCollectionData._(
      json: {
        'fileName': fileName,
        'filePath': filePath,
        'originalFileUri': originalFileUri,
        'encoding': encoding,
      },
      lines: List<ProjectSubtitleLineData>.unmodifiable(lines),
    );
  }

  String? get fileName =>
      _json['fileName'] is String ? _json['fileName'] as String : null;

  String? get filePath =>
      _json['filePath'] is String ? _json['filePath'] as String : null;

  String? get originalFileUri => _json['originalFileUri'] is String
      ? _json['originalFileUri'] as String
      : null;

  String get encoding =>
      _json['encoding'] is String ? _json['encoding'] as String : 'UTF-8';

  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(_json);
    json['lines'] = lines.map((line) => line.toJson()).toList();
    return json;
  }
}

class ProjectMetadataData {
  final Map<String, dynamic> _json;

  ProjectMetadataData._(Map<String, dynamic> json)
      : _json = Map<String, dynamic>.unmodifiable(json);

  factory ProjectMetadataData.fromJson(Map<String, dynamic> json) {
    return ProjectMetadataData._(json);
  }

  factory ProjectMetadataData.create({
    required int totalLines,
    required int editedLines,
    required int markedLines,
    required String lastSaved,
  }) {
    return ProjectMetadataData._({
      'totalLines': totalLines,
      'editedLines': editedLines,
      'markedLines': markedLines,
      'lastSaved': lastSaved,
    });
  }

  int get totalLines =>
      _json['totalLines'] is int ? _json['totalLines'] as int : 0;

  int get editedLines =>
      _json['editedLines'] is int ? _json['editedLines'] as int : 0;

  int get markedLines =>
      _json['markedLines'] is int ? _json['markedLines'] as int : 0;

  String? get lastSaved =>
      _json['lastSaved'] is String ? _json['lastSaved'] as String : null;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_json);
}

/// Validated typed representation of one SubtitleStudio project document.
///
/// The legacy map conversion remains only as a temporary compatibility bridge
/// for import surfaces that have not yet migrated to typed project DTOs.
class ProjectDocument {
  final String version;
  final ProjectSessionData session;
  final ProjectSubtitleCollectionData subtitleCollection;
  final List<ProjectCheckpointData> checkpoints;
  final ProjectMetadataData metadata;
  final String? createdAt;
  final String? exportedAt;
  final String? appVersion;
  final Map<String, dynamic> _extra;

  ProjectDocument._({
    required this.version,
    required this.session,
    required this.subtitleCollection,
    required this.checkpoints,
    required this.metadata,
    required this.createdAt,
    required this.exportedAt,
    required this.appVersion,
    required Map<String, dynamic> extra,
  }) : _extra = Map<String, dynamic>.unmodifiable(extra);

  factory ProjectDocument.create({
    required String version,
    required ProjectSessionData session,
    required ProjectSubtitleCollectionData subtitleCollection,
    required List<ProjectCheckpointData> checkpoints,
    required ProjectMetadataData metadata,
    String? createdAt,
    String? exportedAt,
    String? appVersion,
  }) {
    return ProjectDocument._(
      version: version,
      session: session,
      subtitleCollection: subtitleCollection,
      checkpoints: List<ProjectCheckpointData>.unmodifiable(checkpoints),
      metadata: metadata,
      createdAt: createdAt,
      exportedAt: exportedAt,
      appVersion: appVersion,
      extra: const <String, dynamic>{},
    );
  }

  int get totalLines => subtitleCollection.lines.length;

  String? get originalFileUri {
    final value = subtitleCollection.originalFileUri;
    return value != null && value.isNotEmpty ? value : null;
  }

  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.from(_extra);
    json['version'] = version;
    if (createdAt != null) json['createdAt'] = createdAt;
    if (exportedAt != null) json['exportedAt'] = exportedAt;
    if (appVersion != null) json['appVersion'] = appVersion;
    json['session'] = session.toJson();
    json['subtitleCollection'] = subtitleCollection.toJson();
    json['checkpoints'] =
        checkpoints.map((checkpoint) => checkpoint.toJson()).toList();
    json['metadata'] = metadata.toJson();
    return json;
  }

}

class ProjectDocumentCodec {
  const ProjectDocumentCodec._();

  static ProjectDocument decode(String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (error) {
      throw FormatException(
        'Invalid .msone JSON: ' + error.message,
      );
    }

    if (decoded is! Map) {
      throw const FormatException(
        'Invalid .msone file: root must be an object.',
      );
    }

    final raw = Map<String, dynamic>.from(decoded);

    final versionValue = raw['version'];
    if (versionValue is! String || versionValue.trim().isEmpty) {
      throw const FormatException(
        'Invalid .msone file: missing project version.',
      );
    }

    final sessionMap = _jsonObject(
      raw['session'],
      'Invalid .msone file: missing session data.',
    );
    final collectionMap = _jsonObject(
      raw['subtitleCollection'],
      'Invalid .msone file: missing subtitle collection.',
    );

    final checkpointMaps = _jsonObjectList(
      raw['checkpoints'],
      'Invalid .msone file: checkpoints must be a list of objects.',
    );

    final metadataValue = raw['metadata'];
    if (metadataValue != null && metadataValue is! Map) {
      throw const FormatException(
        'Invalid .msone file: metadata must be an object.',
      );
    }

    final extra = Map<String, dynamic>.from(raw)
      ..remove('version')
      ..remove('createdAt')
      ..remove('exportedAt')
      ..remove('appVersion')
      ..remove('session')
      ..remove('subtitleCollection')
      ..remove('checkpoints')
      ..remove('metadata');

    return ProjectDocument._(
      version: versionValue,
      session: ProjectSessionData.fromJson(sessionMap),
      subtitleCollection:
          ProjectSubtitleCollectionData.fromJson(collectionMap),
      checkpoints: checkpointMaps
          .map(ProjectCheckpointData.fromJson)
          .toList(growable: false),
      metadata: metadataValue is Map
          ? ProjectMetadataData.fromJson(
              Map<String, dynamic>.from(metadataValue),
            )
          : ProjectMetadataData.fromJson(const <String, dynamic>{}),
      createdAt: raw['createdAt'] is String
          ? raw['createdAt'] as String
          : null,
      exportedAt: raw['exportedAt'] is String
          ? raw['exportedAt'] as String
          : null,
      appVersion: raw['appVersion'] is String
          ? raw['appVersion'] as String
          : null,
      extra: extra,
    );
  }

  static String encode(ProjectDocument document) {
    return jsonEncode(document.toJson());
  }
}
