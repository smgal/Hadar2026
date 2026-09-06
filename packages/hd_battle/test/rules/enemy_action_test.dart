import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// Formulas 10-15, pinned against `battle.dart` `_enemyAttack`, plus the
/// appendix H-2 damage band reproduced through the shipped function.
void main() {
  group('formula 10 - target pick (battle.dart:504)', () {
    test('is a plain index into the conscious candidates', () {
      expect(pickTargetIndex(candidateCount: 4, rng: ScriptedRng([3])), 3);
    });
  });

  group('formula 11 - attack kind (battle.dart:507-510)', () {
    test('an enemy with no special and no cast level draws nothing', () {
      final rng = ScriptedRng(const []);
      final kind = chooseEnemyAttack(
        special: 0,
        castLevel: 0,
        strength: 9,
        accuracyPhysical: 9,
        accuracyMagical: 0,
        rng: rng,
      );
      expect(kind, EnemyAttackKind.physical);
      expect(
        rng.draws,
        0,
        reason:
            'the && short-circuits before the rolls; reordering this '
            'would shift every later draw in the battle',
      );
    });

    test('winning the roll with strength picks physical', () {
      final kind = chooseEnemyAttack(
        special: 1,
        castLevel: 1,
        strength: 9,
        accuracyPhysical: 10,
        accuracyMagical: 10,
        rng: ScriptedRng([5000, 1]),
      );
      expect(kind, EnemyAttackKind.physical);
    });

    test('losing the roll picks the special', () {
      final kind = chooseEnemyAttack(
        special: 1,
        castLevel: 1,
        strength: 9,
        accuracyPhysical: 10,
        accuracyMagical: 10,
        rng: ScriptedRng([1, 5000]),
      );
      expect(kind, EnemyAttackKind.special);
    });

    test('winning the roll with zero strength still uses the special', () {
      // Phantom (id 6) is exactly this: strength 0, castLevel 2.
      final kind = chooseEnemyAttack(
        special: 0,
        castLevel: 2,
        strength: 0,
        accuracyPhysical: 0,
        accuracyMagical: 13,
        rng: ScriptedRng([0, 0]),
      );
      expect(kind, EnemyAttackKind.special);
    });

    test('draws twice when a special is available', () {
      final rng = ScriptedRng([0, 0]);
      chooseEnemyAttack(
        special: 1,
        castLevel: 0,
        strength: 5,
        accuracyPhysical: 1,
        accuracyMagical: 1,
        rng: rng,
      );
      expect(rng.draws, 2);
    });
  });

  group('formula 12 - enemy spell damage (battle.dart:518)', () {
    test('is level x 5 plus a [0,10) draw', () {
      expect(enemySpellDamage(enemyLevel: 4, rng: ScriptedRng([7])), 27);
    });
  });

  group('formula 13 - member resists (battle.dart:533)', () {
    test('the party rolls against 50, not 100', () {
      // Resistance 25 stops half of all attacks, where the same value on
      // an enemy would stop a quarter. The asymmetry is the original's.
      var stopped = 0;
      for (var draw = 0; draw < 50; draw++) {
        if (memberResistsAttack(
          memberResistance: 25,
          rng: ScriptedRng([draw]),
        )) {
          stopped++;
        }
      }
      expect(stopped, 25);
    });
  });

  // B5-05 replaced the enemy's own `(random(10)+1)/10` spread with the
  // shared graze multiplier, so both sides vary the same way now and
  // `agility` is what moves it.
  group('formulas 14-15 - enemy physical damage, after B5-05', () {
    test('attack, graze and defence apply in that order', () {
      // attack:  9 * 1                        = 9
      // graze:   9 * 40 ~/ 100                = 3
      // defence: 3 - (2 * 1 * (4 + 1)) ~/ 10  = 3 - 1 = 2
      expect(
        enemyPhysicalDamage(
          enemyStrength: 9,
          enemyLevel: 1,
          memberAc: 2,
          memberLevelPhysical: 1,
          rng: ScriptedRng([4]),
          graze: 40,
        ),
        2,
      );
    });

    test('draws once now — the spread moved out to the graze roll', () {
      final rng = ScriptedRng([0]);
      enemyPhysicalDamage(
        enemyStrength: 1,
        enemyLevel: 1,
        memberAc: 1,
        memberLevelPhysical: 1,
        rng: rng,
      );
      expect(rng.draws, 1);
    });
  });

  group('the damage band, through the shipped function', () {
    /// Enumerates every graze step against every defence draw, the way
    /// appendix H-2's table was produced. Calls the shipped function
    /// rather than restating it, so the numbers cannot drift away from
    /// the rule.
    ///
    /// **Appendix H-2's own figures belong to the pre-B5-05 chain** and
    /// are not reproduced here — the variance moved from an internal
    /// `(random(10)+1)/10` to the graze roll, which widened the spread.
    ({double hitRate, int maxDamage}) band({
      required String enemyKey,
      required int memberAc,
      int memberLevel = 1,
    }) {
      final e = enemyByKey[enemyKey]!;
      var hits = 0;
      var cases = 0;
      var worst = 0;
      for (var graze = 10; graze <= 100; graze += 10) {
        for (var defence = 0; defence < 10; defence++) {
          cases++;
          final damage = enemyPhysicalDamage(
            enemyStrength: e.strength,
            enemyLevel: e.level,
            memberAc: memberAc,
            memberLevelPhysical: memberLevel,
            rng: ScriptedRng([defence]),
            graze: graze,
          );
          if (damage > 0) {
            hits++;
            if (damage > worst) worst = damage;
          }
        }
      }
      return (hitRate: hits * 100 / cases, maxDamage: worst);
    }

    test('armour still attenuates monotonically', () {
      var previous = 101.0;
      for (final ac in [0, 2, 5, 10, 20]) {
        final rate = band(enemyKey: 'troll', memberAc: ac).hitRate;
        expect(rate, lessThanOrEqualTo(previous), reason: 'ac \$ac');
        previous = rate;
      }
    });

    test('a full graze is the old maximum — the ceiling did not move', () {
      // graze 100 with no defence draw is `strength * level`, which is
      // what the inherited formula's best case already was.
      expect(band(enemyKey: 'troll', memberAc: 0).maxDamage, 9);
      expect(band(enemyKey: 'orc', memberAc: 0).maxDamage, 8);
    });

    test('ac 20 is hard attenuation, not immunity', () {
      final r = band(enemyKey: 'troll', memberAc: 20);
      expect(r.hitRate, greaterThan(0));
      expect(r.maxDamage, greaterThan(0));
    });

    test('the floor is reachable — a clean dodge stays possible', () {
      expect(
        enemyPhysicalDamage(
          enemyStrength: 40,
          enemyLevel: 20,
          memberAc: 0,
          memberLevelPhysical: 1,
          rng: ScriptedRng([0]),
          graze: 0,
        ),
        0,
      );
    });
  });
}
