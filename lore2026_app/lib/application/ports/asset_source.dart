/// Boundary for "read a text asset by path".
///
/// The three application-layer readers (map JSON, the map index, cm2
/// script files) used to reach for `rootBundle` directly, which is what
/// kept `package:flutter/services.dart` — and therefore an initialised
/// Flutter binding — in the application layer. They now ask this port,
/// so a headless test or a CLI frontend can serve assets from disk, a
/// fixture map, or an in-memory string.
///
/// Paths are asset-relative and bundle-style (`assets/maps/TOWN1.json`),
/// matching the keys in `pubspec.yaml#flutter/assets`.
abstract class AssetSource {
  /// Reads [path] as a UTF-8 string.
  ///
  /// Throws if the asset cannot be read — callers that treat a missing
  /// asset as a normal outcome (a cm2-only map with no JSON, a map with
  /// no paired cm2) catch and carry on.
  Future<String> loadString(String path);
}
