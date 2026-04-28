import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/map/map_model.dart';
import '../application/map_loader.dart';

/// Resolves a logical map name (e.g. "TOWN1") to its `MapNNN.json` path via
/// the `assets/maps/MapInfos.json` index, then loads the [MapModel].
class HDMapNavigation {
  static final HDMapNavigation _instance = HDMapNavigation._internal();
  factory HDMapNavigation() => _instance;
  HDMapNavigation._internal();

  final HDMapLoader _loader = HDMapLoader();

  /// Loads a map by [fileName] (which may be the bare name like "TOWN1" or
  /// "TOWN1.json"). Returns the loaded [MapModel] on success, or `null` on
  /// failure with [errorMessage] populated.
  String? errorMessage;

  Future<MapModel?> loadByName(String fileName) async {
    try {
      errorMessage = null;
      final searchName = fileName.replaceAll('.json', '');
      String resolvedFileName = '$searchName.json'; // Fallback

      try {
        final mapInfosStr = await rootBundle.loadString(
          'assets/maps/MapInfos.json',
        );
        final List<dynamic> mapInfos = jsonDecode(mapInfosStr);
        for (var info in mapInfos) {
          if (info != null && info['name'] == searchName) {
            final int id = info['id'];
            resolvedFileName = 'Map${id.toString().padLeft(3, '0')}.json';
            break;
          }
        }
      } catch (e) {
        print("Could not load MapInfos.json for resolution: $e");
      }

      final mapPath = 'assets/maps/$resolvedFileName';
      return await _loader.loadMap(mapPath);
    } catch (e) {
      print("Failed to load map: $e");
      errorMessage = "Failed to load map: $e";
      return null;
    }
  }
}
