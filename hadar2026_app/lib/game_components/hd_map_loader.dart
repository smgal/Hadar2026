import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/map_model.dart';

class HDMapLoader {
  Future<MapModel> loadMap(String assetPath) async {
    final map = MapModel();
    String jsonString = "";

    try {
      if (!kIsWeb && await File(assetPath).exists()) {
        jsonString = await File(assetPath).readAsString();
      } else {
        jsonString = await rootBundle.loadString(assetPath);
      }
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

    for (int y = 0; y < map.height; y++) {
      for (int x = 0; x < map.width; x++) {
        int index = y * map.width + x;
        // Layers
        // 0: tile
        // 1: ?
        // 2: obj0
        // 3: obj1
        // 4: shadow
        // 5: event region

        map.data[index].ixTile = _getLayerData(rawData, 0, index, size);
        map.data[index].ixObj0 = _getLayerData(rawData, 2, index, size);
        map.data[index].ixObj1 = _getLayerData(rawData, 3, index, size);
        map.data[index].shadow = _getLayerData(rawData, 4, index, size);
        map.data[index].ixEvent = _getLayerData(rawData, 5, index, size);
      }
    }

    // Parse events
    final List<dynamic> rawEvents = jsonData['events'] ?? [];
    for (var ev in rawEvents) {
      if (ev != null) {
        final parsedEvent = MapEvent.fromJson(ev);
        map.events.add(parsedEvent);

        final unit = map.getUnit(parsedEvent.x, parsedEvent.y);
        if (unit != null) {
          int eventType = 0;
          if (parsedEvent.type == "EVENT")
            eventType = 0x00010000;
          else if (parsedEvent.type == "TALK")
            eventType = 0x00020000;
          else if (parsedEvent.type == "SIGN")
            eventType = 0x00030000;
          else if (parsedEvent.type == "ENTER")
            eventType = 0x00040000;

          unit.ixEvent = eventType | parsedEvent.id;
          print(
            "MapLoader -> Event at (${parsedEvent.x}, ${parsedEvent.y}) type: ${parsedEvent.type}, id: ${parsedEvent.id}, lines: ${parsedEvent.dialogLines.length}",
          );
        }
      }
    }

    print(
      "Loaded map: ${map.width}x${map.height}, total ${map.data.length} tiles.",
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
