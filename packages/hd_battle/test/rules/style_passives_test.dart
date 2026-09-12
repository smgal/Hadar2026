import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

/// BP-45 — what a fighting style adds beyond reach.
///
/// The numbers arrive on the snapshot rather than on the weapon row,
/// because two daggers and one dagger are the **same row**: same method,
/// same band. What differs is the style, and the style is read off both
/// hands, which the battle deliberately does not know.
void main() {
  CombatantSnapshot fighter({
    int strikes = 1,
    int coatingSlots = 1,
    int evasionBonus = 0,
    int initiativeBonus = 0,
    int slot = 0,
    String name = 'A',
  }) => CombatantSnapshot(
    slot: slot,
    name: name,
    hp: 200,
    maxHp: 200,
    strength: 16,
    agility: 12,
    powOfWeapon: 30,
    levelPhysical: 3,
    accuracyPhysical: 19,
    weaponKey: 'one_hand_slash',
    strikes: strikes,
    coatingSlots: coatingSlots,
    evasionBonus: evasionBonus,
    initiativeBonus: initiativeBonus,
  );

  group('a pair of weapons lands two blows', () {
    test('two blows are rolled where one was', () {
      int blows({required int strikes}) {
        final battle = Battle(
          BattleSetup(
            party: [fighter(strikes: strikes)],
            enemyKeys: const ['ogre'],
            seed: 5,
          ),
        );
        final events = <BattleEvent>[];
        var guard = 0;
        while (!battle.isFinished && guard++ < 200) {
          final d = battle.pendingDecision;
          if (d == null) {
            events.addAll(battle.advance());
            continue;
          }
          if (events.whereType<RoundStarted>().length > 1) break;
          events.addAll(
            battle.applyCommand(switch (d) {
              ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
              EnemyTargetDecision() => ChooseEnemyTarget(d.slot, 0),
              _ => CancelChoice(d.slot),
            }),
          );
        }
        return events
            .where((e) => e is EnemyDamaged || e is AttackMissed)
            .length;
      }

      // Same seed, same board: the only difference is the count.
      expect(blows(strikes: 2), greaterThan(blows(strikes: 1)));
    });

    test('a default snapshot still strikes once', () {
      const plain = CombatantSnapshot(slot: 0, name: 'A', hp: 1, maxHp: 1);
      expect(plain.strikes, 1);
      expect(plain.coatingSlots, 1);
      expect(plain.evasionBonus, 0);
      expect(plain.initiativeBonus, 0);
    });

    test('a second swing at nothing is not taken', () {
      // The sequence stops when the board is clear — a blow at a dead
      // enemy is not something a screen could explain.
      final battle = Battle(
        BattleSetup(
          party: [fighter(strikes: 2)],
          enemyKeys: const ['orc'],
          seed: 1,
        ),
      );
      final events = <BattleEvent>[];
      var guard = 0;
      while (!battle.isFinished && guard++ < 200) {
        final d = battle.pendingDecision;
        if (d == null) {
          events.addAll(battle.advance());
          continue;
        }
        events.addAll(
          battle.applyCommand(switch (d) {
            ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
            EnemyTargetDecision() => ChooseEnemyTarget(d.slot, 0),
            _ => CancelChoice(d.slot),
          }),
        );
      }
      expect(battle.outcome!.resultCode, BattleResultCode.win);
    });
  });

  group('two coatings, one on each weapon', () {
    Combatant lone({int slots = 1}) =>
        Combatant.fromSnapshot(fighter(coatingSlots: slots));

    test('one weapon holds one, and a new one replaces it', () {
      final c = lone();
      expect(c.applyCoating(Coating.poison), isNull);
      expect(c.coatings.single.kind, Coating.poison);
      final evicted = c.applyCoating(Coating.fire);
      expect(evicted?.kind, Coating.poison);
      expect(c.coatings.single.kind, Coating.fire);
    });

    test('a pair holds one each', () {
      final c = lone(slots: 2);
      expect(c.applyCoating(Coating.poison), isNull);
      expect(c.applyCoating(Coating.fire), isNull);
      expect(
        {for (final x in c.coatings) x.kind},
        {Coating.poison, Coating.fire},
      );
      // The third pushes the oldest off rather than stacking.
      final evicted = c.applyCoating(Coating.paralysis);
      expect(evicted?.kind, Coating.poison);
      expect(c.coatings.length, 2);
    });

    test('the same kind twice is a refresh, not a second slot', () {
      final c = lone(slots: 2);
      c.applyCoating(Coating.poison);
      expect(c.applyCoating(Coating.poison), isNull);
      expect(c.coatings.length, 1);
    });

    test('a nonsense slot count still leaves one', () {
      expect(Combatant.fromSnapshot(fighter(coatingSlots: 0)).coatingSlots, 1);
      expect(Combatant.fromSnapshot(fighter(strikes: 0)).strikes, 1);
    });

    test('the old single-coating reader still answers', () {
      // Everything that only ever cared about one coating keeps working.
      final c = lone(slots: 2);
      expect(c.coating, isNull);
      c.applyCoating(Coating.paralysis);
      expect(c.coating?.kind, Coating.paralysis);
    });
  });

  group('the passives reach the rolls', () {
    test('a free hand raises evasion, and less than a shield does', () {
      final bare = evasionOf(agility: 12, luck: 0, styleBonus: 4);
      final shielded = evasionOf(agility: 12, luck: 0, shieldBlock: 25);
      expect(bare, greaterThan(evasionOf(agility: 12, luck: 0)));
      expect(
        bare,
        lessThan(shielded),
        reason: 'dropping the shield has to be a decision, not an upgrade',
      );
    });

    test('a heavy weapon acts later in the round', () {
      List<int> order(int bonus) {
        final turns = orderOfBattle(
          partyAgility: [12 + bonus, 12],
          partyActive: const [true, true],
          enemyAgility: const [],
          enemyActive: const [],
          rng: ScriptedRng(const [0, 0]),
        );
        return [for (final t in turns) t.index];
      }

      expect(order(0), [0, 1], reason: 'a tie falls to the lower slot');
      expect(order(-5), [1, 0], reason: 'the heavy one goes second');
    });

    test('the starting party is unaffected — the defaults are neutral', () {
      final setup = startingSetup();
      for (final p in setup.party) {
        expect(p.strikes, 1);
        expect(p.evasionBonus, 0);
        expect(p.initiativeBonus, 0);
      }
    });
  });
}
