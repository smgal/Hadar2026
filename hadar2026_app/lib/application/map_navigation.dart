import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/map/map_bundle.dart';
import '../domain/map/map_model.dart';
import '../application/map_loader.dart';

/// Resolves a logical map name (e.g. "TOWN1") to a [MapBundle] —
/// the (cm2, json) pair indexed by `assets/maps/MapInfos.json`.
///
/// MapInfos.json entries may carry optional `cm2` and `json` fields
/// pointing at script/data files. When `json` is omitted, falls back
/// to `Map${id:03d}.json`. When `cm2` is omitted, the map runs without
/// a paired dynamic script (must be a native-script map then).
class HDMapNavigation {
  static final HDMapNavigation _instance = HDMapNavigation._internal();
  factory HDMapNavigation() => _instance;
  HDMapNavigation._internal();

  final HDMapLoader _loader = HDMapLoader();

  /// Last load error message; populated when `loadByName` returns null.
  String? errorMessage;

  Future<MapBundle?> loadByName(String fileName) async {
    try {
      errorMessage = null;
      final searchName = fileName.replaceAll('.json', '');
      String resolvedJsonName = '$searchName.json'; // Fallback
      String? overrideJsonName;
      String? cm2Path;

      try {
        final mapInfosStr = await rootBundle.loadString(
          'assets/maps/MapInfos.json',
        );
        final List<dynamic> mapInfos = jsonDecode(mapInfosStr);
        for (var info in mapInfos) {
          if (info != null && info['name'] == searchName) {
            final int id = info['id'];
            resolvedJsonName = 'Map${id.toString().padLeft(3, '0')}.json';
            if (info['json'] is String) overrideJsonName = info['json'];
            if (info['cm2'] is String) cm2Path = info['cm2'];
            break;
          }
        }
      } catch (e) {
        print("Could not load MapInfos.json for resolution: $e");
      }

      final jsonName = overrideJsonName ?? resolvedJsonName;
      final jsonAssetPath = 'assets/maps/$jsonName';

      MapModel? json;
      try {
        json = await _loader.loadMap(jsonAssetPath);
      } catch (e) {
        // JSON-less is allowed only if a cm2 script is paired. Otherwise
        // there's no map at all.
        if (cm2Path == null) {
          errorMessage = "Failed to load map: $e";
          return null;
        }
        print("HDMapNavigation: cm2-only map $searchName (no JSON: $e)");
      }

      return MapBundle(
        mapName: searchName,
        json: json,
        cm2Path: cm2Path,
      );
    } catch (e) {
      print("Failed to load map: $e");
      errorMessage = "Failed to load map: $e";
      return null;
    }
  }
}
