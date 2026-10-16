import 'dart:convert';

import 'package:subtitle_studio/database/models/models.dart';

/// Versioned metadata for checkpoint history semantics.
///
/// Version 1 is the legacy SubtitleStudio model where an operation checkpoint
/// represents the state BEFORE that operation.
///
/// Version 2 uses Git-style commit semantics: a checkpoint represents the state
/// AFTER its operation. Snapshot checkpoints therefore contain the exact state
/// represented by that commit.
class CheckpointHistoryMetadata {
  static const int currentVersion = 2;
  static const String _versionKey = '_historyVersion';
  static const String _semanticsKey = '_stateSemantics';
  static const String postOperationSemantics = 'after-operation';
  static const String _stateHashKey = '_stateHash';
  static const String _parentStateHashKey = '_parentStateHash';

  const CheckpointHistoryMetadata._();

  static bool isPostOperation(Checkpoint checkpoint) {
    final decoded = decode(checkpoint.metadata);
    return decoded[_versionKey] == currentVersion &&
        decoded[_semanticsKey] == postOperationSemantics;
  }

  static String? stateHash(Checkpoint checkpoint) {
    final value = decode(checkpoint.metadata)[_stateHashKey];
    return value is String && value.isNotEmpty ? value : null;
  }

  static String? parentStateHash(Checkpoint checkpoint) {
    final value = decode(checkpoint.metadata)[_parentStateHashKey];
    return value is String && value.isNotEmpty ? value : null;
  }

  static Map<String, dynamic> decode(String? metadata) {
    if (metadata == null || metadata.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final value = jsonDecode(metadata);
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    } catch (_) {
      // Legacy operation metadata was not guaranteed to be valid JSON.
    }
    return const <String, dynamic>{};
  }

  static String encodePostOperation({
    Map<String, dynamic>? operationMetadata,
    String? stateHash,
    String? parentStateHash,
  }) {
    return jsonEncode({
      ...?operationMetadata,
      _versionKey: currentVersion,
      _semanticsKey: postOperationSemantics,
      if (stateHash != null) _stateHashKey: stateHash,
      if (parentStateHash != null) _parentStateHashKey: parentStateHash,
    });
  }
}
