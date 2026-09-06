import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

/// Position is two integers, and the one invariant is that being out of
/// reach never costs a turn.
void main() {
  group('distance is gap plus both depths', () {
    test('front against front at gap zero is touching', () {
      expect(distanceBetween(gap: 0, attackerRank: 1, targetRank: 1), 0);
    });

    test('each step back on either side adds one', () {
      expect(distanceBetween(gap: 0, attackerRank: 3, targetRank: 1), 2);
      expect(distanceBetween(gap: 0, attackerRank: 1, targetRank: 3), 2);
      expect(distanceBetween(gap: 2, attackerRank: 3, targetRank: 3), 6);
    });

    test('the two sides are symmetric — advancing is one event', () {
      // Whoever "moves", the gap is what changed. That is why there is
      // one number and not two.
      for (var a = 1; a <= 3; a++) {
        for (var b = 1; b <= 3; b++) {
          expect(
            distanceBetween(gap: 1, attackerRank: a, targetRank: b),
            distanceBetween(gap: 1, attackerRank: b, targetRank: a),
          );
        }
      }
    });
  });

  group('out of reach is a penalty, never a void', () {
    test('in reach costs nothing', () {
      expect(reachPenalty(0).isNone, isTrue);
      expect(reachPenalty(-3).isNone, isTrue);
    });

    test('one step short costs accuracy and invites a blocker', () {
      final p = reachPenalty(1);
      expect(p.accuracy, greaterThan(0));
      expect(p.interception, greaterThan(0));
    });

    test('two steps is worse, and nothing beyond two is worse still', () {
      expect(reachPenalty(2).accuracy, greaterThan(reachPenalty(1).accuracy));
      expect(reachPenalty(5).accuracy, reachPenalty(2).accuracy);
    });

    test('interception never reaches certainty', () {
      // A blow that is guaranteed to land on someone else is a voided
      // turn wearing a different name.
      for (var short = 1; short <= 6; short++) {
        expect(reachPenalty(short).interception, lessThan(100));
      }
    });
  });

  group('ranks and the gap stay inside the board', () {
    test('nobody stands outside 1..3', () {
      expect(clampRank(0), frontRank);
      expect(clampRank(9), backRank);
      expect(clampRank(2), 2);
    });

    test('the gap stays inside 0..2', () {
      expect(clampGap(-1), 0);
      expect(clampGap(9), maxGap);
    });

    test('the back rank cannot retreat — that is being cornered', () {
      expect(canRetreat(1), isTrue);
      expect(canRetreat(2), isTrue);
      expect(canRetreat(backRank), isFalse);
    });
  });

  group('a side fronts with the rank it actually occupies', () {
    test('an empty front rank is not a front rank', () {
      expect(frontOf([2, 3, 3]), 2);
      expect(frontOf([1, 3]), 1);
    });

    test('nobody standing means the back', () {
      expect(frontOf(const <int>[]), backRank);
    });
  });

  group('formation orders are added, not contested', () {
    test('advancing into a retreat leaves the gap alone', () {
      expect(
        resolveFormation(
          gap: 1,
          party: FormationOrder.advance,
          enemy: FormationOrder.retreat,
        ),
        1,
      );
    });

    test('both charging closes twice as fast', () {
      expect(
        resolveFormation(
          gap: 2,
          party: FormationOrder.advance,
          enemy: FormationOrder.advance,
        ),
        0,
      );
    });

    test('the result never leaves the board', () {
      expect(
        resolveFormation(
          gap: 0,
          party: FormationOrder.advance,
          enemy: FormationOrder.advance,
        ),
        0,
      );
      expect(
        resolveFormation(
          gap: 2,
          party: FormationOrder.retreat,
          enemy: FormationOrder.retreat,
        ),
        maxGap,
      );
    });

    test('holding on both sides changes nothing', () {
      expect(
        resolveFormation(
          gap: 1,
          party: FormationOrder.hold,
          enemy: FormationOrder.hold,
        ),
        1,
      );
    });
  });

  group('where a creature stands falls out of what it is', () {
    test('a commander that summons hangs back furthest', () {
      expect(
        defaultEnemyRank(
          strength: 40,
          castLevel: 6,
          specialCastLevel: 3,
          agility: 30,
        ),
        backRank,
      );
    });

    test('a caster keeps its distance', () {
      expect(
        defaultEnemyRank(
          strength: 5,
          castLevel: 4,
          specialCastLevel: 0,
          agility: 20,
        ),
        backRank,
      );
    });

    test('a brute leads', () {
      expect(
        defaultEnemyRank(
          strength: 8,
          castLevel: 0,
          specialCastLevel: 0,
          agility: 8,
        ),
        frontRank,
      );
    });

    test('something with no arms does not lead a line', () {
      expect(
        defaultEnemyRank(
          strength: 0,
          castLevel: 0,
          specialCastLevel: 0,
          agility: 0,
        ),
        greaterThan(frontRank),
      );
    });
  });

  group('the snapshot carries a rank', () {
    test('unset, it falls out of the slot — front, middle, back', () {
      expect(
        const CombatantSnapshot(slot: 0, name: 'a', hp: 1, maxHp: 1).rank,
        1,
      );
      expect(
        const CombatantSnapshot(slot: 2, name: 'a', hp: 1, maxHp: 1).rank,
        2,
      );
      expect(
        const CombatantSnapshot(slot: 5, name: 'a', hp: 1, maxHp: 1).rank,
        3,
      );
    });

    test('set, it wins', () {
      expect(
        const CombatantSnapshot(
          slot: 5,
          name: 'a',
          hp: 1,
          maxHp: 1,
          rank: 1,
        ).rank,
        1,
      );
    });

    test('it survives a JSON round trip', () {
      const c = CombatantSnapshot(slot: 1, name: 'a', hp: 1, maxHp: 1, rank: 3);
      expect(CombatantSnapshot.fromJson(c.toJson()).rank, 3);
    });
  });

  group('the battle holds one gap for both sides', () {
    test('it comes from the setup and stays on the board', () {
      expect(Battle(startingSetup()).gap, 0);
      expect(
        Battle(
          BattleSetup(
            party: [seumgal()],
            enemyKeys: const ['orc'],
            seed: 1,
            initialGap: 9,
          ),
        ).gap,
        maxGap,
      );
    });

    test('enemy ranks come from the encounter, else from the creature', () {
      final battle = Battle(
        BattleSetup(
          party: [seumgal()],
          enemyKeys: const ['orc', 'archi_mage'],
          enemyRanks: const [3],
          seed: 1,
        ),
      );
      expect(battle.enemies[0].rank, 3, reason: 'the encounter said so');
      expect(battle.enemies[1].rank, backRank, reason: 'a caster hangs back');
    });
  });

  group('reaching past a defender never voids the turn', () {
    test('a hopeless swing still resolves into something', () {
      // Back rank, maximum gap, enemy in its own back rank: as far out
      // of reach as this game can be. It must still produce events.
      final battle = Battle(
        BattleSetup(
          party: [
            const CombatantSnapshot(
              slot: 0,
              name: 'far',
              hp: 100,
              maxHp: 100,
              rank: 3,
              strength: 10,
              powOfWeapon: 10,
              levelPhysical: 1,
              accuracyPhysical: 19,
            ),
          ],
          enemyKeys: const ['orc', 'orc'],
          enemyRanks: const [1, 3],
          initialGap: 2,
          seed: 5,
        ),
      );
      final result = runBattle(
        battle,
        (d) => switch (d) {
          ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
          EnemyTargetDecision() => ChooseEnemyTarget(d.slot, 1),
          _ => null,
        },
      );
      expect(
        result.events.whereType<AttackStrained>(),
        isNotEmpty,
        reason: 'the distance has to be reported',
      );
      expect(
        result.events.any(
          (e) =>
              e is EnemyDamaged ||
              e is AttackMissed ||
              e is EnemyBlocked ||
              e is AttackIntercepted,
        ),
        isTrue,
        reason: 'and the swing has to land somewhere in the rules',
      );
    });
  });
  _targeting();
}

/// B5-04 — the enemy's target draw. This is the change that gives the
/// party a defensive decision it did not have at all.
void _targeting() {
  List<double> share(List<int> ranks, {int gap = 0, int reach = 2}) {
    final hits = List.filled(ranks.length, 0);
    final rng = SeededRng(99);
    const trials = 40000;
    for (var i = 0; i < trials; i++) {
      hits[pickByRank(
        candidateRanks: ranks,
        attackerRank: 1,
        gap: gap,
        reach: reach,
        rng: rng,
      )]++;
    }
    return [for (final h in hits) h / trials];
  }

  group('nearer is likelier', () {
    test('the front rank draws more than the back', () {
      final s = share([1, 2, 3]);
      expect(s[0], greaterThan(s[1]));
      expect(s[1], greaterThan(s[2]));
    });

    test('standing alone in front means taking most of it', () {
      // This is what makes a tank possible. Before B5-04 a shield only
      // ever protected the person holding it, because nothing made the
      // enemy swing at them.
      final s = share([1, 3, 3, 3, 3]);
      expect(s[0], greaterThan(0.35));
    });

    test('everyone in the back is not a hiding place', () {
      // Nobody is in front of anybody, so it collapses to uniform.
      final s = share([3, 3, 3, 3]);
      for (final v in s) {
        expect(v, closeTo(0.25, 0.02));
      }
    });

    test('the back rank is never safe', () {
      final s = share([1, 3]);
      expect(s[1], greaterThan(0.1));
    });
  });

  group('reach decides how steeply it falls off', () {
    test('a long weapon picks its target more freely', () {
      final short = share([1, 3], reach: 0);
      final long = share([1, 3], reach: 3);
      expect(
        long[1],
        greaterThan(short[1]),
        reason: 'reaching past the front line is what long weapons do',
      );
    });

    test('falloff never inverts', () {
      for (var reach = 0; reach <= 5; reach++) {
        expect(falloffForReach(reach), greaterThan(0));
      }
    });
  });

  group('the draw stays seeded and cheap', () {
    test('one number is drawn whatever the weights are', () {
      for (final ranks in [
        [1],
        [1, 2, 3],
        [3, 3, 3, 3, 3],
      ]) {
        final rng = SeededRng(4);
        pickByRank(
          candidateRanks: ranks,
          attackerRank: 1,
          gap: 0,
          reach: 2,
          rng: rng,
        );
        expect(rng.draws, 1, reason: '$ranks');
      }
    });

    test('it always returns a valid index', () {
      final rng = SeededRng(8);
      for (var i = 0; i < 500; i++) {
        final n = 1 + (i % 5);
        final ranks = [for (var k = 0; k < n; k++) 1 + (k % 3)];
        final pick = pickByRank(
          candidateRanks: ranks,
          attackerRank: 1,
          gap: i % 3,
          reach: i % 4,
          rng: rng,
        );
        expect(pick, inInclusiveRange(0, ranks.length - 1));
      }
    });
  });
}
