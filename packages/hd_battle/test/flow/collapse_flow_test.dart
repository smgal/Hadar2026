import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

/// B2-04 in the battle, not just in the rule.
void main() {
  /// Both members aim at enemy 0 so the second one meets whatever the
  /// first one left behind.
  BattleCommand? bothOnFirstEnemy(BattleDecision decision) =>
      switch (decision) {
        ActionDecision() => ChooseAction(decision.slot, BattleAction.attack),
        EnemyTargetDecision() => ChooseEnemyTarget(
          decision.slot,
          decision.enemyIndices.contains(0) ? 0 : decision.enemyIndices.first,
        ),
        SpellDecision() => ChooseSpell(decision.slot, decision.magicIds.first),
        ItemDecision() => ChooseItem(decision.slot, decision.itemKeys.first),
        AllyTargetDecision() => ChooseAllyTarget(
          decision.slot,
          decision.slots.first,
        ),
        OrderDecision() => ChooseAction(decision.slot, decision.options.first),
        ItemUseDecision() => ChooseItemUse(decision.slot, ItemUse.coat),
      };

  group('an enemy at zero hit points is collapsed, not dead', () {
    test('the collapse event fires and dead stays 0', () {
      var seen = false;
      for (var seed = 0; seed < 80 && !seen; seed++) {
        final battle = Battle(
          startingSetup(enemyKeys: ['orc', 'orc'], seed: seed),
        );
        final run = runBattle(battle, bothOnFirstEnemy);
        for (final e in run.events.whereType<EnemyCollapsed>()) {
          seen = true;
          expect(battle.enemies[e.enemyIndex].hp, 0);
        }
      }
      expect(seen, isTrue, reason: 'no seed produced a collapse');
    });
  });

  group('the accumulator, in the battle', () {
    test('a second attacker in the same round deepens a collapse', () {
      var deepened = false;
      for (var seed = 0; seed < 200 && !deepened; seed++) {
        final battle = Battle(
          startingSetup(enemyKeys: ['orc', 'orc', 'orc'], seed: seed),
        );
        final run = runBattle(battle, bothOnFirstEnemy);
        final piled = run.events.whereType<EnemyDamaged>().where(
          (e) => e.whileCollapsed,
        );
        if (piled.isNotEmpty) {
          deepened = true;
          // The blow went onto the accumulator, not hit points.
          expect(battle.enemies[piled.first.enemyIndex].hp, 0);
          expect(
            battle.enemies[piled.first.enemyIndex].unconscious,
            greaterThan(1),
          );
        }
      }
      expect(
        deepened,
        isTrue,
        reason: 'no seed let a second attacker reach a collapsed target',
      );
    });

    test('a heavy enough blow finishes a collapsed enemy outright', () {
      // Orc: endurance 8, level 1 -> threshold 8, so the second blow has
      // to land more than 8. The starting party cannot; a stronger
      // second attacker can.
      var finished = false;
      for (var seed = 0; seed < 200 && !finished; seed++) {
        final battle = Battle(
          BattleSetup(
            party: [
              seumgal(),
              const CombatantSnapshot(
                slot: 1,
                name: 'Heavy',
                strength: 60,
                powOfWeapon: 60,
                levelPhysical: 3,
                accuracyPhysical: 19,
                endurance: 10,
                ac: 4,
                hp: 100,
                maxHp: 100,
              ),
            ],
            enemyKeys: const ['orc', 'orc', 'orc'],
            seed: seed,
          ),
        );
        final run = runBattle(battle, bothOnFirstEnemy);
        final blows = run.events.whereType<EnemyFinished>().toList();
        if (blows.isNotEmpty) {
          finished = true;
          expect(battle.enemies[blows.first.enemyIndex].dead, 1);
        }
      }
      expect(
        finished,
        isTrue,
        reason:
            'the sentence the inherited battle could never print '
            '(battle.dart:437-447) still never prints',
      );
    });

    test('finishing awards no second helping of experience', () {
      for (var seed = 0; seed < 200; seed++) {
        final battle = Battle(
          startingSetup(enemyKeys: ['orc', 'orc', 'orc'], seed: seed),
        );
        final run = runBattle(battle, bothOnFirstEnemy);
        final collapses = run.events.whereType<EnemyCollapsed>().length;
        if (collapses == 0) continue;

        final settled =
            run.events.whereType<ExperienceSettled>().singleOrNull?.total ?? 0;
        var bonuses = 0;
        for (final c in run.outcome.combatants) {
          final shared = (c.dead == 0 && c.unconscious == 0) ? settled : 0;
          bonuses += c.experienceGained - shared;
        }
        // Three orcs at level 1 are worth 10 each, once.
        expect(
          bonuses,
          lessThanOrEqualTo(30),
          reason: 'seed $seed paid for a collapse twice',
        );
        expect(
          bonuses,
          collapses * 10,
          reason: 'one award per collapse, none for the finishing blow',
        );
        return;
      }
      fail('no seed in 0..199 produced a collapse');
    });
  });

  group('a spell drops an enemy the same way a weapon does', () {
    test('collapse, clamp and experience all happen', () {
      var collapsed = false;
      for (var seed = 0; seed < 80 && !collapsed; seed++) {
        final battle = Battle(
          startingSetup(enemyKeys: ['orc', 'orc'], seed: seed),
        );
        final run = runBattle(
          battle,
          // B6-01: area magic is a scope in the one list, not a menu line.
          castFirst((o) => o.scope == SkillScope.allEnemies),
        );
        final bySpell = run.events.whereType<EnemyCollapsed>().where(
          (e) => e.source == DamageSource.spell,
        );
        if (bySpell.isNotEmpty) {
          collapsed = true;
          for (final e in bySpell) {
            expect(
              battle.enemies[e.enemyIndex].hp,
              0,
              reason: 'a spell used to leave hit points negative',
            );
          }
          // The inherited battle awarded nothing for a spell kill.
          expect(
            run.outcome.combatants.any((c) => c.experienceGained > 0),
            isTrue,
          );
        }
      }
      expect(collapsed, isTrue);
    });
  });

  group('the party collapses too, and stays recoverable', () {
    test('a wipe leaves nobody standing', () {
      final battle = Battle(
        startingSetup(
          enemyKeys: ['neo_necromancer'],
          seed: 3,
          seumgalHp: 1,
          yuriHp: 1,
        ),
      );
      final run = runBattle(battle, alwaysAttack);

      expect(run.outcome.resultCode, BattleResultCode.lose);
      for (final c in run.outcome.combatants) {
        expect(c.hp, 0);
        expect(
          c.unconscious >= 1 || c.dead == 1,
          isTrue,
          reason:
              'collapsed or killed - Neo-Necromancer has '
              'specialCastLevel 3, so its mass slay (B2-11) can set '
              '`dead` without going through the accumulator',
        );
      }
    });
  });

  group('poison on the party', () {
    test('ticks once a round and can finish the collapsed', () {
      final battle = Battle(
        BattleSetup(
          party: [
            CombatantSnapshot(
              slot: 0,
              name: 'Poisoned',
              hp: 3,
              maxHp: 30,
              poison: 2,
              accuracyPhysical: 19,
              strength: 18,
              powOfWeapon: 10,
              levelPhysical: 1,
            ),
          ],
          // Tough enough that the party phase cannot end the battle before
          // the enemy phase - which is where the party poison ticks.
          enemyKeys: const ['neo_necromancer'],
          seed: 4,
        ),
      );
      final run = runBattle(battle, alwaysAttack);

      expect(
        run.events.whereType<MemberPoisonTick>(),
        isNotEmpty,
        reason: 'the inherited battle never read the party poison field',
      );
      expect(
        run.outcome.combatants.single.unconscious == 1 ||
            run.outcome.combatants.single.dead == 1,
        isTrue,
      );
    });

    test('poison is the party death path', () {
      final battle = Battle(
        BattleSetup(
          party: [
            CombatantSnapshot(
              slot: 0,
              name: 'Doomed',
              hp: 1,
              maxHp: 30,
              poison: 99,
              accuracyPhysical: 0,
            ),
          ],
          enemyKeys: const ['neo_necromancer'],
          seed: 1,
        ),
      );
      final run = runBattle(battle, alwaysAttack);
      expect(run.outcome.resultCode, BattleResultCode.lose);
    });
  });
}
