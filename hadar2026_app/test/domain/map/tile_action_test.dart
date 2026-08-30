import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/domain/map/map_unit.dart';
import 'package:hadar2026_app/domain/map/tile_properties.dart';

void main() {
  group('HDTileAction.scriptMode', () {
    // These values are the wire contract with cm2: `ScriptMode()` is
    // compared against FLAG_MAP/TALK/SIGN/EVENT/ENTER in
    // assets/const.cm2. Changing them silently mis-branches every cm2
    // map script, so pin them here.
    test('matches the FLAG_* constants in assets/const.cm2', () {
      expect(HDTileAction.none.scriptMode, 0, reason: 'FLAG_MAP');
      expect(HDTileAction.talk.scriptMode, 1, reason: 'FLAG_TALK');
      expect(HDTileAction.sign.scriptMode, 2, reason: 'FLAG_SIGN');
      expect(HDTileAction.event.scriptMode, 3, reason: 'FLAG_EVENT');
      expect(HDTileAction.enter.scriptMode, 4, reason: 'FLAG_ENTER');
    });

    test('is unique across every action', () {
      final modes = HDTileAction.values.map((a) => a.scriptMode).toList();
      expect(modes.toSet().length, modes.length);
    });
  });

  group('HDTileAction.isInteractive', () {
    test('is exactly talk / sign / enter', () {
      final interactive =
          HDTileAction.values.where((a) => a.isInteractive).toSet();
      expect(interactive, {
        HDTileAction.talk,
        HDTileAction.sign,
        HDTileAction.enter,
      });
    });
  });

  group('HDTileAction.isStepOn', () {
    test('is exactly event / enter', () {
      final stepOn = HDTileAction.values.where((a) => a.isStepOn).toSet();
      expect(stepOn, {HDTileAction.event, HDTileAction.enter});
    });

    test('enter is the only action that is both interactive and step-on', () {
      final both = HDTileAction.values
          .where((a) => a.isInteractive && a.isStepOn)
          .toSet();
      expect(both, {HDTileAction.enter});
    });
  });

  group('HDTileAction.debugTag', () {
    test('labels the seven traced actions and leaves the rest empty', () {
      expect(HDTileAction.talk.debugTag, 'Tak');
      expect(HDTileAction.sign.debugTag, 'Sig');
      expect(HDTileAction.event.debugTag, 'Evt');
      expect(HDTileAction.enter.debugTag, 'Ent');
      expect(HDTileAction.water.debugTag, 'Wtr');
      expect(HDTileAction.swamp.debugTag, 'Swm');
      expect(HDTileAction.lava.debugTag, 'Lav');

      expect(HDTileAction.none.debugTag, isEmpty);
      expect(HDTileAction.cliff.debugTag, isEmpty);
      expect(HDTileAction.move.debugTag, isEmpty);
    });
  });

  group('HDTileProperties.isUnitPassable', () {
    test('a null unit is never passable', () {
      expect(HDTileProperties.isUnitPassable(null), isFalse);
    });

    test('blocks every interactive tile (they occupy the tile)', () {
      // ixTile 64..69 maps to ACTION_ENTER via _getTileAction.
      final enterUnit = MapUnit(ixTile: 64, ixObj1: 0, ixEvent: 0);
      expect(HDTileProperties.getUnitAction(enterUnit), HDTileAction.enter);
      expect(HDTileProperties.isUnitPassable(enterUnit), isFalse);
    });

    test('plain ground is passable', () {
      final moveUnit = MapUnit(ixTile: 10, ixObj1: 0, ixEvent: 0);
      expect(HDTileProperties.getUnitAction(moveUnit), HDTileAction.move);
      expect(HDTileProperties.isUnitPassable(moveUnit), isTrue);
    });

    test('deep water blocks; shallow water opens only with the buff', () {
      final deep = MapUnit(ixTile: 57, ixObj1: 0, ixEvent: 0);
      final shallow = MapUnit(ixTile: 56, ixObj1: 0, ixEvent: 0);

      expect(HDTileProperties.getUnitAction(shallow), HDTileAction.water);
      expect(HDTileProperties.isUnitPassable(shallow), isFalse);
      expect(HDTileProperties.isUnitPassable(shallow, walkOnWater: 1), isTrue);

      // The buff does not open deep water.
      expect(HDTileProperties.isUnitPassable(deep, walkOnWater: 1), isFalse);
    });
  });
}
