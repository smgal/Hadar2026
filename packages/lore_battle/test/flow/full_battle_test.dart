import 'package:lore_battle/lore_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

void main() {
  test('the live battle view isolates mutable setup collections', () {
    final skills = [50, 10, 10, 0, 30, 0];
    final supplies = {'hp_potion': 2};
    final battle = Battle(
      BattleSetup(
        party: [knight(skills: skills)],
        enemyKeys: const ['orc_soldier'],
        seed: 1,
        consumables: supplies,
      ),
    );
    final view = battle.view;
    skills[0] = 1;
    supplies.clear();

    expect(view, isNot(isA<Battle>()));
    expect(view.party.single.snapshot.skills.first, 50);
    expect(battle.consumables['hp_potion'], 2);
    expect(view.party.clear, throwsUnsupportedError);
    expect(view.enemies.clear, throwsUnsupportedError);
    expect(view.party.single.snapshot.skills.clear, throwsUnsupportedError);
    expect(view.enemies.single.abilities.clear, throwsUnsupportedError);
  });

  test('the cached outcome keeps its combatant results read-only', () {
    final battle = Battle(setupFor(party: [knight()], enemyKeys: const []));
    battle.advance();

    final outcome = battle.outcome!;
    expect(outcome.combatants.clear, throwsUnsupportedError);
    expect(battle.outcome!.combatants.single.slot, 0);
  });

  group('a whole battle', () {
    test('five against four orc soldiers is won and pays out', () {
      final battle = Battle(
        setupFor(
          enemyKeys: const [
            'orc_soldier',
            'orc_soldier',
            'orc_soldier',
            'orc_soldier',
          ],
        ),
      );
      final result = runBattle(battle, alwaysAttack);

      expect(result.outcome.resultCode, BattleResultCode.win);
      expect(result.events.first, isA<EnemiesAppeared>());
      expect(result.events.last, isA<BattleEnded>());
      // Every seat that started is reported.
      expect(
        [for (final c in result.outcome.combatants) c.slot],
        [0, 1, 2, 3, 4],
      );
      // Orc soldier: level 3, armour 2 -> 27 x 2 = 54 gold each (ch.12.2).
      expect(result.outcome.goldGained, 54 * 4);
      // 27 experience per knock-out, to whoever did it.
      final paid = result.outcome.combatants.fold(
        0,
        (a, c) => a + c.experienceGained,
      );
      expect(paid, greaterThanOrEqualTo(27 * 4));
      expect(paid % 27, 0);
    });

    test('same setup, same commands, same seed: same outcome', () {
      Map<String, dynamic> play(int seed) {
        final battle = Battle(
          setupFor(
            seed: seed,
            enemyKeys: const [
              'troll_hunter',
              'orc_magic_user',
              'kobold_wizard',
            ],
          ),
        );
        return runBattle(battle, alwaysAttack).outcome.toJson();
      }

      expect(play(7), play(7));
      expect(play(7), isNot(play(8)));
    });

    test('the event stream is reproducible too', () {
      List<String> play() {
        final battle = Battle(
          setupFor(seed: 21, enemyKeys: const ['kobold_king']),
        );
        return [
          for (final e in runBattle(battle, alwaysAttack).events)
            e.runtimeType.toString(),
        ];
      }

      expect(play(), play());
    });

    test('a party that cannot win loses with wire value 2', () {
      final battle = Battle(
        setupFor(
          party: [knight(level: 1)],
          enemyKeys: const ['draconian_king'],
          seed: 3,
        ),
      );
      final result = runBattle(battle, alwaysAttack);
      expect(result.outcome.resultCode, BattleResultCode.lose);
      expect(result.outcome.resultCode.wire, 2);
      expect(result.outcome.goldGained, 0);
    });

    test('result wire values are evade 0, win 1, lose 2', () {
      expect(BattleResultCode.evade.wire, 0);
      expect(BattleResultCode.win.wire, 1);
      expect(BattleResultCode.lose.wire, 2);
    });

    test('an unknown enemy key is refused when the battle is built', () {
      expect(
        () => Battle(setupFor(enemyKeys: const ['no_such_thing'])),
        throwsArgumentError,
      );
      // A Part 3 key is not a Part 1 key.
      expect(
        () => Battle(setupFor(enemyKeys: const ['orc_soldier'], episode: 1)),
        throwsArgumentError,
      );
      expect(() => Battle(setupFor(episode: 4)), throwsArgumentError);
    });
  });

  group('the battle flags', () {
    test('canEscape false takes the escape line off the menu', () {
      final battle = Battle(setupFor(canEscape: false))..advance();
      final decision = battle.pendingDecision! as ActionDecision;
      expect(decision.options, isNot(contains(BattleAction.escape)));
      expect(decision.options, contains(BattleAction.orders));
    });

    test('canEscape true offers it to the leader and nobody else', () {
      final battle = Battle(setupFor())..advance();
      final leader = battle.pendingDecision! as ActionDecision;
      expect(leader.slot, 0);
      expect(leader.options, contains(BattleAction.escape));
      battle.applyCommand(const ChooseAction(0, BattleAction.brace));
      final next = battle.pendingDecision! as ActionDecision;
      expect(next.options, isNot(contains(BattleAction.escape)));
      expect(next.options, isNot(contains(BattleAction.orders)));
    });

    test('a successful escape ends the battle with wire value 0', () {
      // Agility 49 cannot fail rand(50) > agility.
      final runner = CombatantSnapshot(
        slot: 0,
        name: 'Runner',
        agility: 49,
        hp: 100,
        maxHp: 100,
        level: 1,
        endurance: 10,
      );
      final battle = Battle(setupFor(party: [runner]));
      final result = runBattle(
        battle,
        (d) => d is ActionDecision
            ? ChooseAction(d.slot, BattleAction.escape)
            : alwaysAttack(d),
      );
      expect(result.outcome.resultCode, BattleResultCode.evade);
      expect(result.outcome.resultCode.wire, 0);
      expect(result.events.whereType<EscapeSucceeded>(), hasLength(1));
      expect(result.outcome.goldGained, 0);
    });

    test('enemyActsFirst: the first round has no party phase', () {
      final battle = Battle(setupFor(enemyActsFirst: true));
      final opening = battle.advance();
      final started = opening.whereType<RoundStarted>().single;
      expect(started.round, 1);
      expect(started.enemyActsFirst, isTrue);
      // Nothing is asked: the round resolves with enemies only.
      expect(battle.pendingDecision, isNull);

      final events = <BattleEvent>[];
      while (battle.pendingDecision == null && !battle.isFinished) {
        events.addAll(battle.advance());
      }
      expect(events.whereType<AttackDeclared>(), isEmpty);
      // Then round 2 asks the leader as usual.
      expect(battle.round, 2);
      expect(battle.pendingDecision, isA<ActionDecision>());
      expect(battle.gap, 0, reason: 'an ambush opens at gap 0');
    });

    test('attackUnconscious on: striking a fallen enemy finishes it and '
        'pays everyone standing', () {
      final battle = Battle(
        setupFor(
          party: [
            knight(),
            knight(slot: 1, name: 'Second'),
          ],
          enemyKeys: const ['orc_soldier'],
          enemyOverrides: const {0: EnemyOverride(hp: 0, unconscious: 1)},
          // One standing enemy is needed or the battle is already won.
        ).copyWithEnemies(const ['orc_soldier', 'orc_villager']),
      );
      battle.advance();
      final target = battle.pendingDecision;
      expect(target, isA<ActionDecision>());
      battle.applyCommand(const ChooseAction(0, BattleAction.attack));
      final ask = battle.pendingDecision! as EnemyTargetDecision;
      // The standing one first, the fallen one after it.
      expect(ask.enemyIndices, [1, 0]);
      battle.applyCommand(const ChooseEnemyTarget(0, 0));
      battle.applyCommand(const ChooseAction(1, BattleAction.brace));

      final events = <BattleEvent>[];
      while (battle.pendingDecision == null && !battle.isFinished) {
        events.addAll(battle.advance());
      }
      final finished = events.whereType<EnemyFinished>().single;
      expect(finished.enemyIndex, 0);
      expect(finished.flavour, inInclusiveRange(0, 3));
      expect(battle.enemies[0].dead, 1);
      // Level 3 -> 27 to each of the two standing members.
      final paid = events.whereType<ExperienceGained>().toList();
      expect(paid.map((e) => e.slot).toSet(), {0, 1});
      expect(paid.every((e) => e.amount == 27), isTrue);
    });

    test('attackUnconscious off: the fallen are not offered and blows '
        'pass over them', () {
      final battle = Battle(
        setupFor(
          party: [knight()],
          attackUnconscious: false,
          enemyOverrides: const {0: EnemyOverride(hp: 0, unconscious: 1)},
        ).copyWithEnemies(const ['orc_soldier', 'orc_villager']),
      );
      final result = runBattle(battle, alwaysAttack);
      expect(result.events.whereType<EnemyFinished>(), isEmpty);
      expect(result.outcome.resultCode, BattleResultCode.win);
      expect(battle.enemies[0].dead, 0);
      expect(battle.enemies[0].unconscious, 1);
    });
  });

  group('the assistant member', () {
    test('is never asked for a command', () {
      final battle = Battle(setupFor(party: [knight(), mage(), assistant()]));
      final asked = <int>{};
      runBattle(battle, (d) {
        asked.add(d.slot);
        return alwaysAttack(d);
      });
      expect(asked, isNot(contains(assistantSeat)));
      expect(asked, containsAll([0, 1]));
    });

    test('attacks on its own', () {
      final battle = Battle(
        setupFor(party: [knight(), assistant()], enemyKeys: const ['zombie']),
      );
      final result = runBattle(battle, alwaysAttack);
      expect(
        result.events.whereType<AttackDeclared>().where(
          (e) => e.slot == assistantSeat,
        ),
        isNotEmpty,
      );
    });

    test('a sweeping assistant declares against every enemy each round', () {
      final battle = Battle(
        setupFor(
          party: [knight(), assistant(attacksAll: true)],
          enemyKeys: const ['zombie', 'zombie', 'zombie'],
        ),
      );
      final events = playOneRound(
        battle,
        (d) => d is ActionDecision
            ? ChooseAction(d.slot, BattleAction.brace)
            : alwaysAttack(d),
      );
      final swept = events
          .whereType<AttackDeclared>()
          .where((e) => e.slot == assistantSeat)
          .map((e) => e.enemyIndex)
          .toList();
      expect(swept, [0, 1, 2]);
    });

    test('keeps the party alive when it is the only one standing', () {
      final battle = Battle(
        setupFor(
          party: [knight(hp: 0, unconscious: 1), assistant()],
          enemyKeys: const ['orc_villager'],
        ),
      );
      final result = runBattle(battle, alwaysAttack);
      // Nobody could be asked, and the assistant won it alone.
      expect(result.outcome.resultCode, BattleResultCode.win);
    });
  });
}

extension on BattleSetup {
  /// The same setup against other enemies — the overrides stay keyed by
  /// index.
  BattleSetup copyWithEnemies(List<String> keys) => BattleSetup(
    party: party,
    enemyKeys: keys,
    seed: seed,
    episode: episode,
    consumables: consumables,
    arrows: arrows,
    initialGap: initialGap,
    enemyRanks: enemyRanks,
    enemyOverrides: enemyOverrides,
    canEscape: canEscape,
    enemyActsFirst: enemyActsFirst,
    attackUnconscious: attackUnconscious,
  );
}
