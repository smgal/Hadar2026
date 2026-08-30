import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/map_navigation.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/domain/map/tile_properties.dart';

/// Serves assets from a plain map — no Flutter asset bundle, no
/// filesystem. This is the headless seam the ports exist for.
class _FakeAssets implements AssetSource {
  _FakeAssets(this.files);

  final Map<String, String> files;
  final List<String> reads = [];

  @override
  Future<String> loadString(String path) async {
    reads.add(path);
    final content = files[path];
    if (content == null) {
      throw Exception('asset not found: $path');
    }
    return content;
  }
}

/// A map with a single walkable row and one TALK event at (1, 0).
String _mapJson({int width = 3, int height = 1}) {
  final size = width * height;
  // Six layers, in the order HDMapLoader reads them
  // (0 tile, 1 unused, 2 obj0, 3 obj1, 4 shadow, 5 event region).
  final data = List<int>.filled(size * 6, 0);
  for (var i = 0; i < size; i++) {
    data[i] = 10; // ixTile 10 -> HDTileAction.move
  }
  return jsonEncode({
    'width': width,
    'height': height,
    'data': data,
    'events': [
      {
        'id': 7,
        // MapEvent.type is derived from the name prefix
        // (TALK/ENTER/EVENT/NPC/SIGN), not a separate field.
        'name': 'TALK_greeter',
        'x': 1,
        'y': 0,
        'pages': [
          {
            'list': [
              {
                'code': 401,
                'parameters': ['안녕하시오.'],
              },
            ],
          },
        ],
      },
    ],
  });
}

void main() {
  late _FakeAssets assets;

  void bind(Map<String, String> files) {
    assets = _FakeAssets(files);
    HDHosts().bind(
      ui: _UnusedUiHost(),
      movement: _UnusedMovementHost(),
      assets: assets,
    );
  }

  tearDown(HDHosts().reset);

  group('HDHosts', () {
    test('reading a port before bind throws a StateError that names the fix', () {
      HDHosts().reset();
      expect(
        () => HDHosts().assets,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('bind()'),
          ),
        ),
      );
    });
  });

  group('HDMapNavigation.loadByName (headless, fake AssetSource)', () {
    test('resolves a name through MapInfos.json to its id-derived files', () async {
      bind({
        'assets/maps/MapInfos.json': jsonEncode([
          null,
          {'id': 13, 'name': 'TOWN1'},
        ]),
        'assets/maps/Map013.json': _mapJson(),
      });

      final bundle = await HDMapNavigation().loadByName('TOWN1');

      expect(bundle, isNotNull);
      expect(bundle!.mapName, 'TOWN1');
      expect(bundle.cm2Path, 'Map013.cm2', reason: 'id-derived cm2 default');
      expect(bundle.json, isNotNull);
      expect(bundle.json!.width, 3);
      expect(assets.reads, contains('assets/maps/Map013.json'));
    });

    test('honours the explicit json and cm2 overrides in the index', () async {
      bind({
        'assets/maps/MapInfos.json': jsonEncode([
          {
            'id': 2,
            'name': 'DEN1',
            'json': 'DEN1.json',
            'cm2': 'L1_ep1d1.cm2',
          },
        ]),
        'assets/maps/DEN1.json': _mapJson(),
      });

      final bundle = await HDMapNavigation().loadByName('DEN1');

      expect(bundle!.cm2Path, 'L1_ep1d1.cm2');
      expect(assets.reads, contains('assets/maps/DEN1.json'));
      expect(assets.reads, isNot(contains('assets/maps/Map002.json')));
    });

    test('a cm2-only map (no JSON) still resolves, with a null model', () async {
      bind({
        'assets/maps/MapInfos.json': jsonEncode([
          {'id': 5, 'name': 'ORIGIN', 'cm2': 'origin.cm2'},
        ]),
        // Map005.json deliberately absent.
      });

      final bundle = await HDMapNavigation().loadByName('ORIGIN');

      expect(bundle, isNotNull);
      expect(bundle!.json, isNull);
      expect(bundle.cm2Path, 'origin.cm2');
      expect(HDMapNavigation().errorMessage, isNull);
    });

    test('a name with neither JSON nor cm2 fails with an error message', () async {
      bind({'assets/maps/MapInfos.json': jsonEncode(<dynamic>[])});

      final bundle = await HDMapNavigation().loadByName('NOPE');

      expect(bundle, isNull);
      expect(HDMapNavigation().errorMessage, contains('Failed to load map'));
    });

    test('parses tile data and JSON dialogue out of the loaded map', () async {
      bind({
        'assets/maps/MapInfos.json': jsonEncode([
          {'id': 1, 'name': 'TOWN1'},
        ]),
        'assets/maps/Map001.json': _mapJson(),
      });

      final map = (await HDMapNavigation().loadByName('TOWN1'))!.json!;

      expect(
        HDTileProperties.getUnitAction(map.getUnit(0, 0)),
        HDTileAction.move,
      );
      // The event at (1, 0) is stamped onto the unit as a TALK action.
      expect(
        HDTileProperties.getUnitAction(map.getUnit(1, 0)),
        HDTileAction.talk,
      );
      expect(map.events.single.dialogLines, ['안녕하시오.']);
    });
  });
}

// The navigation use-case never touches these, but `bind` takes the full
// set — that is the point: one place lists everything a frontend owes
// the application layer.
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
