import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Canonical SHA-256 fingerprint for persisted subtitle state.
///
/// Only fields persisted by SubtitleLine are included. The line order is part
/// of the hash because checkpoint restore must reproduce exact history order.
class CheckpointStateHasher {
  const CheckpointStateHasher._();

  static String hashLines(Iterable<SubtitleLine> lines) {
    final canonical = lines.map((line) {
      return <String, dynamic>{
        'index': line.index,
        'startTime': line.startTime,
        'endTime': line.endTime,
        'original': line.original,
        'edited': line.edited,
        'marked': line.marked,
        'comment': line.comment,
        'resolved': line.resolved,
      };
    }).toList(growable: false);

    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }
}
