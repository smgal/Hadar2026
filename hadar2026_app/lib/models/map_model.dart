import 'dart:typed_data';

class MapModel {
  int width;
  int height;
  static const int handicapMax = 4;

  // SmSet equivalent (32 bytes = 256 bits)
  Uint8List jumpable = Uint8List(32);
  Uint8List teleportable = Uint8List(32);

  // Dynamic size tile data
  Uint8List data;

  // Visual tile overrides (Tile::CopyTile)
  Map<int, int> tileOverrides = {};

  // Handicap data
  Uint8List handicapData = Uint8List(handicapMax);

  MapModel({this.width = 0, this.height = 0})
    : data = Uint8List(0); // Initialize empty

  // Helper to get tile at x,y
  int getTile(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return 0;
    if (y * width + x >= data.length) return 0; // Safety check
    return data[y * width + x] &
        0x3F; // Mask out the upper 2 bits (lighting flags)
  }

  bool isJumpable(int x, int y) {
    int tile = getTile(x, y);
    return _checkSet(jumpable, tile);
  }

  bool _checkSet(Uint8List set, int index) {
    if (index < 0 || index >= 256) return false;
    // index ~/ 8 is byte index, index % 8 is bit index
    return (set[index ~/ 8] & (1 << (index % 8))) > 0;
  }

  void init(int w, int h) {
    width = w;
    height = h;
    data = Uint8List(w * h);
  }

  void setTile(int x, int y, int tileId) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    data[y * width + x] = tileId;
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'data': data.toList(),
      'jumpable': jumpable.toList(),
      'teleportable': teleportable.toList(),
      'handicapData': handicapData.toList(),
      'tileOverrides': tileOverrides.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  factory MapModel.fromJson(Map<String, dynamic> json) {
    final model = MapModel(
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
    if (json['data'] != null) {
      model.data = Uint8List.fromList(List<int>.from(json['data']));
    }
    if (json['jumpable'] != null) {
      model.jumpable = Uint8List.fromList(List<int>.from(json['jumpable']));
    }
    if (json['teleportable'] != null) {
      model.teleportable = Uint8List.fromList(
        List<int>.from(json['teleportable']),
      );
    }
    if (json['handicapData'] != null) {
      model.handicapData = Uint8List.fromList(
        List<int>.from(json['handicapData']),
      );
    }
    if (json['tileOverrides'] != null) {
      final overrides = Map<String, dynamic>.from(json['tileOverrides']);
      model.tileOverrides = overrides.map(
        (k, v) => MapEntry(int.parse(k), v as int),
      );
    }
    return model;
  }
}
