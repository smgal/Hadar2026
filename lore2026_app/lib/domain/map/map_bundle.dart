import 'map_model.dart';
import 'tile_properties.dart';

/// Where a map hands the party on to — the `exit` / `enter` link the
/// Part 3 map files carry in their header.
class MapLink {
  const MapLink({required this.map, required this.x, required this.y});

  /// Target map name (`E3_Ground1`).
  final String map;

  /// 1-based, like every coordinate in the design documents.
  final int x;
  final int y;

  static MapLink? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final map = j['map'];
    if (map is! String) return null;
    return MapLink(map: map, x: j['x'] as int? ?? 0, y: j['y'] as int? ?? 0);
  }
}

/// One `MapInfos.json` entry, as lore2026 extends it.
///
/// The RPG Maker fields (`id`, `name`, …) are the ones hadar2026_app
/// reads; the rest is what the converter knows about the original map and
/// the engine would otherwise have to guess from the name.
class LoreMapInfo {
  const LoreMapInfo({
    required this.id,
    required this.name,
    required this.episode,
    required this.key,
    required this.title,
    required this.type,
    required this.defaultTile,
    this.encounter = false,
    this.start,
    this.exit,
    this.enter,
    this.cm2,
    this.json,
  });

  final int id;

  /// `E3_Lore` — the name scripts pass to `LoadScript`.
  final String name;

  /// 1, 2 or 3.
  final int episode;

  /// The original map key (`Lore`).
  final String key;

  /// Korean display name.
  final String title;

  /// `HDTileProperties.TYPE_*`.
  final int type;

  /// The map's "기본 타일".
  final int defaultTile;

  /// Whether the original map file allows random encounters (Part 3
  /// header). Scripts still decide the table and may switch it off.
  final bool encounter;

  /// Default arrival cell, 1-based (Part 3 header).
  final (int, int)? start;
  final MapLink? exit;
  final MapLink? enter;

  final String? cm2;
  final String? json;

  bool get isGround => type == HDTileProperties.TYPE_GROUND;
  bool get isDen => type == HDTileProperties.TYPE_DEN;
  bool get isTown => type == HDTileProperties.TYPE_TOWN;
  bool get isKeep => type == HDTileProperties.TYPE_KEEP;

  static LoreMapInfo? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final name = j['name'];
    final id = j['id'];
    if (name is! String || id is! int) return null;
    final start = j['start'];
    return LoreMapInfo(
      id: id,
      name: name,
      episode: j['episode'] as int? ?? 0,
      key: j['key'] as String? ?? name,
      title: j['title'] as String? ?? name,
      type: HDTileProperties.typeFromName(j['type'] as String? ?? 'town'),
      defaultTile: j['default'] as int? ?? 0,
      encounter: j['encounter'] as bool? ?? false,
      start: start is List && start.length == 2
          ? (start[0] as int, start[1] as int)
          : null,
      exit: MapLink.fromJson(j['exit']),
      enter: MapLink.fromJson(j['enter']),
      cm2: j['cm2'] as String?,
      json: j['json'] as String?,
    );
  }
}

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

  /// The `MapInfos.json` entry, when the name was found there.
  final LoreMapInfo? info;

  const MapBundle({
    required this.mapName,
    this.json,
    this.cm2Path,
    this.info,
  });
}
