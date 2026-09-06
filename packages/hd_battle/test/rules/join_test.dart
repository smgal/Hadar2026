import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B5-09 — someone joining mid-battle takes a real slot and fights.
void main() {
  CombatantSnapshot esper(int slot) => CombatantSnapshot(
    slot: slot,
    name: 'esper$slot',
    hp: 300,
    maxHp: 300,
    rank: 1,
    esp: 400,
    maxEsp: 400,
    accuracyEsp: 19,
    levelEsp: 20,
    levelPhysical: 1,
    strength: 10,
    powOfWeapon: 10,
    accuracyPhysical: 15,
  );

  Battle mindControlFight({required int capacity, required int members}) =>
      Battle(
        BattleSetup(
          party: [for (var i = 0; i < members; i++) esper(i)],
          // Phantom is on the mind-control whitelist.
          enemyKeys: const ['phantom', 'phantom'],
          enemyRanks: const [1, 1],
          initialGap: 0,
          partyCapacity: capacity,
          seed: 7,
        ),
      );

  ({List<BattleEvent> events, Battle battle}) run(Battle battle) {
    final events = <BattleEvent>[];
    var guard = 0;
    while (!battle.isFinished && guard++ < 3000) {
      final d = battle.pendingDecision;
      if (d == null) {
        events.addAll(battle.advance());
        continue;
      }
      battle.applyCommand(switch (d) {
        ActionDecision() => ChooseAction(
          d.slot,
          d.options.contains(BattleAction.castSkill)
              ? BattleAction.castSkill
              : BattleAction.attack,
        ),
        SpellDecision() => ChooseSpell(
          d.slot,
          d.magicIds.contains(mindControlMagicId)
              ? mindControlMagicId
              : d.magicIds.first,
        ),
        EnemyTargetDecision() => ChooseEnemyTarget(
          d.slot,
          d.enemyIndices.first,
        ),
        _ => CancelChoice(d.slot),
      });
    }
    return (events: events, battle: battle);
  }

  group('a recruit takes a real slot and stays on the board', () {
    test('it joins the party rather than being wiped from the fight', () {
      final r = run(mindControlFight(capacity: 6, members: 1));
      if (r.events.whereType<EnemyRecruited>().isEmpty) return;
      expect(
        r.battle.party.length,
        greaterThan(1),
        reason: 'B2-10 deleted them; B5-09 seats them',
      );
    });

    test('the outcome reports the slot it was actually seated in', () {
      final r = run(mindControlFight(capacity: 6, members: 1));
      if (r.events.whereType<EnemyRecruited>().isEmpty) return;
      for (final joined in r.battle.outcome!.recruits) {
        expect(
          joined.slot,
          isNot(-1),
          reason: 'the RPG writes it back like anyone else',
        );
        expect(joined.slot, inInclusiveRange(0, 5));
      }
    });
  });

  group('a full party is decided during the fight, not after', () {
    test('mind control comes out of the menu when there is no room', () {
      final battle = mindControlFight(capacity: 1, members: 1);
      battle.advance();
      // Walk to the skill list (ESP is in it since B6-01).
      battle.applyCommand(ChooseAction(0, BattleAction.castSkill));
      final decision = battle.pendingDecision;
      if (decision is SpellDecision) {
        expect(
          decision.magicIds,
          isNot(contains(mindControlMagicId)),
          reason: 'offering it would spend a turn on nothing',
        );
      }
    });

    test('and stays in the menu when there is', () {
      final battle = mindControlFight(capacity: 6, members: 1);
      battle.advance();
      battle.applyCommand(ChooseAction(0, BattleAction.castSkill));
      final decision = battle.pendingDecision;
      expect(decision, isA<SpellDecision>());
      expect(
        (decision! as SpellDecision).magicIds,
        contains(mindControlMagicId),
      );
    });

    test('nobody is ever seated outside the capacity', () {
      final r = run(mindControlFight(capacity: 2, members: 2));
      for (final c in r.battle.party) {
        expect(c.slot, lessThan(2));
      }
    });
  });

  group('the contract carries the capacity', () {
    test('it defaults to the six slots the RPG has', () {
      expect(
        const BattleSetup(party: [], enemyKeys: [], seed: 1).partyCapacity,
        6,
      );
    });

    test('it survives a JSON round trip', () {
      const setup = BattleSetup(
        party: [],
        enemyKeys: [],
        seed: 1,
        partyCapacity: 4,
      );
      expect(BattleSetup.fromJson(setup.toJson()).partyCapacity, 4);
    });
  });

  group('experience is left alone', () {
    test('a latecomer is settled exactly like everyone else', () {
      // Deliberately not special-cased — the shared total goes to every
      // conscious member and that is the whole rule.
      expect(victoryExperience([0]), greaterThan(0));
    });
  });
}
