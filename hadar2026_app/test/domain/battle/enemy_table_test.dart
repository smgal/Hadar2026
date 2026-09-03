import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/battle.dart';
import 'package:hadar2026_app/domain/battle/enemy_data.dart';

void main() {
  group('enemyTable', () {
    test('holds 75 rows, id 0..74', () {
      expect(enemyTable.length, 75);
      expect(enemyTable.first.name, 'Orc');
      expect(enemyTable.last.id, 74);
    });

    // battle.dart's experience formula is `(e.data.id + 1)^3 ~/ 8`, so a
    // row whose id disagrees with its index would pay out the wrong
    // amount for the wrong monster.
    test('every row id equals its index', () {
      for (var i = 0; i < enemyTable.length; i++) {
        expect(enemyTable[i].id, i, reason: enemyTable[i].name);
      }
    });
  });

  group('HDBattle.registerEnemy', () {
    setUp(HDBattle().init);
    tearDown(HDBattle().init);

    // The guard read `<= 0`, so id 0 could never be summoned from cm2
    // even though the row exists. No shipped script uses 0 as a
    // sentinel — the values in use are 1, 3, 5, 7, 26, 69, 71.
    test('accepts id 0 (Orc), the whole table is reachable', () {
      HDBattle().registerEnemy(0);
      expect(HDBattle().enemies.length, 1);
      expect(HDBattle().enemies.single.name.text, 'Orc');
    });

    test('accepts the last id', () {
      HDBattle().registerEnemy(74);
      expect(HDBattle().enemies.length, 1);
    });

    test('an out-of-range id is refused, not silently dropped', () {
      // town1.cm2:50 has a commented-out RegisterEnemy(75) — the kind of
      // mistake the silent guard used to hide.
      HDBattle().registerEnemy(75);
      HDBattle().registerEnemy(-1);
      expect(HDBattle().enemies, isEmpty);
    });
  });
}
