import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/map/map_bundle.dart';
import '../domain/map/map_model.dart';
import '../domain/map/tile_table.dart';
import '../application/map_loader.dart';
import 'ports/host_binding.dart';

/// Resolves a map name into its data, script and metadata.
///
/// `name` → entry in `assets/maps/MapInfos.json` → `MapNNN.json` + the
/// paired cm2 + what the converter recorded about the original map
/// ([LoreMapInfo]). Don't bypass the index: the three games reuse map
/// keys (`Lore`, `Menace`, `LastDitch`), and only the index tells
/// `E1_Menace` from `E3_Menace`.
class HDMapNavigation {
  static final HDMapNavigation _instance = HDMapNavigation._internal();
  factory HDMapNavigation() => _instance;
  HDMapNavigation._internal();

  final HDMapLoader _loader = HDMapLoader();

  String? errorMessage;

  Map<String, LoreMapInfo>? _infos;
  TileTable? _tileTable;

  /// Drops the cached index and tile table. Tests bind a different asset
  /// source per case; the desktop build re-reads after a map-editor save.
  void invalidate() {
    _infos = null;
    _tileTable = null;
  }

  /// Every `MapInfos.json` entry by name. Read once.
  Future<Map<String, LoreMapInfo>> infos() async {
    final cached = _infos;
    if (cached != null) return cached;
    final out = <String, LoreMapInfo>{};
    try {
      final text = await HDHosts().assets.loadString(
        'assets/maps/MapInfos.json',
      );
      for (final raw in jsonDecode(text) as List) {
        final info = LoreMapInfo.fromJson(raw);
        if (info != null) out[info.name] = info;
      }
    } catch (e) {
      debugPrint("Could not load MapInfos.json: $e");
    }
    return _infos = out;
  }

  Future<LoreMapInfo?> info(String name) async =>
      (await infos())[name.replaceAll('.json', '')];

  /// `assets/maps/tiletable.json`. Read once; empty if missing, in which
  /// case `Map::ChangeTile` degrades to a solid cell rather than throwing.
  Future<TileTable> tileTable() async {
    final cached = _tileTable;
    if (cached != null) return cached;
    try {
      final text = await HDHosts().assets.loadString(
        'assets/maps/tiletable.json',
      );
      return _tileTable = TileTable.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint("Could not load tiletable.json: $e");
      return _tileTable = TileTable.empty;
    }
  }

  Future<MapBundle?> loadByName(String fileName) async {
    try {
      errorMessage = null;
      final searchName = fileName.replaceAll('.json', '');
      final found = (await infos())[searchName];

      String jsonName = '$searchName.json'; // Fallback
      String? cm2Path;
      if (found != null) {
        final idStr = found.id.toString().padLeft(3, '0');
        jsonName = found.json ?? 'Map$idStr.json';
        cm2Path = found.cm2 ?? 'Map$idStr.cm2';
      }

      final jsonAssetPath = 'assets/maps/$jsonName';
      MapModel? json;
      try {
        json = await _loader.loadMap(jsonAssetPath);
      } catch (e) {
        if (cm2Path == null) {
          errorMessage = "Failed to load map: $e";
          return null;
        }
        debugPrint("HDMapNavigation: cm2-only map $searchName (no JSON: $e)");
      }

      return MapBundle(
        mapName: searchName,
        json: json,
        cm2Path: cm2Path,
        info: found,
      );
    } catch (e) {
      debugPrint("Failed to load map: $e");
      errorMessage = "Failed to load map: $e";
      return null;
    }
  }
}
