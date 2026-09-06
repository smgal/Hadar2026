import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B5-06 — physical elements on one chart with the magical ones, and
/// knockback as the reward that ties them to position.
void main() {
  Affinity chartFor(String key) {
    final e = enemyByKey[key]!;
    return fullAffinityOf(
      key: key,
      strength: e.strength,
      ac: e.ac,
      agility: e.agility,
      endurance: e.endurance,
    );
  }

  group('one chart, not two', () {
    test('an enemy carries its magical and physical affinities together', () {
      // The mummy's fire weakness (B2-09) has to survive alongside the
      // undead physical profile, or the player learns two tables.
      final mummy = chartFor('mummy');
      expect(mummy.weakTo, contains(Element.fire));
      expect(mummy.weakTo, contains(Element.blunt));
      expect(mummy.resists, contains(Element.slash));
    });
  });

  group('every creature reacts to weapons somehow', () {
    test('nothing in the table is indifferent to all three', () {
      // A creature no weapon type has an opinion about would make the
      // whole axis decoration for that fight.
      for (final e in enemyTable) {
        final chart = chartFor(e.key);
        final physical = {Element.slash, Element.pierce, Element.blunt};
        expect(chart.weakTo.intersection(physical), isNotEmpty, reason: e.key);
      }
    });

    test('flesh is the common case and a blade is the default answer', () {
      final ordinary = [
        for (final e in enemyTable)
          if (constitutionOf(
                key: e.key,
                strength: e.strength,
                ac: e.ac,
                agility: e.agility,
                endurance: e.endurance,
              ) ==
              Constitution.ordinary)
            e,
      ];
      expect(ordinary.length, greaterThan(enemyTable.length ~/ 3));
      expect(
        physicalAffinityOf(Constitution.ordinary).weakTo,
        contains(Element.slash),
      );
    });

    test('the undead invert it — that is when a sword stops working', () {
      final undead = physicalAffinityOf(Constitution.undead);
      expect(undead.resists, contains(Element.slash));
      expect(undead.weakTo, contains(Element.blunt));
    });
  });

  group('knockback is what makes elements and position one system', () {
    test('only weight drives anything back', () {
      // Letting every weakness push would move the line several times a
      // round, and position has to stay plannable.
      expect(knocksBack(Element.blunt, hitWeakness: true), isTrue);
      expect(knocksBack(Element.slash, hitWeakness: true), isFalse);
      expect(knocksBack(Element.pierce, hitWeakness: true), isFalse);
      expect(knocksBack(Element.fire, hitWeakness: true), isFalse);
    });

    test('and only when it found a weakness', () {
      expect(knocksBack(Element.blunt, hitWeakness: false), isFalse);
    });

    test('a pushed target gives ground until there is none', () {
      expect(pushBack(1), PushResult.moved);
      expect(pushBack(2), PushResult.moved);
      expect(pushBack(backRank), PushResult.cornered);
    });

    test('being cornered costs instead of doing nothing', () {
      // Otherwise the mechanic fizzles exactly where the fight has gone
      // furthest — against the thing standing at the back.
      expect(corneredBonusPercent, greaterThan(0));
    });
  });

  group('the follow-up hangs off state, not turn order', () {
    test('stagger is a mark, so initiative cannot turn it into a lottery', () {
      // B2-05 rolls initiative per round. "The attack right after a
      // knockback is stronger" would depend on a die nobody controls.
      expect(staggerBonusPercent, greaterThan(0));
    });

    test('a knocked-back enemy is marked, and the mark clears next round', () {
      final battle = Battle(
        BattleSetup(
          party: [
            const CombatantSnapshot(
              slot: 0,
              name: 'mace',
              hp: 200,
              maxHp: 200,
              rank: 1,
              strength: 18,
              powOfWeapon: 22,
              levelPhysical: 2,
              accuracyPhysical: 19,
              weaponKey: 'mace',
            ),
          ],
          enemyKeys: const ['skeleton'],
          enemyRanks: const [1],
          initialGap: 0,
          seed: 23,
        ),
      );
      var sawPush = false;
      var guard = 0;
      while (!battle.isFinished && guard++ < 400) {
        final d = battle.pendingDecision;
        if (d == null) {
          for (final e in battle.advance()) {
            if (e is EnemyPushedBack) sawPush = true;
            if (e is RoundStarted && sawPush) {
              expect(
                battle.enemies.every((x) => !x.staggered),
                isTrue,
                reason: 'the mark is worth one round of follow-up, no more',
              );
            }
          }
          continue;
        }
        battle.applyCommand(switch (d) {
          ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
          EnemyTargetDecision() => ChooseEnemyTarget(d.slot, 0),
          _ => CancelChoice(d.slot),
        });
      }
      expect(sawPush, isTrue, reason: 'a mace against bone should push');
    });
  });

  group('the party can be pushed by the same rule', () {
    test('a member with no weakness is never knocked back by weapons', () {
      const c = CombatantSnapshot(slot: 0, name: 'a', hp: 1, maxHp: 1);
      expect(c.weakTo, isEmpty);
    });

    test('a weakness survives a JSON round trip', () {
      const c = CombatantSnapshot(
        slot: 0,
        name: 'a',
        hp: 1,
        maxHp: 1,
        weakTo: {Element.blunt},
      );
      expect(CombatantSnapshot.fromJson(c.toJson()).weakTo, {Element.blunt});
    });
  });
}
