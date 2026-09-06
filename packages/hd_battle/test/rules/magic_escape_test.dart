import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// Formulas 7-9.
void main() {
  group('formulas 7-8 - spell damage (battle.dart:166, :185)', () {
    test('the all-enemy formula is (magic + esp) x 5 + [0,10)', () {
      expect(
        spellDamageAll(levelMagic: 3, levelEsp: 2, rng: ScriptedRng([4])),
        29,
      );
    });

    test('the single-enemy formula is (magic + esp) x 8 + [0,15)', () {
      expect(
        spellDamageSingle(levelMagic: 3, levelEsp: 2, rng: ScriptedRng([9])),
        49,
      );
    });

    test('neither reads the spell, which is why every spell is the same', () {
      // The signatures cannot even take a spell id. B2-01 is where that
      // changes; this test exists so the port cannot be mistaken for a
      // per-spell implementation.
      final a = spellDamageSingle(
        levelMagic: 1,
        levelEsp: 1,
        rng: ScriptedRng([0]),
      );
      final b = spellDamageSingle(
        levelMagic: 1,
        levelEsp: 1,
        rng: ScriptedRng([0]),
      );
      expect(a, b);
    });
  });

  group('formula 9 - escape (battle.dart:412-415)', () {
    test('average enemy agility is an integer mean', () {
      expect(averageEnemyAgility([8, 9, 11]), 9);
      expect(averageEnemyAgility([]), 0);
      expect(averageEnemyAgility([1, 2]), 1);
    });

    test('a tie counts as failure', () {
      // (agility 10 + luck 10) ~/ 2 + draw 5 = 15, block = 5 + 10 = 15
      expect(
        escapeSucceeds(
          agility: 10,
          luck: 10,
          averageEnemyAgility: 5,
          rng: ScriptedRng([5]),
        ),
        isFalse,
      );
    });

    test('one more than a tie succeeds', () {
      expect(
        escapeSucceeds(
          agility: 10,
          luck: 10,
          averageEnemyAgility: 5,
          rng: ScriptedRng([6]),
        ),
        isTrue,
      );
    });

    test('draws exactly once', () {
      final rng = ScriptedRng([0]);
      escapeSucceeds(agility: 0, luck: 0, averageEnemyAgility: 0, rng: rng);
      expect(rng.draws, 1);
    });
  });
}
