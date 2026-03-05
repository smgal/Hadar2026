import 'dart:typed_data';

class MapEvent {
  final int id;
  final String name;
  final String note;
  final int x;
  final int y;
  List<String> dialogLines = [];

  // parsed type
  final String type; // e.g., "TALK", "ENTER", "EVENT"

  MapEvent({
    required this.id,
    required this.name,
    required this.note,
    required this.x,
    required this.y,
    List<String>? dialogLines,
  }) : type = _parseTypeString(name) {
    if (dialogLines != null) {
      this.dialogLines = dialogLines;
    }
  }

  static String _parseTypeString(String name) {
    if (name.startsWith("TALK")) return "TALK";
    if (name.startsWith("ENTER")) return "ENTER";
    if (name.startsWith("EVENT") || name.startsWith("EVT")) return "EVENT";
    if (name.startsWith("NPC")) return "NPC";
    if (name.startsWith("SIGN")) return "SIGN";
    return "UNKNOWN";
  }

  factory MapEvent.fromJson(Map<String, dynamic> json) {
    final ev = MapEvent(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      note: json['note'] ?? '',
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
    );

    if (json['pages'] != null && (json['pages'] as List).isNotEmpty) {
      var page = json['pages'][0];
      if (page['list'] != null) {
        for (var item in page['list']) {
          if (item['code'] == 401 && item['parameters'] != null) {
            for (var param in item['parameters']) {
              if (param is String) {
                ev.dialogLines.add(param);
              }
            }
          }
        }
      }
    }

    return ev;
  }
}

class MapUnit {
  int ixTile;
  int ixObj0;
  int ixObj1;
  int shadow;
  int ixEvent;

  MapUnit({
    this.ixTile = 0,
    this.ixObj0 = 0,
    this.ixObj1 = 0,
    this.shadow = 0,
    this.ixEvent = 0,
  });

  factory MapUnit.fromJson(Map<String, dynamic> json) {
    return MapUnit(
      ixTile: json['ixTile'] ?? 0,
      ixObj0: json['ixObj0'] ?? 0,
      ixObj1: json['ixObj1'] ?? 0,
      shadow: json['shadow'] ?? 0,
      ixEvent: json['ixEvent'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ixTile': ixTile,
      'ixObj0': ixObj0,
      'ixObj1': ixObj1,
      'shadow': shadow,
      'ixEvent': ixEvent,
    };
  }
}

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
