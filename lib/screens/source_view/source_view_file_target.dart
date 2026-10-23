import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';

/// Source View's storage decision, independent of platform channel calls.
///
/// A document URI is a locator requiring a current SAF grant, not a local
/// filesystem path. A separate local cache path may be a fallback only when
/// that original path is genuinely a native filesystem location.
final class SourceViewFileTarget {
  const SourceViewFileTarget._({
    required this.source,
    required this.androidDocumentUri,
  });

  final StudioFileIdentity source;
  final String? androidDocumentUri;

  /// A local file URI is also a native source after explicit URI decoding
  /// at the I/O boundary. A content/remote URI never becomes a fallback.
  bool get canFallbackToLocalFile =>
      source.kind == StudioFileLocationKind.nativePath ||
      source.kind == StudioFileLocationKind.fileUri;

  static SourceViewFileTarget resolve({
    required String filePath,
    String? safUri,
  }) {
    final source = StudioFileIdentity.fromLocator(filePath);
    final grant = safUri?.trim();
    if (grant != null && grant.isNotEmpty) {
      final granted = StudioFileIdentity.fromLocator(safUri!);
      if (!granted.isAndroidDocument) {
        throw const FormatException(
          'Source View SAF access must use an Android document URI.',
        );
      }
      // When filePath itself is a document, do not allow a stale or
      // unrelated saved grant to redirect a write to a different document.
      // A separate native cached file may still have its own SAF URI.
      if (source.isAndroidDocument && source.location != safUri) {
        throw const FormatException(
          'Source View document and SAF grant identity do not match.',
        );
      }
    }
    // The provided SAF locator takes precedence over the source locator,
    // preserving the existing native-cache-file + SAF grant flow.
    return SourceViewFileTarget._(
      source: source,
      androidDocumentUri: grant != null && grant.isNotEmpty
          ? safUri
          : source.isAndroidDocument ? source.location : null,
    );
  }
}
