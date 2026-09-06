import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B5-02 — a weapon is a table, and the table's job is to make sure a
/// turn is never wasted no matter where the fight has drifted to.
void main() {
  group('every weapon can do something at every distance', () {
    test('nothing in the table leaves a turn empty', () {
      // This is the invariant B5 rests on. A weapon with no answer at
      // some distance would be a wasted turn wearing a different name.
      for (final weapon in weaponTable.values) {
        for (var d = 0; d <= longestPossibleReach; d++) {
          final attack = chooseAttack(weapon, d);
          expect(attack.power, greaterThan(0), reason: '${weapon.key} at $d');
        }
      }
    });

    test('an unknown key falls back to bare hands rather than throwing', () {
      expect(weaponFor('a weapon nobody has heard of').key, 'unarmed');
    });
  });

  group('long weapons have a minimum, and that is what balances reach', () {
    test('the lance cannot be used up close', () {
      final lance = weaponTable['lance']!;
      final point = lance.attacks.first;
      expect(point.minReach, greaterThan(0));
      expect(point.covers(0), isFalse);
      expect(point.covers(3), isTrue);
    });

    test('so up close it falls back to the shaft, and the shaft is weak', () {
      final lance = weaponTable['lance']!;
      final close = chooseAttack(lance, 0);
      expect(close.method, AttackMethod.blunt);
      expect(close.power, lessThan(lance.attacks.first.power));
    });

    test('charging in makes the lance the wrong weapon for where it is', () {
      // The self-balancing loop: it closes, hits hard, and is then
      // holding the thing it is worst with.
      final lance = weaponTable['lance']!;
      expect(
        chooseAttack(lance, 3).power,
        greaterThan(chooseAttack(lance, 0).power),
      );
    });

    test('every polearm carries a close-in answer', () {
      for (final key in ['halberd', 'poleaxe', 'trident', 'lance']) {
        final close = chooseAttack(weaponTable[key]!, 0);
        expect(close.covers(0), isTrue, reason: key);
      }
    });
  });

  group(
    'four of the original ten are polearms — the idea was already there',
    () {
      test('they reach further than the daggers and maces', () {
        for (final long in ['halberd', 'poleaxe', 'trident', 'lance']) {
          for (final short in ['dagger', 'club', 'mace', 'unarmed']) {
            expect(
              weaponTable[long]!.longestReach,
              greaterThan(weaponTable[short]!.longestReach),
              reason: '$long vs $short',
            );
          }
        }
      });

      test('only some weapons can charge', () {
        final chargers = [
          for (final w in weaponTable.values)
            if (w.canCharge) w.key,
        ];
        expect(chargers, isNotEmpty);
        expect(chargers.length, lessThan(weaponTable.length));
        expect(chargers, contains('lance'));
      });
    },
  );

  group('the strongest fitting method wins', () {
    test('a long sword slashes at range and thrusts up close', () {
      final sword = weaponTable['long_sword']!;
      expect(chooseAttack(sword, 2).method, AttackMethod.slash);
      expect(chooseAttack(sword, 0).method, AttackMethod.pierce);
    });

    test('out of every band, the least-far one is used', () {
      final lance = weaponTable['lance']!;
      // Distance 5 is past everything; the point is closer to fitting
      // than the shaft is.
      expect(chooseAttack(lance, 5).method, AttackMethod.pierce);
    });
  });

  group('the method decides the element', () {
    test('each maps onto the one affinity axis', () {
      expect(elementOfMethod(AttackMethod.slash), Element.slash);
      expect(elementOfMethod(AttackMethod.pierce), Element.pierce);
      expect(elementOfMethod(AttackMethod.blunt), Element.blunt);
    });
  });

  group('enemies carry weapons too', () {
    test('the roster has a spread of reaches — otherwise gap is scenery', () {
      final reaches = <int>{};
      for (final data in enemyTable) {
        reaches.add(
          weaponFor(
            enemyWeaponKey(
              key: data.key,
              strength: data.strength,
              agility: data.agility,
            ),
          ).longestReach,
        );
      }
      expect(
        reaches.length,
        greaterThan(1),
        reason:
            'if both sides only held reach-1 weapons the gap would '
            'never mean anything',
      );
    });

    test('something with no arms fights in close', () {
      expect(
        weaponFor(
          enemyWeaponKey(key: 'ghost', strength: 0, agility: 0),
        ).longestReach,
        lessThanOrEqualTo(1),
      );
    });

    test('a named creature keeps its named weapon', () {
      expect(enemyWeaponKey(key: 'centaur', strength: 1, agility: 1), 'lance');
    });
  });

  group('the snapshot carries the key, not the profile', () {
    test('the RPG says how hard, the battle says how it reaches', () {
      const c = CombatantSnapshot(
        slot: 0,
        name: 'a',
        hp: 1,
        maxHp: 1,
        powOfWeapon: 42,
        weaponKey: 'lance',
      );
      expect(c.powOfWeapon, 42, reason: 'how hard comes from the RPG');
      expect(
        weaponFor(c.weaponKey).longestReach,
        3,
        reason: 'how far comes from here',
      );
    });

    test('it survives a JSON round trip', () {
      const c = CombatantSnapshot(
        slot: 0,
        name: 'a',
        hp: 1,
        maxHp: 1,
        weaponKey: 'halberd',
      );
      expect(CombatantSnapshot.fromJson(c.toJson()).weaponKey, 'halberd');
    });
  });
}
