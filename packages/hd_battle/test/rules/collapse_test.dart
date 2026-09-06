import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B2-04 and B2-03. One rule for losing hit points, with `unconscious`
/// as an accumulator rather than a flag.
void main() {
  group('still standing', () {
    test('damage that does not reach zero just takes hit points', () {
      final r = applyDamage(
        hp: 10,
        unconscious: 0,
        dead: 0,
        amount: 3,
        deathThreshold: 8,
      );
      expect(r.hp, 7);
      expect(r.unconscious, 0);
      expect(r.outcome, CollapseOutcome.none);
      expect(r.damageApplied, 3);
    });

    test('reaching zero collapses, and does not kill', () {
      final r = applyDamage(
        hp: 3,
        unconscious: 0,
        dead: 0,
        amount: 3,
        deathThreshold: 8,
      );
      expect(r.hp, 0);
      expect(r.unconscious, 1);
      expect(r.dead, 0);
      expect(r.outcome, CollapseOutcome.collapsed);
    });

    test('hit points are clamped at zero', () {
      // The inherited battle left party members at negative hit points
      // and handed that to the RPG (appendix O-7).
      final r = applyDamage(
        hp: 3,
        unconscious: 0,
        dead: 0,
        amount: 999,
        deathThreshold: 8,
      );
      expect(r.hp, 0);
      expect(r.damageApplied, 3, reason: 'only what was there was taken');
      expect(
        r.unconscious,
        1,
        reason: 'overkill does not spill into the accumulator',
      );
    });
  });

  group('collapsed - the accumulator', () {
    test('further damage piles up without killing', () {
      final r = applyDamage(
        hp: 0,
        unconscious: 1,
        dead: 0,
        amount: 4,
        deathThreshold: 8,
      );
      expect(r.unconscious, 5);
      expect(r.dead, 0);
      expect(r.outcome, CollapseOutcome.deepened);
    });

    test('death arrives when the accumulator passes the threshold', () {
      // Exactly at the threshold is still alive; the C++ test was `>`.
      final atThreshold = applyDamage(
        hp: 0,
        unconscious: 1,
        dead: 0,
        amount: 7,
        deathThreshold: 8,
      );
      expect(atThreshold.unconscious, 8);
      expect(atThreshold.dead, 0);

      final past = applyDamage(
        hp: 0,
        unconscious: 1,
        dead: 0,
        amount: 8,
        deathThreshold: 8,
      );
      expect(past.dead, 1);
      expect(past.outcome, CollapseOutcome.finished);
    });

    test('a tougher target absorbs more before dying', () {
      final tough = applyDamage(
        hp: 0,
        unconscious: 1,
        dead: 0,
        amount: 20,
        deathThreshold: 100,
      );
      final frail = applyDamage(
        hp: 0,
        unconscious: 1,
        dead: 0,
        amount: 20,
        deathThreshold: 3,
      );
      expect(tough.dead, 0);
      expect(frail.dead, 1);
    });

    test(
      'the threshold has a floor of 1 so the weakest can still collapse',
      () {
        expect(unconsciousDeathThreshold(endurance: 0, level: 5), 1);
        expect(unconsciousDeathThreshold(endurance: 5, level: 0), 1);
        expect(unconsciousDeathThreshold(endurance: 8, level: 1), 8);
        expect(unconsciousDeathThreshold(endurance: 15, level: 1), 15);
      },
    );
  });

  group('already dead', () {
    test('is left alone', () {
      final r = applyDamage(
        hp: 0,
        unconscious: 9,
        dead: 1,
        amount: 50,
        deathThreshold: 8,
      );
      expect(r.outcome, CollapseOutcome.alreadyDead);
      expect(r.unconscious, 9, reason: 'nothing accumulates after death');
      expect(r.damageApplied, 0);
    });
  });

  group('poison uses the same rule', () {
    test('no poison changes nothing', () {
      final r = applyPoisonTick(
        hp: 9,
        poison: 0,
        unconscious: 0,
        dead: 0,
        deathThreshold: 8,
      );
      expect(r.hp, 9);
      expect(r.outcome, CollapseOutcome.none);
    });

    test('poison collapses like anything else', () {
      final r = applyPoisonTick(
        hp: 2,
        poison: 5,
        unconscious: 0,
        dead: 0,
        deathThreshold: 8,
      );
      expect(r.hp, 0);
      expect(r.unconscious, 1);
      expect(r.outcome, CollapseOutcome.collapsed);
    });

    test('poison eats through the accumulator over several rounds', () {
      var unconscious = 1;
      var rounds = 0;
      var dead = 0;
      while (dead == 0 && rounds < 20) {
        final r = applyPoisonTick(
          hp: 0,
          poison: 3,
          unconscious: unconscious,
          dead: dead,
          deathThreshold: 8,
        );
        unconscious = r.unconscious;
        dead = r.dead;
        rounds++;
      }
      expect(dead, 1);
      expect(rounds, 3, reason: '1 -> 4 -> 7 -> 10 passes 8 on the third');
    });
  });

  group('every path agrees', () {
    test('poison and a weapon reach the same state', () {
      // The three answers the inherited battle had (appendix O-4).
      final byPoison = applyPoisonTick(
        hp: 5,
        poison: 5,
        unconscious: 0,
        dead: 0,
        deathThreshold: 8,
      );
      final byDamage = applyDamage(
        hp: 5,
        unconscious: 0,
        dead: 0,
        amount: 5,
        deathThreshold: 8,
      );
      for (final r in [byPoison, byDamage]) {
        expect(r.hp, 0);
        expect(r.unconscious, 1);
        expect(r.dead, 0);
        expect(r.outcome, CollapseOutcome.collapsed);
      }
    });
  });

  group('condition reading', () {
    test('worst state wins', () {
      expect(
        conditionOf(hp: 30, poison: 0, unconscious: 0, dead: 0),
        Condition.good,
      );
      expect(
        conditionOf(hp: 30, poison: 2, unconscious: 0, dead: 0),
        Condition.poisoned,
      );
      expect(
        conditionOf(hp: 0, poison: 2, unconscious: 1, dead: 0),
        Condition.unconscious,
      );
      expect(
        conditionOf(hp: 0, poison: 2, unconscious: 9, dead: 1),
        Condition.dead,
      );
    });

    test('zero hit points reads as unconscious even without the flag', () {
      expect(
        conditionOf(hp: 0, poison: 0, unconscious: 0, dead: 0),
        Condition.unconscious,
      );
    });
  });

  group('stat reduction clamps - the C++ tree does not', () {
    test('never goes below the floor', () {
      // `castSpellWithSpecialAbility` case 3 does a bare
      // `resistance -= 10`, and case 4's guard still lets 5 become -5.
      expect(reduceStat(5, 10), 0);
      expect(reduceStat(0, 10), 0);
      expect(reduceStat(70, 10), 60);
    });

    test('a floor other than zero works', () {
      // 능력 저하 must not take a level below 1.
      expect(reduceStat(1, 1, floor: 1), 1);
      expect(reduceStat(4, 1, floor: 1), 3);
    });
  });
}
