import 'map_model.dart';

/// A loaded map's full bundle. A map can be defined as:
///
/// - cm2 only (dynamic events, no static JSON);
/// - JSON only (legacy, static events only — discouraged for new maps);
/// - both (cm2 takes precedence per (action, x, y) tile, JSON is fallback).
///
/// [mapName] is the canonical lookup key — same string used by
/// `HDNativeScriptRunner.mapScriptFactory` and by `MapInfos.json#name`.
class MapBundle {
  final String mapName;
  final MapModel? json;
  final String? cm2Path;

  const MapBundle({required this.mapName, this.json, this.cm2Path});
}
