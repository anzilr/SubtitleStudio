import 'dart:typed_data';
import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';

/// A picker selection with a trusted locator and a presentation-only path.
/// SAF's converted display path must never be used with dart:io File(...).
final class StudioPickedFileReference {
  const StudioPickedFileReference._(
      this.identity, this.displayPath, this.isFromSaf);

  final StudioFileIdentity identity;
  final String displayPath;
  final bool isFromSaf;

  String get accessLocator => identity.persistedLocator;

  factory StudioPickedFileReference.fromPicker({
    required String accessLocator,
    required String displayPath,
    required bool isFromSaf,
  }) {
    final identity = StudioFileIdentity.fromLocator(accessLocator);
    if (displayPath.trim().isEmpty ||
        (isFromSaf && !identity.isAndroidDocument) ||
        (!isFromSaf &&
            identity.kind != StudioFileLocationKind.nativePath &&
            identity.kind != StudioFileLocationKind.fileUri)) {
      throw const FormatException('Invalid picker file reference.');
    }
    return StudioPickedFileReference._(identity, displayPath, isFromSaf);
  }

  /// Legacy callers retain displayPath/safUri/bytes; new callers must use
  /// accessLocator to load/persist the actual source identity.
  Map<String, dynamic> toLegacyPickerInfo(Uint8List bytes) => {
    'displayPath': displayPath,
    'safUri': isFromSaf ? accessLocator : null,
    'accessLocator': accessLocator,
    'bytes': bytes,
  };

  @override
  String toString() => 'StudioPickedFileReference(' +
      identity.kind.name + ', fromSaf: ' + isFromSaf.toString() + ')';
}
