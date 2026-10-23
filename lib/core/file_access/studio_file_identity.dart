import 'package:flutter/foundation.dart';

/// Classified, opaque identity of a source file. This is a *locator*, not an
/// access grant: a content URI still needs the current Android permission and
/// a macOS bookmark must be resolved by the platform before constructing it.
///
/// The raw location stays byte-for-byte identical to legacy persistence and
/// waveform cache keys. UI names and revision metadata must not be used as an
/// alternative document identity.
enum StudioFileLocationKind {
  nativePath,
  androidDocument,
  fileUri,
  remoteUri,
  opaqueUri,
}

@immutable
final class StudioFileIdentity {
  const StudioFileIdentity._(this.location, this.kind);

  /// Keep the original location for read/write/cache boundaries; never log it.
  final String location;
  final StudioFileLocationKind kind;

  static StudioFileIdentity fromLocator(String location) {
    if (location.trim().isEmpty) {
      throw const FormatException('File location must not be empty.');
    }
    // Drive letters (including C:relative) are not URI schemes.
    if (RegExp(r'^[a-zA-Z]:').hasMatch(location)) {
      return StudioFileIdentity._(
        location, StudioFileLocationKind.nativePath);
    }

    final uri = Uri.tryParse(location);
    if (uri == null) {
      throw const FormatException('Malformed file locator.');
    }

    switch (uri.scheme.toLowerCase()) {
      case 'content':
        if (!uri.hasAuthority || uri.host.isEmpty || uri.path.isEmpty) {
          throw const FormatException('Malformed Android document locator.');
        }
        return StudioFileIdentity._(
            location, StudioFileLocationKind.androidDocument);
      case 'file':
        if (uri.path.isEmpty) {
          throw const FormatException('Malformed local file URI.');
        }
        return StudioFileIdentity._(
            location, StudioFileLocationKind.fileUri);
      case '':
        return StudioFileIdentity._(
            location, StudioFileLocationKind.nativePath);
      case 'http':
      case 'https':
      case 'rtsp':
      case 'rtmp':
        return StudioFileIdentity._(
            location, StudioFileLocationKind.remoteUri);
      default:
        // Forward-compatible: native decoders may understand other protocols.
        // Never turn an unknown scheme into a local filesystem stat.
        return StudioFileIdentity._(
            location, StudioFileLocationKind.opaqueUri);
    }
  }

  bool get isAndroidDocument =>
      kind == StudioFileLocationKind.androidDocument;

  bool get canStatLocally => kind == StudioFileLocationKind.nativePath;

  /// Matching the persisted locator avoids breaking existing user projects.
  String get persistedLocator => location;

  @override
  bool operator ==(Object other) =>
      other is StudioFileIdentity &&
      other.kind == kind && other.location == location;

  @override
  int get hashCode => Object.hash(location, kind);

  /// Never expose document IDs, names, tokens, home paths or credentials.
  @override
  String toString() => 'StudioFileIdentity(${kind.name})';
}
