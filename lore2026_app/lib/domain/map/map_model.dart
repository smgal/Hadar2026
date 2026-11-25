import 'map_event.dart';
import 'map_unit.dart';

export 'map_event.dart';
export 'map_unit.dart';

class MapModel {
  int width;
  int height;

  List<MapEvent> events = [];
  List<MapUnit> data = [];

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

  /// 세이브에 싣는 꼴.
  ///
  /// **층마다 따로, 같은 값이 이어지면 묶어서** 적는다(`[값, 개수, …]`).
  /// 칸마다 `{ixTile: …}` 을 적던 방식은 코볼트성(150×120)에서 1MB 를
  /// 넘겼고, 웹의 저장소는 칸 넷을 합쳐 5MB 가 한도다.
  Map<String, dynamic> toJson() {
    List<int> pack(int Function(MapUnit u) pick) {
      final out = <int>[];
      for (final u in data) {
        final v = pick(u);
        if (out.isNotEmpty && out[out.length - 2] == v) {
          out[out.length - 1]++;
        } else {
          out
            ..add(v)
            ..add(1);
        }
      }
      return out;
    }

    return {
      'width': width,
      'height': height,
      'layers': {
        'tile': pack((u) => u.ixTile),
        'decor': pack((u) => u.ixDecor),
        'obj0': pack((u) => u.ixObj0),
        'obj1': pack((u) => u.ixObj1),
        'shadow': pack((u) => u.shadow),
        'event': pack((u) => u.ixEvent),
      },
      'tileOverrides': tileOverrides.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  factory MapModel.fromJson(Map<String, dynamic> json) {
    final model = MapModel();
    model.init(json['width'] ?? 0, json['height'] ?? 0);

    void unpack(Object? packed, void Function(MapUnit u, int v) put) {
      if (packed is! List) return;
      var at = 0;
      for (var i = 0; i + 1 < packed.length; i += 2) {
        final v = packed[i] as int;
        final n = packed[i + 1] as int;
        for (var k = 0; k < n && at < model.data.length; k++) {
          put(model.data[at++], v);
        }
      }
    }

    final layers = json['layers'];
    if (layers is Map) {
      unpack(layers['tile'], (u, v) => u.ixTile = v);
      unpack(layers['decor'], (u, v) => u.ixDecor = v);
      unpack(layers['obj0'], (u, v) => u.ixObj0 = v);
      unpack(layers['obj1'], (u, v) => u.ixObj1 = v);
      unpack(layers['shadow'], (u, v) => u.shadow = v);
      unpack(layers['event'], (u, v) => u.ixEvent = v);
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
