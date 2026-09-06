import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

/// B1-04: the battle runs to completion on `pendingDecision` /
/// `applyCommand` / `advance` alone, and B1's reproducibility criterion.
void main() {
  group('a battle runs to the end without a view', () {
    test('attacking until nothing stands wins the battle', () {
      final battle = Battle(startingSetup(enemyKeys: ['orc'], seed: 7));
      final run = runBattle(battle, alwaysAttack);

      expect(run.outcome.resultCode, BattleResultCode.win);
      expect(battle.enemies.every((e) => !e.isConscious), isTrue);
      expect(run.events.whereType<BattleEnded>().length, 1);
    });

    test('the opening step announces the enemies and opens round 1', () {
      final battle = Battle(startingSetup(enemyKeys: ['orc', 'wolf']));
      expect(battle.phase, BattlePhase.intro);
      expect(battle.round, 0);

      final events = battle.advance();
      expect(events.first, isA<EnemiesAppeared>());
      expect((events.first as EnemiesAppeared).enemyIndices, [0, 1]);
      expect(events.whereType<RoundStarted>().single.round, 1);
      expect(battle.round, 1);
      expect(battle.phase, BattlePhase.collecting);
    });

    test('advance throws while a decision is pending', () {
      final battle = Battle(startingSetup());
      battle.advance();
      expect(battle.pendingDecision, isA<ActionDecision>());
      expect(battle.advance, throwsStateError);
    });

    test('applyCommand throws when nothing is pending', () {
      final battle = Battle(startingSetup());
      expect(
        () => battle.applyCommand(const CancelChoice(0)),
        throwsStateError,
      );
    });

    test('a command for the wrong slot is refused', () {
      final battle = Battle(startingSetup());
      battle.advance();
      expect(
        () => battle.applyCommand(const CancelChoice(5)),
        throwsArgumentError,
      );
    });
  });

  group('reproducibility - B1 completion criterion', () {
    test('same setup, same commands, same seed give the same outcome', () {
      final first = runBattle(
        Battle(startingSetup(enemyKeys: ['giant', 'wolf'], seed: 99)),
        alwaysAttack,
      );
      final second = runBattle(
        Battle(startingSetup(enemyKeys: ['giant', 'wolf'], seed: 99)),
        alwaysAttack,
      );
      expect(second.outcome.toJson(), first.outcome.toJson());
    });

    test('a different seed generally gives a different outcome', () {
      final a = runBattle(
        Battle(startingSetup(enemyKeys: ['giant', 'wolf'], seed: 1)),
        alwaysAttack,
      );
      final b = runBattle(
        Battle(startingSetup(enemyKeys: ['giant', 'wolf'], seed: 2)),
        alwaysAttack,
      );
      expect(b.outcome.toJson(), isNot(a.outcome.toJson()));
    });

    test('the same seed draws the same number of times', () {
      final a = Battle(startingSetup(seed: 5));
      runBattle(a, alwaysAttack);
      final b = Battle(startingSetup(seed: 5));
      runBattle(b, alwaysAttack);
      expect(b.rng.draws, a.rng.draws);
      expect(a.rng.draws, greaterThan(0));
    });
  });

  group('losing', () {
    test('a wipe reports lose and settles nothing', () {
      // One hit point each against the strongest row in the table.
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
      expect(run.outcome.goldGained, 0);
      expect(
        run.events.whereType<ExperienceSettled>(),
        isEmpty,
        reason: 'the victory settlement only runs on a win',
      );
      // B2-04: collapsing is recoverable, so a wipe leaves the party
      // unconscious rather than dead. The RPG still sees `lose`.
      // The accumulator can be above 1 when someone was hit twice in a
      // round, which initiative order (B2-05) makes ordinary.
      expect(
        run.outcome.combatants.every((c) => c.unconscious >= 1 || c.dead == 1),
        isTrue,
      );
      expect(
        run.outcome.combatants.every((c) => c.hp == 0),
        isTrue,
        reason: 'hit points are clamped now (appendix O-7)',
      );
    });

    test('the model runs the game-over flow nowhere', () {
      // The original called HDMenuFlows().processGameOver(2) from inside
      // the battle (battle.dart:257). Here a wipe is only a result code.
      final battle = Battle(
        startingSetup(
          enemyKeys: ['neo_necromancer'],
          seed: 3,
          seumgalHp: 1,
          yuriHp: 1,
        ),
      );
      final run = runBattle(battle, alwaysAttack);
      expect(run.outcome.resultCode.wire, 2);
    });
  });

  group('escaping', () {
    test('a successful escape ends the battle at once', () {
      // B6-04: escape is the leader's (slot 0's) party action.
      var escaped = false;
      for (var seed = 0; seed < 60 && !escaped; seed++) {
        final battle = Battle(startingSetup(enemyKeys: ['orc'], seed: seed));
        final run = runBattle(
          battle,
          (decision) => switch (decision) {
            ActionDecision() => ChooseAction(
              decision.slot,
              decision.options.contains(BattleAction.escape)
                  ? BattleAction.escape
                  : BattleAction.attack,
            ),
            EnemyTargetDecision() => ChooseEnemyTarget(
              decision.slot,
              decision.enemyIndices.first,
            ),
            SpellDecision() => ChooseSpell(
              decision.slot,
              decision.magicIds.first,
            ),
            ItemDecision() => ChooseItem(
              decision.slot,
              decision.itemKeys.first,
            ),
            AllyTargetDecision() => ChooseAllyTarget(
              decision.slot,
              decision.slots.first,
            ),
            OrderDecision() => ChooseAction(
              decision.slot,
              decision.options.first,
            ),
            ItemUseDecision() => ChooseItemUse(decision.slot, ItemUse.coat),
          },
        );
        if (run.outcome.resultCode == BattleResultCode.evade) {
          escaped = true;
          expect(run.events.whereType<EscapeSucceeded>().length, 1);
          expect(run.outcome.goldGained, 0);
        }
      }
      expect(escaped, isTrue, reason: 'no seed in 0..59 produced an escape');
    });
  });

  group('experience is reported, never applied', () {
    test('a win gives every conscious member the shared total', () {
      final battle = Battle(startingSetup(enemyKeys: ['orc'], seed: 7));
      final run = runBattle(battle, alwaysAttack);

      final settled = run.events.whereType<ExperienceSettled>().single;
      // Orc is legacy id 0, so the floor of 1 applies.
      expect(settled.total, 1);

      for (final c in run.outcome.combatants) {
        expect(c.experienceGained, greaterThanOrEqualTo(settled.total));
      }
    });

    test('kill bonuses go to the attacker alone', () {
      final battle = Battle(startingSetup(enemyKeys: ['orc'], seed: 7));
      final run = runBattle(battle, alwaysAttack);
      final total = run.events.whereType<ExperienceSettled>().single.total;
      final bonuses = [
        for (final c in run.outcome.combatants) c.experienceGained - total,
      ];
      expect(
        bonuses.where((b) => b > 0).length,
        1,
        reason: 'exactly one member landed the killing blow',
      );
    });
  });
}
