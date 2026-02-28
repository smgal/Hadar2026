import 'dart:io';
import 'package:flutter/services.dart';
import '../models/map_model.dart';

class HDMapLoader {
  Future<MapModel> loadMap(String assetPath) async {
    final map = MapModel();
    ByteData byteData;

    try {
      if (await File(assetPath).exists()) {
        final bytes = await File(assetPath).readAsBytes();
        byteData = ByteData.view(bytes.buffer);
      } else {
        final bytes = await rootBundle.load(assetPath);
        byteData = bytes;
      }
    } catch (e) {
      throw Exception("File not found or unreadable: $assetPath");
    }

    int offset = 0;

    // Read Header: Width (1 byte), Height (1 byte)
    if (byteData.lengthInBytes < 2) {
      throw Exception("File too short");
    }

    map.width = byteData.getUint8(offset++);
    map.height = byteData.getUint8(offset++);

    // Initialize data array
    int size = map.width * map.height;
    map.data = Uint8List(size);

    print(
      "MapLoader: Dimensions ${map.width}x${map.height}, attempting to read $size bytes. Available: ${byteData.lengthInBytes - offset}",
    );

    // Read Data
    for (int i = 0; i < size; i++) {
      if (offset < byteData.lengthInBytes) {
        map.data[i] = byteData.getUint8(offset++);
      } else {
        map.data[i] = 0;
      }
    }

    // Debug print
    print(
      "Loaded map: ${map.width}x${map.height}, total ${map.data.length} tiles.",
    );

    return map;
  }
}
