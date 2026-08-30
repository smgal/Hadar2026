import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../application/ports/asset_source.dart';

/// [AssetSource] backed by the Flutter asset bundle, with an on-disk
/// override on non-web platforms.
///
/// The override is what lets desktop runs pick up edits to
/// `assets/maps/*.json` and `assets/*.cm2` — including the ones
/// `tools/mapEditor` writes in place — without a rebuild. Web has no
/// filesystem, so it reads the bundle directly.
class HDBundleAssetSource implements AssetSource {
  static final HDBundleAssetSource _instance =
      HDBundleAssetSource._internal();
  factory HDBundleAssetSource() => _instance;
  HDBundleAssetSource._internal();

  @override
  Future<String> loadString(String path) async {
    if (!kIsWeb && await File(path).exists()) {
      return File(path).readAsString();
    }
    return rootBundle.loadString(path);
  }
}
