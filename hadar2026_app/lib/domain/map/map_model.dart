import 'dart:typed_data';

import 'map_event.dart';
import 'map_unit.dart';

export 'map_event.dart';
export 'map_unit.dart';

class MapModel {
  int width;
  int height;

  List<MapEvent> events = [];
  List<MapUnit> data = [];

  // Used for backwards compatibility with parts of the code expecting handicappedData
  static const int handicapMax = 4;
  Uint8List handicapData = Uint8List(handicapMax);

  // Visual tile overrides (Tile::CopyTile)
  Map<int, int> tileOverrides = {};

  MapModel({this.width = 0, this.height = 0});

  MapUnit? getUnit(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return null;
    int index = y * width + x;
    if (index >= data.length) return null;
    return data[index];
  }

  int getTile(int x, int y) {
    final unit = getUnit(x, y);
    return unit?.ixTile ?? 0;
  }

  void setTile(int x, int y, int tileId) {
    final unit = getUnit(x, y);
    if (unit != null) {
      unit.ixTile = tileId;
    }
  }

  void init(int w, int h) {
    width = w;
    height = h;
    data = List.generate(w * h, (_) => MapUnit());
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'data': data.map((u) => u.toJson()).toList(),
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
      final list = json['data'] as List;
      model.data = list.map((e) => MapUnit.fromJson(e)).toList();
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
