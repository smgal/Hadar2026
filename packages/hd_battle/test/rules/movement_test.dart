import 'package:hd_battle/hd_battle.dart';
import 'package:test/test.dart';

/// B5-03 — the three ways position changes on purpose.
void main() {
  group('formation orders are a phase, not a turn', () {
    test('they resolve before anyone acts', () {
      // Putting the leader's order in the initiative order would have
      // meant the leader had to be fastest, which would have undone
      // B2-05. Resolving it up front keeps both.
      final battle = Battle(
        BattleSetup(
          party: [
            const CombatantSnapshot(
              slot: 0,
              name: 'leader',
              hp: 100,
              maxHp: 100,
              rank: 1,
              accuracyPhysical: 10,
              strength: 10,
              powOfWeapon: 10,
              levelPhysical: 1,
            ),
          ],
          enemyKeys: const ['orc'],
          initialGap: 2,
          seed: 5,
        ),
      );
      final events = <BattleEvent>[];
      var guard = 0;
      while (!battle.isFinished && guard++ < 50) {
        final d = battle.pendingDecision;
        if (d == null) {
          events.addAll(battle.advance());
          if (events.whereType<FormationResolved>().isNotEmpty) break;
          continue;
        }
        battle.applyCommand(switch (d) {
          // B6-01: formation moves live under the leader's `orders`.
          ActionDecision() => ChooseAction(d.slot, BattleAction.orders),
          OrderDecision() => ChooseAction(
            d.slot,
            BattleAction.advanceFormation,
          ),
          EnemyTargetDecision() => ChooseEnemyTarget(d.slot, 0),
          _ => CancelChoice(d.slot),
        });
      }
      final resolved = events.whereType<FormationResolved>().single;
      expect(resolved.partyAdvanced, isTrue);
      expect(resolved.to, lessThan(resolved.from));
    });

    test('orders are added, so matching a move cancels it', () {
      expect(
        resolveFormation(
          gap: 1,
          party: FormationOrder.retreat,
          enemy: FormationOrder.advance,
        ),
        1,
      );
    });

    test('a standoff is reported as one, not silently', () {
      const e = FormationResolved(
        from: 1,
        to: 1,
        partyAdvanced: false,
        partyRetreated: true,
        enemyAdvanced: true,
        enemyRetreated: false,
      );
      expect(e.cancelled, isTrue);
    });

    test('what a side wants comes from whose weapon is longer', () {
      expect(
        formationWant(myReach: 1, theirReach: 3, gap: 2),
        FormationOrder.advance,
        reason: 'outreached, so close',
      );
      expect(
        formationWant(myReach: 3, theirReach: 1, gap: 0),
        FormationOrder.retreat,
        reason: 'the longer weapon wants room',
      );
      expect(
        formationWant(myReach: 2, theirReach: 2, gap: 0),
        FormationOrder.hold,
        reason: 'even, and already touching',
      );
    });
  });

  group('the menu never offers something that cannot be done', () {
    Battle battleWith({
      required int rank,
      required String weaponKey,
      required int gap,
    }) => Battle(
      BattleSetup(
        party: [
          CombatantSnapshot(
            slot: 0,
            name: 'a',
            hp: 100,
            maxHp: 100,
            rank: rank,
            weaponKey: weaponKey,
          ),
        ],
        enemyKeys: const ['orc'],
        initialGap: gap,
        seed: 1,
      ),
    );

    List<BattleAction> optionsOf(Battle b) {
      b.advance();
      return (b.pendingDecision! as ActionDecision).options;
    }

    test('a charge needs a weapon that charges and room to step into', () {
      expect(
        optionsOf(battleWith(rank: 2, weaponKey: 'lance', gap: 0)),
        contains(BattleAction.charge),
      );
      expect(
        optionsOf(battleWith(rank: 1, weaponKey: 'lance', gap: 0)),
        isNot(contains(BattleAction.charge)),
        reason: 'already at the front',
      );
      expect(
        optionsOf(battleWith(rank: 2, weaponKey: 'dagger', gap: 0)),
        isNot(contains(BattleAction.charge)),
        reason: 'a dagger does not charge',
      );
    });

    test('the formation cannot be pushed past the edges of the board', () {
      // B6-01: the moves are answers to `orders`, so open that first.
      List<BattleAction> ordersOf(Battle battle) {
        battle.advance();
        battle.applyCommand(const ChooseAction(0, BattleAction.orders));
        return (battle.pendingDecision! as OrderDecision).options;
      }

      expect(
        ordersOf(battleWith(rank: 1, weaponKey: 'dagger', gap: 0)),
        isNot(contains(BattleAction.advanceFormation)),
      );
      expect(
        ordersOf(battleWith(rank: 1, weaponKey: 'dagger', gap: maxGap)),
        isNot(contains(BattleAction.retreatFormation)),
      );
    });

    test('bracing is always available — holding is a thing you can do', () {
      expect(
        optionsOf(battleWith(rank: 1, weaponKey: 'dagger', gap: 0)),
        contains(BattleAction.brace),
      );
    });
  });

  group('bracing', () {
    test('the second blow in a round is much less well met', () {
      // A tank that cannot be worn down is not a decision either.
      expect(braceBonus(1), lessThan(braceBonus(0)));
      expect(braceBonus(0), greaterThan(0));
    });
  });
  _pushes();
}

/// B5-07 — the two pushes that are not knockback.
void _pushes() {
  Battle shieldFight({int shieldBlock = 60, bool dodges = false}) => Battle(
    BattleSetup(
      party: [
        CombatantSnapshot(
          slot: 0,
          name: 'wall',
          hp: 200,
          maxHp: 200,
          rank: 1,
          agility: 14,
          ac: 8,
          armour: ArmourPieces(body: 3, shieldBlock: shieldBlock),
          levelPhysical: 2,
          accuracyPhysical: 15,
          strength: 14,
          powOfWeapon: 20,
          weaponKey: 'long_sword',
          dodgesBack: dodges,
        ),
      ],
      enemyKeys: const ['giant'],
      enemyRanks: const [1],
      initialGap: 0,
      seed: 12,
    ),
  );

  List<BattleEvent> run(Battle battle, {int rounds = 40}) {
    final events = <BattleEvent>[];
    var guard = 0;
    while (!battle.isFinished && guard++ < rounds * 20) {
      final d = battle.pendingDecision;
      if (d == null) {
        events.addAll(battle.advance());
        continue;
      }
      battle.applyCommand(switch (d) {
        ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
        EnemyTargetDecision() => ChooseEnemyTarget(d.slot, 0),
        _ => CancelChoice(d.slot),
      });
    }
    return events;
  }

  group('a shield turns the attacker away, not its holder', () {
    test('blocking shoves the attacker back', () {
      final events = run(shieldFight());
      expect(events.whereType<AttackerShovedBack>(), isNotEmpty);
    });

    test('the blocker keeps its rank — otherwise bracing would be undone', () {
      final battle = shieldFight();
      run(battle);
      // Nothing in this fight moves the party member forward or back;
      // if a block pushed the blocker, this would have drifted.
      expect(battle.party.single.rank, 1);
    });
  });

  group('giving ground rather than being finished', () {
    test('it needs somewhere to go, which is what caps it', () {
      // From the back rank there is nowhere to fall into, so the
      // passive simply stops working. No counter needed.
      expect(canRetreat(backRank), isFalse);
    });

    test('only the person moves, never the formation', () {
      final battle = shieldFight(shieldBlock: 0, dodges: true);
      final before = battle.gap;
      run(battle);
      expect(
        battle.gap,
        before,
        reason: 'one evasion roll must not reposition the party',
      );
    });

    test('someone without the passive does not get it', () {
      final events = run(shieldFight(shieldBlock: 0));
      expect(events.whereType<DodgedBack>(), isEmpty);
    });
  });
}
