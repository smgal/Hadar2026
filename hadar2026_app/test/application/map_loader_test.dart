import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/map_loader.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/domain/map/map_model.dart';

class _FakeAssets implements AssetSource {
  _FakeAssets(this.files);

  final Map<String, String> files;

  @override
  Future<String> loadString(String path) async {
    final content = files[path];
    if (content == null) throw Exception('asset not found: $path');
    return content;
  }
}

class _UnusedUiHost implements UiHost {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('UiHost is not used by these tests');
}

class _UnusedMovementHost implements PartyMovementHost {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('PartyMovementHost is not used by these tests');
}

void main() {
  tearDown(HDHosts().reset);

  // Five-layer layout (BP-36 R-36-57). Each MV layer zN of a 2×1 map gets
  // a distinct value so a swapped layer index shows up as a wrong field.
  test('reads every MV layer into its MapUnit field, z1 into ixDecor', () async {
    const w = 2, h = 1, size = w * h;
    final data = List<int>.filled(size * 6, 0);
    void put(int z, int x, int v) => data[z * size + x] = v;

    // (0,0): wood floor → rug → table → candle, shadow, region
    put(0, 0, 0x600 + 10); // A5 10, stored with the 1536 base
    put(1, 0, 66); // L2 rug
    put(2, 0, 15); // L3 table
    put(3, 0, 51); // L4 candle
    put(4, 0, 9); // shadow bits
    put(5, 0, 6); // region id
    // (1,0): bare floor, nothing else
    put(0, 1, 0x600 + 12);

    HDHosts().bind(
      ui: _UnusedUiHost(),
      movement: _UnusedMovementHost(),
      assets: _FakeAssets({
        'm.json': jsonEncode({
          'width': w,
          'height': h,
          'data': data,
          'events': [],
        }),
      }),
    );

    final map = await HDMapLoader().loadMap('m.json');

    final set = map.getUnit(0, 0)!;
    expect(set.ixTile, 10);
    expect(set.ixDecor, 66);
    expect(set.ixObj0, 15);
    expect(set.ixObj1, 51);
    expect(set.shadow, 9);
    expect(set.ixEvent, 6);

    final bare = map.getUnit(1, 0)!;
    expect(bare.ixTile, 12);
    expect(bare.ixDecor, 0);
    expect(bare.ixObj0, 0);
    expect(bare.ixObj1, 0);
  });

  group('MapUnit save round-trip', () {
    test('keeps ixDecor', () {
      final unit = MapUnit(ixTile: 10, ixDecor: 66, ixObj0: 15, ixObj1: 51);
      final back = MapUnit.fromJson(unit.toJson());
      expect(back.ixDecor, 66);
      expect(back.ixObj0, 15);
      expect(back.ixObj1, 51);
    });

    test('a save made before the five-layer layout loads with ixDecor 0', () {
      final old = MapUnit.fromJson({
        'ixTile': 10,
        'ixObj0': 0,
        'ixObj1': 15,
        'shadow': 0,
        'ixEvent': 0,
      });
      expect(old.ixDecor, 0);
      expect(old.ixObj1, 15);
    });
  });
}
