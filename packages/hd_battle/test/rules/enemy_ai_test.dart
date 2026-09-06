import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B2-07. The dispatcher, the casting ladder, and the innate abilities.
void main() {
  group('the dispatcher', () {
    EnemyIntent intent({
      int special = 0,
      int castLevel = 0,
      int strength = 10,
      int agility = 10,
      int accuracyPhysical = 10,
      int accuracyMagical = 10,
      int consciousPlayers = 2,
      List<int> draws = const [1, 0],
    }) => chooseEnemyIntent(
      special: special,
      castLevel: castLevel,
      strength: strength,
      agility: agility,
      accuracyPhysical: accuracyPhysical,
      accuracyMagical: accuracyMagical,
      consciousPlayers: consciousPlayers,
      rng: ScriptedRng(draws),
    );

    test('a plain enemy swings', () {
      // No special, so the agility roll is short-circuited away and the
      // first two draws are the accuracy comparison.
      expect(intent(), EnemyIntent.weapon);
    });

    test('a caster that loses the roll casts', () {
      expect(intent(castLevel: 3, draws: [0, 5000]), EnemyIntent.cast);
    });

    test('a caster with no strength casts even when it wins the roll', () {
      // Phantom is exactly this: strength 0, castLevel 2.
      expect(
        intent(castLevel: 2, strength: 0, draws: [5000, 0]),
        EnemyIntent.cast,
      );
    });

    test('an enemy with no cast level swings even when it loses', () {
      expect(intent(castLevel: 0, draws: [0, 5000]), EnemyIntent.weapon);
    });

    test('the special ability needs FOUR conscious party members', () {
      // With the two-member starting party this branch never fires,
      // which is a large part of why enemies felt flat.
      for (final count in [1, 2, 3]) {
        expect(
          intent(
            special: 1,
            agility: 20,
            consciousPlayers: count,
            draws: [0, 1, 0],
          ),
          isNot(EnemyIntent.special),
          reason: '$count conscious',
        );
      }
      expect(
        intent(special: 1, agility: 20, consciousPlayers: 4, draws: [0]),
        EnemyIntent.special,
      );
    });

    test('agility is capped at 20 for that roll', () {
      // A draw of 20 must fail even for an absurdly nimble enemy.
      expect(
        intent(special: 1, agility: 99, consciousPlayers: 6, draws: [20, 1, 0]),
        isNot(EnemyIntent.special),
      );
      expect(
        intent(special: 1, agility: 99, consciousPlayers: 6, draws: [19]),
        EnemyIntent.special,
      );
    });

    test('a superhuman caster gets an extra turn', () {
      // The original has no `return` after the superhuman cast, so the
      // enemy acts twice. `specialCastLevel` had zero readers before.
      expect(hasSuperhumanTurn(specialCastLevel: 0), isFalse);
      expect(hasSuperhumanTurn(specialCastLevel: 1), isTrue);
      expect(hasSuperhumanTurn(specialCastLevel: 3), isTrue);
    });
  });

  group('the casting ladder', () {
    EnemySpellPlan plan({
      required int castLevel,
      int hp = 100,
      int endurance = 10,
      int level = 10,
      int mentality = 12,
      int consciousPlayers = 4,
      int enemyCount = 1,
      int totalEnemyHp = 100,
      int totalEnemyMaxHp = 100,
      int averagePartyAc = 0,
      List<int> draws = const [0, 0, 0, 0],
    }) => chooseEnemySpell(
      castLevel: castLevel,
      hp: hp,
      endurance: endurance,
      level: level,
      mentality: mentality,
      consciousPlayers: consciousPlayers,
      enemyCount: enemyCount,
      totalEnemyHp: totalEnemyHp,
      totalEnemyMaxHp: totalEnemyMaxHp,
      averagePartyAc: averagePartyAc,
      rng: ScriptedRng(draws, repeat: true),
    );

    test('level 0 does nothing', () {
      expect(plan(castLevel: 0), isA<NoSpell>());
    });

    test('level 1 picks blind', () {
      final p = plan(castLevel: 1) as CastAtOne;
      expect(p.target, EnemySpellTarget.anyone);
    });

    test('level 2 picks a conscious target', () {
      final p = plan(castLevel: 2) as CastAtOne;
      expect(p.target, EnemySpellTarget.randomConscious);
    });

    test('level 3 splits on random(conscious) < 2', () {
      expect(plan(castLevel: 3, draws: [1]), isA<CastAtOne>());
      expect(plan(castLevel: 3, draws: [3]), isA<CastAtAll>());
    });

    test('level 4 heals itself below a third of its health', () {
      // max hp is endurance x level = 100, so a third is 33.
      expect(plan(castLevel: 4, hp: 30, draws: [0]), isA<HealSelf>());
      expect(
        plan(castLevel: 4, hp: 90, draws: [0]),
        isA<CastAtOne>(),
        reason: 'healthy enemies attack',
      );
    });

    test('the self-heal is level x mentality / 4', () {
      final p =
          plan(castLevel: 4, hp: 10, level: 10, mentality: 12, draws: [0])
              as HealSelf;
      expect(p.amount, 30);
      expect(
        enemyCureAmount(level: 10, mentality: 12, onSelf: false),
        20,
        reason: 'an ally gets less - / 6 rather than / 4',
      );
    });

    test('level 5 heals the whole group when the group is in trouble', () {
      // hurt? no. random(conscious) < 2? yes. enemies > 2? yes.
      // group under a third? yes. coin(2) == 0? yes.
      final p = plan(
        castLevel: 5,
        hp: 100,
        enemyCount: 4,
        totalEnemyHp: 20,
        totalEnemyMaxHp: 400,
        draws: [1, 0],
      );
      expect(p, isA<HealAllies>());
    });

    test('level 5 targets the weakest when it is not healing', () {
      final p = plan(castLevel: 5, enemyCount: 1, draws: [1, 0]) as CastAtOne;
      expect(p.target, EnemySpellTarget.weakestConscious);
    });

    test('level 6 grinds armour when the party is well armoured', () {
      final p = plan(castLevel: 6, hp: 100, averagePartyAc: 6, draws: [0]);
      expect(p, isA<StripArmour>());
    });

    test('level 6 leaves a lightly armoured party alone', () {
      expect(
        plan(castLevel: 6, hp: 100, averagePartyAc: 3, draws: [0, 0, 1]),
        isNot(isA<StripArmour>()),
      );
    });

    test('every level from 1 to 6 produces a plan', () {
      for (var level = 1; level <= 6; level++) {
        expect(
          plan(castLevel: level),
          isNot(isA<NoSpell>()),
          reason: 'cast level $level',
        );
      }
    });

    test('a zero-conscious party does not crash the ladder', () {
      // `random(0)` throws in Dart; the guard keeps the range at 1.
      for (var level = 1; level <= 6; level++) {
        expect(
          () => plan(castLevel: level, consciousPlayers: 0),
          returnsNormally,
          reason: 'cast level $level',
        );
      }
    });
  });

  group('enemy cures reach the dead', () {
    test('the rule is recorded', () {
      expect(
        enemyCureTargetsDead,
        isTrue,
        reason:
            '`enemyCastCureSpell` clears `dead` before anything '
            'else, so enemies revive their fallen allies',
      );
    });
  });

  group('innate abilities', () {
    test('the three map off the special field', () {
      expect(enemySpecialFor(1), EnemySpecial.poison);
      expect(enemySpecialFor(2), EnemySpecial.knockOut);
      expect(enemySpecialFor(3), EnemySpecial.slay);
      expect(enemySpecialFor(0), isNull);
      expect(enemySpecialFor(4), isNull);
    });

    test('harder abilities roll against a wider range', () {
      expect(specialAbilityRange(EnemySpecial.poison), 40);
      expect(specialAbilityRange(EnemySpecial.knockOut), 50);
      expect(specialAbilityRange(EnemySpecial.slay), 60);
    });

    test('only the killing one reaches someone already down', () {
      expect(specialAbilityHitsDowned(EnemySpecial.poison), isFalse);
      expect(specialAbilityHitsDowned(EnemySpecial.knockOut), isFalse);
      expect(
        specialAbilityHitsDowned(EnemySpecial.slay),
        isTrue,
        reason:
            'PLAYERSTATUS_NOT_DEAD, so a collapsed member is not '
            'safe from it',
      );
    });

    test('agility gates it, then luck saves', () {
      // agility 30 vs range 40: a draw of 31 misses.
      expect(
        resolveSpecialAbility(
          EnemySpecial.poison,
          enemyAgility: 30,
          targetLuck: 0,
          rng: ScriptedRng([31]),
        ),
        SpecialAbilityOutcome.missed,
      );
      // Lands, then luck 10 beats a draw of 5.
      expect(
        resolveSpecialAbility(
          EnemySpecial.poison,
          enemyAgility: 30,
          targetLuck: 10,
          rng: ScriptedRng([10, 5]),
        ),
        SpecialAbilityOutcome.luckSaved,
      );
      // Lands, and luck 10 loses to a draw of 15.
      expect(
        resolveSpecialAbility(
          EnemySpecial.poison,
          enemyAgility: 30,
          targetLuck: 10,
          rng: ScriptedRng([10, 15]),
        ),
        SpecialAbilityOutcome.applied,
      );
    });

    test('luck 0 never saves anybody', () {
      for (var draw = 0; draw < 20; draw++) {
        expect(
          resolveSpecialAbility(
            EnemySpecial.slay,
            enemyAgility: 60,
            targetLuck: 0,
            rng: ScriptedRng([0, draw]),
          ),
          SpecialAbilityOutcome.applied,
          reason: 'the starting party has luck 0',
        );
      }
    });

    test('the armour grind is resisted by luck against random(21)', () {
      expect(armourGrindResisted(luck: 0, rng: ScriptedRng([0])), isFalse);
      expect(armourGrindResisted(luck: 20, rng: ScriptedRng([19])), isTrue);
      expect(armourGrindResisted(luck: 20, rng: ScriptedRng([20])), isFalse);
    });

    test('the poison ability retries for an unpoisoned target', () {
      expect(poisonTargetAttempts, 5);
    });
  });
}
