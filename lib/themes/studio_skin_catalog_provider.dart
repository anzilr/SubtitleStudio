import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'studio_skin_catalog.dart';

/// Injectable catalog boundary for built-in and future locally installed skins.
///
/// The default catalog contains the three bundled families. SKIN-EXT-2 can
/// replace it with a provider that watches validated app-owned skin files,
/// without changing the Appearance UI or the shared Material theme factory.
final studioSkinCatalogProvider = Provider<StudioSkinCatalog>(
  (ref) => StudioSkinCatalog(),
);
