import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/map/map_model.dart';
import 'ports/host_binding.dart';

class HDMapLoader {
  Future<MapModel> loadMap(String assetPath) async {
    final map = MapModel();
    String jsonString = "";

    try {
      jsonString = await HDHosts().assets.loadString(assetPath);
    } catch (e) {
      throw Exception("File not found or unreadable: $assetPath ($e)");
    }

    final Map<String, dynamic> jsonData = jsonDecode(jsonString);

    map.width = jsonData['width'] ?? 0;
    map.height = jsonData['height'] ?? 0;

    // Parse the data array
    final List<dynamic> rawData = jsonData['data'] ?? [];

    int size = map.width * map.height;
    map.init(map.width, map.height);

    for (int index = 0; index < size; index++) {
      // Layers (five-layer layout, BP-36 R-36-57)
      // 0: tile    L1 ground
      // 1: decor   L2 floor decor (walked over)
      // 2: obj0    L3 object (blocks)
      // 3: obj1    L4 top object (blocks, checked first)
      // 4: shadow  L5 light/shadow
      // 5: region  what the cell does, when the tile bands cannot say
      final unit = map.data[index];
      unit.ixTile = _getLayerData(rawData, 0, index, size);
      unit.ixDecor = _getLayerData(rawData, 1, index, size);
      unit.ixObj0 = _getLayerData(rawData, 2, index, size);
      unit.ixObj1 = _getLayerData(rawData, 3, index, size);
      unit.shadow = _getLayerData(rawData, 4, index, size);

      // **The region is an action override, not a free-form id.** The
      // converter writes 1~9 (event · talk · sign · enter · block · walk ·
      // water · swamp · lava) wherever the original tile meant something
      // its picture's band does not. It lands in the same bits an
      // `events[]` entry uses, so `HDTileProperties.getUnitAction` has one
      // place to look.
      final region = _getLayerData(rawData, 5, index, size);
      unit.ixEvent = (region >= 1 && region <= 9) ? region << 16 : 0;
    }

    // Parse events. The converted Lore maps carry none — every person and
    // sign is a region-marked cell handled by the map's cm2 — but a map
    // edited in tools/mapEditor may add some, and they keep working.
    final List<dynamic> rawEvents = jsonData['events'] ?? [];
    for (var ev in rawEvents) {
      if (ev != null) {
        final parsedEvent = MapEvent.fromJson(ev);
        map.events.add(parsedEvent);

        final unit = map.getUnit(parsedEvent.x, parsedEvent.y);
        if (unit != null) {
          int eventType = 0;
          if (parsedEvent.type == "EVENT") {
            eventType = 0x00010000;
          } else if (parsedEvent.type == "TALK") {
            eventType = 0x00020000;
          } else if (parsedEvent.type == "SIGN") {
            eventType = 0x00030000;
          } else if (parsedEvent.type == "ENTER") {
            eventType = 0x00040000;
          }
          if (eventType != 0) unit.ixEvent = eventType | parsedEvent.id;
        }
      }
    }

    debugPrint(
      "Loaded map $assetPath: ${map.width}x${map.height}, "
      "${map.events.length} events.",
    );

    return map;
  }

  int _getLayerData(List<dynamic> rawData, int layer, int index, int size) {
    int dataIndex = layer * size + index;
    if (dataIndex < rawData.length) {
      int d = rawData[dataIndex] as int;
      if (layer == 0) {
        // Base tile subtraction
        d = (d < 0x600) ? d : d - 0x600;
      }
      return d;
    }
    return 0;
  }
}
