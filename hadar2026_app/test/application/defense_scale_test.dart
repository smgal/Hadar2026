import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/domain/battle/enemy_data.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/player.dart';

/// The player-side defence formula, copied verbatim from
/// `battle.dart` `_enemyAttack`:
///
/// ```dart
/// int damage = (e.strength * e.level * (Random().nextInt(10) + 1)) ~/ 10;
/// damage -= (t.ac * t.level.physical * (Random().nextInt(10) + 1)) ~/ 10;
/// ```
///
/// Both `Random()` calls are unseeded (P0-11), so the real formula cannot
/// be driven from a test. Enumerating all 10x10 draws instead gives the
/// exact distribution — which is how GROUND_TRUTH H-2's table was
/// produced.
///
/// **If these numbers change, fix appendix H-2 first, then this test.**
({double hitRate, int maxDamage}) _distribution({
  required int enemyStrength,
  required int enemyLevel,
  required int playerAc,
  required int playerLevel,
}) {
  var hits = 0;
  var worst = 0;
  for (var a = 1; a <= 10; a++) {
    for (var d = 1; d <= 10; d++) {
      var damage = (enemyStrength * enemyLevel * a) ~/ 10;
      damage -= (playerAc * playerLevel * d) ~/ 10;
      if (damage > 0) {
        hits++;
        if (damage > worst) worst = damage;
      }
    }
  }
  return (hitRate: hits / 100 * 100, maxDamage: worst);
}

const _troll = 1; // enemyTable[1]
const _orc = 0; // enemyTable[0]

({double hitRate, int maxDamage}) _vs(int enemyId, int ac,
        {int playerLevel = 1}) =>
    _distribution(
      enemyStrength: enemyTable[enemyId].strength,
      enemyLevel: enemyTable[enemyId].level,
      playerAc: ac,
      playerLevel: playerLevel,
    );

void main() {
  group('the H-2 table reproduces exactly', () {
    // GROUND_TRUTH H-2 (corrected edition), Troll (id 1): strength 9,
    // level 1, against a level-1 player.
    test('Troll: ac 2/5/9/10/20', () {
      expect(_vs(_troll, 2).hitRate, 83.0);
      expect(_vs(_troll, 5).hitRate, 65.0);
      expect(_vs(_troll, 9).hitRate, 45.0);
      expect(_vs(_troll, 10).hitRate, 36.0);
      expect(_vs(_troll, 20).hitRate, 16.0);

      expect(_vs(_troll, 2).maxDamage, 9);
      expect(_vs(_troll, 10).maxDamage, 8);
      expect(_vs(_troll, 20).maxDamage, 7);
    });

    test('Orc: ac 10 and 20', () {
      expect(_vs(_orc, 10).hitRate, 31.0);
      expect(_vs(_orc, 20).hitRate, 13.0);
    });

    // The claim H-2's first edition got wrong: ac 20 is a hard
    // attenuation, not an immunity.
    test('ac 20 still takes damage roughly one turn in six', () {
      final r = _vs(_troll, 20);
      expect(r.hitRate, greaterThan(0));
      expect(r.maxDamage, greaterThan(0));
    });
  });

  group('the original item data lands in the party stat band', () {
    // party.dart gives the starting members baseAc 5 and 3.
    // Shields run ac 0..5 and body armour 0..5 in the ported catalog.
    test('starting gear keeps the player where the party band already is',
        () {
      final p = HDPlayer()..baseAc = 3;
      p.equipItem(HDEquipSlot.handSub,
          const HDItemId(HDItemType.shield, index: 1)); // 가죽 방패, ac 1
      p.equipItem(HDEquipSlot.armor,
          const HDItemId(HDItemType.armor, index: 1)); // 가죽 갑옷, ac 1
      expect(p.ac, 5);

      final rate = _vs(_troll, p.ac).hitRate;
      expect(rate, inInclusiveRange(55.0, 70.0));
    });

    test('a full set of the best ported gear stays under ac 15', () {
      final p = HDPlayer()..baseAc = 5;
      p.equipItem(HDEquipSlot.handSub,
          const HDItemId(HDItemType.shield, index: 5)); // ac 5
      p.equipItem(HDEquipSlot.armor,
          const HDItemId(HDItemType.armor, index: 5)); // ac 5
      // Head/leg/ornament carry no ac in the original tables.
      p.equipItem(HDEquipSlot.head,
          const HDItemId(HDItemType.head, index: 10));
      expect(p.ac, 15);
      expect(_vs(_troll, 15).hitRate, lessThan(_vs(_troll, 5).hitRate));
    });
  });

  group('the shield actually does something', () {
    test('taking it off makes the player easier to hit', () {
      final p = HDPlayer()..baseAc = 3;
      p.equipItem(HDEquipSlot.armor,
          const HDItemId(HDItemType.armor, index: 1));
      p.equipItem(HDEquipSlot.handSub,
          const HDItemId(HDItemType.shield, index: 3)); // ac 3

      final withShield = _vs(_troll, p.ac).hitRate;
      p.unequip(HDEquipSlot.handSub);
      final without = _vs(_troll, p.ac).hitRate;

      expect(without, greaterThan(withShield));
    });
  });

  group('the ac ladder for content planning', () {
    // Recorded in G2-01 in the same shape as appendix H-2.
    test('is monotonically decreasing', () {
      var previous = 101.0;
      for (final ac in [3, 5, 7, 10, 15, 20, 25]) {
        final rate = _vs(_troll, ac).hitRate;
        expect(rate, lessThan(previous), reason: 'ac $ac');
        previous = rate;
      }
    });
  });
}
