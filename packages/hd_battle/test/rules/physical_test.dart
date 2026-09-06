import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// Formulas 1-6, pinned against `battle.dart` `_executeAttack`.
///
/// Every test drives the shipped function through a scripted draw
/// sequence. Nothing here re-implements the arithmetic — that was the
/// weakness of `hadar2026_app/test/application/defense_scale_test.dart`,
/// which had to copy the formula because the original could not be
/// driven at all.
void main() {
  group('formula 1 - physical attack misses (battle.dart:450)', () {
    test('a draw above accuracy misses, equal or below hits', () {
      for (var accuracy = 0; accuracy <= 20; accuracy++) {
        for (var draw = 0; draw < 20; draw++) {
          expect(
            physicalAttackMisses(
              accuracyPhysical: accuracy,
              rng: ScriptedRng([draw]),
            ),
            draw > accuracy,
            reason: 'accuracy $accuracy, draw $draw',
          );
        }
      }
    });

    test('accuracy 19 or more never misses on a [0,20) draw', () {
      for (var draw = 0; draw < 20; draw++) {
        expect(
          physicalAttackMisses(accuracyPhysical: 19, rng: ScriptedRng([draw])),
          isFalse,
        );
      }
    });

    test('draws exactly once', () {
      final rng = ScriptedRng([0]);
      physicalAttackMisses(accuracyPhysical: 5, rng: rng);
      expect(rng.draws, 1);
    });
  });

  group('formula 2 - enemy resists (battle.dart:455)', () {
    test('resistance is a percentage against a [0,100) draw', () {
      expect(
        enemyResistsAttack(enemyResistance: 0, rng: ScriptedRng([0])),
        isFalse,
      );
      expect(
        enemyResistsAttack(enemyResistance: 70, rng: ScriptedRng([69])),
        isTrue,
      );
      expect(
        enemyResistsAttack(enemyResistance: 70, rng: ScriptedRng([70])),
        isFalse,
      );
    });
  });

  // B5-05 replaced the inherited `random(50)` attenuation with the
  // graze multiplier. Two sources of variance measured out at 3.09
  // average damage against an Orc where one gives 3.90 — physical was
  // already the weak half of the game and could not carry both.
  group('formulas 3-5 - physical damage, after B5-05', () {
    test('base, graze and defence apply in that order', () {
      // base:    20 * 3 * 2 ~/ 20            = 6
      // graze:   6 * 50 ~/ 100               = 3
      // defence: 3 - (2 * 1 * (4 + 1)) ~/ 10 = 3 - 1 = 2
      expect(
        physicalDamage(
          strength: 20,
          powOfWeapon: 3,
          levelPhysical: 2,
          enemyAc: 2,
          enemyLevel: 1,
          rng: ScriptedRng([4]),
          graze: 50,
        ),
        2,
      );
    });

    test('ungrazed is the default, so a caller can opt out', () {
      expect(
        physicalDamage(
          strength: 20,
          powOfWeapon: 3,
          levelPhysical: 2,
          enemyAc: 0,
          enemyLevel: 0,
          rng: ScriptedRng([0]),
        ),
        6,
      );
    });

    test('draws once now, not twice — one source of variance', () {
      final rng = ScriptedRng([0]);
      physicalDamage(
        strength: 0,
        powOfWeapon: 0,
        levelPhysical: 0,
        enemyAc: 0,
        enemyLevel: 0,
        rng: rng,
      );
      expect(rng.draws, 1);
    });

    test('can come out zero or negative', () {
      final damage = physicalDamage(
        strength: 1,
        powOfWeapon: 1,
        levelPhysical: 1,
        enemyAc: 10,
        enemyLevel: 5,
        rng: ScriptedRng([0, 9]),
      );
      expect(damage, lessThanOrEqualTo(0));
    });

    test('bare-hand attack power of 1 is not free damage', () {
      // 8 * 1 * 1 ~/ 20 == 0 before any roll.
      expect(
        physicalDamage(
          strength: 8,
          powOfWeapon: 1,
          levelPhysical: 1,
          enemyAc: 0,
          enemyLevel: 0,
          rng: ScriptedRng([0, 0]),
        ),
        0,
      );
    });
  });

  group('formula 6 - kill experience (battle.dart:446, :494)', () {
    test('is ten times the enemy level', () {
      expect(killExperience(enemyLevel: 0), 0);
      expect(killExperience(enemyLevel: 3), 30);
      expect(killExperience(enemyLevel: 30), 300);
    });
  });
  _damageChain();
}

/// B5-05 — the rebuilt chain: immunity instead of a resistance roll,
/// one graze multiplier instead of two spreads.
void _damageChain() {
  group('immunity replaces the resistance roll', () {
    test('over half the roster was never resisting anything anyway', () {
      // 38 of 75 rows sit at resistance 0, so the roll it replaced did
      // nothing at all for most of the game (appendix W-4).
      final none = [
        for (final e in enemyTable)
          if (immunityFor(resistance: e.resistance) == Immunity.none) e,
      ];
      expect(none.length, greaterThan(enemyTable.length ~/ 2));
    });

    test('the ones the original meant to be unhittable still are', () {
      // Stheno and Euryale carry resistance 255, where the old
      // `random(100) < 255` was always true.
      for (final key in ['stheno', 'euryale', 'sprite']) {
        expect(
          immunityFor(resistance: enemyByKey[key]!.resistance),
          Immunity.physical,
          reason: key,
        );
      }
    });

    test('an ordinary creature has no immunity', () {
      for (final key in ['orc', 'troll', 'giant', 'wolf']) {
        expect(
          immunityFor(resistance: enemyByKey[key]!.resistance),
          Immunity.none,
          reason: key,
        );
      }
    });
  });

  group('the graze multiplier', () {
    test('a clean dodge is reachable — zero has to stay possible', () {
      expect(grazeScale(accuracy: 0, evasion: 40, rng: ScriptedRng([0])), 0);
    });

    test('and so is a solid hit', () {
      expect(grazeScale(accuracy: 40, evasion: 0, rng: ScriptedRng([99])), 100);
    });

    test('the edge moves the centre, so agility finally matters', () {
      final slow = grazeScale(
        accuracy: 10,
        evasion: 30,
        rng: ScriptedRng([50]),
      );
      final fast = grazeScale(
        accuracy: 30,
        evasion: 10,
        rng: ScriptedRng([50]),
      );
      expect(fast, greaterThan(slow));
    });

    test('it never leaves 0..100', () {
      final rng = SeededRng(3);
      for (var i = 0; i < 2000; i++) {
        final v = grazeScale(accuracy: i % 40, evasion: (i * 7) % 40, rng: rng);
        expect(v, inInclusiveRange(0, 100));
      }
    });

    test('one draw, always', () {
      final rng = SeededRng(1);
      grazeScale(accuracy: 5, evasion: 5, rng: rng);
      expect(rng.draws, 1);
    });
  });

  group('the shield folded into evasion', () {
    test('it raises evasion rather than pre-empting the roll', () {
      expect(
        evasionOf(agility: 10, luck: 0, shieldBlock: 45),
        greaterThan(evasionOf(agility: 10, luck: 0)),
      );
    });

    test('no shield is a wall', () {
      expect(
        evasionOf(agility: 0, luck: 0, shieldBlock: 999),
        evasionOf(agility: 0, luck: 0, shieldBlock: maxShieldBlock),
      );
    });
  });
}
