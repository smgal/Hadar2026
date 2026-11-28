import 'package:lore_battle/lore_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

Battle zeroBattle(BattleSetup setup) =>
    Battle(setup, rng: ScriptedRng(const [0], repeat: true));

CombatantView seat(Battle battle, int slot) =>
    battle.party.firstWhere((c) => c.slot == slot);

/// Everyone braces — a round in which only the enemy does anything.
BattleCommand? holdStill(BattleDecision d) => d is ActionDecision
    ? ChooseAction(d.slot, BattleAction.brace)
    : alwaysAttack(d);

/// Plays whole battles over [seeds] until [wanted] shows up in the
/// events, and returns that battle's result. The rolls behind a boss's
/// abilities are too many to script; a seed search is still exact about
/// what happened once it finds one.
({Battle battle, List<BattleEvent> events, BattleOutcome outcome})?
firstBattleWith(
  BattleSetup Function(int seed) build,
  bool Function(BattleEvent event) wanted, {
  int seeds = 80,
  BattleCommand? Function(BattleDecision) answer = alwaysAttack,
}) {
  for (var seed = 1; seed <= seeds; seed++) {
    final battle = Battle(build(seed));
    final result = runBattle(battle, answer, stepLimit: 20000);
    if (result.events.any(wanted)) {
      return (battle: battle, events: result.events, outcome: result.outcome);
    }
  }
  return null;
}

void main() {
  group('poison', () {
    test('an enemy loses 50 at the start of its turn', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['zombie'],
          enemyOverrides: const {0: EnemyOverride(poison: 1)},
        ),
      );
      final events = playOneRound(battle, holdStill);
      final tick = events.whereType<EnemyPoisonTick>().single;
      expect(tick.amount, 50);
      expect(battle.enemies.single.hp, 2400 - 50);
    });

    test('it drops at zero, and the battle is won with it unconscious', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['orc_villager'],
          enemyOverrides: const {0: EnemyOverride(poison: 1)},
        ),
      );
      final result = runBattle(battle, holdStill);
      expect(result.events.whereType<EnemyCollapsedFromPoison>(), hasLength(1));
      expect(result.outcome.resultCode, BattleResultCode.win);
      // Nobody knocked it out, so nobody is paid experience - but an
      // enemy that is down pays its gold.
      expect(result.events.whereType<ExperienceGained>(), isEmpty);
      expect(result.outcome.goldGained, 1);
    });

    test('an unconscious enemy that is poisoned dies of it', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['orc_villager', 'zombie'],
          enemyOverrides: const {
            0: EnemyOverride(poison: 1, hp: 0, unconscious: 1),
          },
        ),
      );
      final events = playOneRound(battle, holdStill);
      expect(events.whereType<EnemyDiedFromPoison>().single.enemyIndex, 0);
      expect(battle.enemies[0].dead, 1);
    });

    test('Part 1\'s enemies lose 1', () {
      final battle = zeroBattle(
        setupFor(
          episode: 1,
          party: [knight()],
          enemyKeys: const ['ogre'],
          enemyOverrides: const {0: EnemyOverride(poison: 1)},
        ),
      );
      final events = playOneRound(battle, holdStill);
      expect(events.whereType<EnemyPoisonTick>().single.amount, 1);
    });

    test('a member loses their poison counter once a round, at the end', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight(poison: 3)],
          enemyKeys: const ['orc_villager'],
          enemyOverrides: const {0: EnemyOverride(strength: 0, hp: 99999)},
        ),
      );
      final events = playOneRound(battle, holdStill);
      final tick = events.whereType<MemberPoisonTick>().single;
      expect([tick.slot, tick.amount], [0, 3]);
      expect(seat(battle, 0).hp, 750 - 3);
      // It comes after everyone has moved: the last thing before the
      // next round opens.
      final tickAt = events.indexOf(tick);
      expect(events[tickAt + 1], isA<RoundStarted>());
    });

    test('poison on an unconscious member piles onto the counter', () {
      final battle = zeroBattle(
        setupFor(
          party: [
            knight(),
            knight(slot: 1, name: 'Down', hp: 0, unconscious: 70, poison: 4),
          ],
          enemyKeys: const ['orc_villager'],
          enemyOverrides: const {0: EnemyOverride(strength: 0, hp: 99999)},
        ),
      );
      playOneRound(battle, holdStill);
      expect(seat(battle, 1).unconscious, 74);
      final events = playOneRound(battle, holdStill);
      // endurance 15 x level 5 = 75: the second tick passes it.
      expect(events.whereType<MemberDiedFromPoison>().single.slot, 1);
      expect(seat(battle, 1).dead, 1);
    });
  });

  group('an enemy\'s weapon and spells', () {
    test(
      'a blow: strength x level x (1..10) / 5, less the member\'s armour',
      () {
        final battle = zeroBattle(
          setupFor(
            party: [knight(shieldPower: 0)],
            enemyKeys: const ['zombie'],
          ),
        );
        final events = playOneRound(battle, holdStill);
        // Zombie: 13 x 8 x 1 / 5 = 20, less armour 4 x 5 x 1 / 10 = 2.
        // The knight braced without a shield: a roll of zero is a guard.
        expect(
          events.whereType<MemberBlocked>().single.kind,
          BlockKind.resisted,
        );

        final plain = zeroBattle(
          setupFor(
            party: [knight(shieldPower: 0), knight(slot: 1, shieldPower: 0)],
            enemyKeys: const ['zombie'],
          ),
        );
        // Nobody braces: the leader attacks, the blow lands on the first.
        final struck = playOneRound(plain, alwaysAttack);
        final hit = struck.whereType<MemberDamaged>().single;
        expect(hit.amount, 20 - 2);
        expect(hit.source, DamageSource.physical);
      },
    );

    test('a shield stops the blow whole and shoves the attacker back', () {
      final battle = zeroBattle(
        setupFor(party: [knight()], enemyKeys: const ['zombie']),
      );
      final events = playOneRound(battle, alwaysAttack);
      expect(events.whereType<ShieldBlocked>().single.slot, 0);
      expect(events.whereType<MemberDamaged>(), isEmpty);
      expect(events.whereType<AttackerShovedBack>(), hasLength(1));
      expect(battle.enemies.single.rank, 2);
    });

    test('a mage has no shield to roll for', () {
      final battle = zeroBattle(
        setupFor(party: [mage(slot: 0, rank: 1)], enemyKeys: const ['zombie']),
      );
      final events = playOneRound(battle, alwaysAttack);
      expect(events.whereType<ShieldBlocked>(), isEmpty);
      // 20, and a mage's armour is 0.
      expect(events.whereType<MemberDamaged>().single.amount, 20);
    });

    test('the spell it casts follows its mentality', () {
      final found = firstBattleWith(
        (seed) => setupFor(
          party: [knight(), knight(slot: 1), knight(slot: 2)],
          enemyKeys: const ['kobold_wizard'],
          seed: seed,
        ),
        (e) => e is EnemyCastSpell,
      );
      expect(found, isNotNull);
      // Mentality 20: 번개 on one, 혹한기 on all.
      for (final cast in found!.events.whereType<EnemyCastSpell>()) {
        expect(
          cast.spell,
          cast.slot < 0 ? EnemySpellKind.coldSnap : EnemySpellKind.lightning,
        );
      }
    });

    test('a member\'s resistance stops a spell on rand(50)', () {
      // Rolls of zero: the spell does not miss, and 0 < resistance 10.
      final battle = zeroBattle(
        setupFor(party: [knight()], enemyKeys: const ['lore_mage']),
      );
      final events = playOneRound(battle, holdStill);
      expect(events.whereType<EnemyCastSpell>(), hasLength(1));
      final blocked = events.whereType<MemberBlocked>().single;
      expect(blocked.source, DamageSource.spell);
      expect(blocked.kind, BlockKind.resisted);
    });

    test('an enemy with no strength and no magic does nothing', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['dark_healer', 'zombie'],
          enemyOverrides: const {1: EnemyOverride(strength: 0)},
        ),
      );
      final events = playOneRound(battle, holdStill);
      expect(events.whereType<MemberDamaged>(), isEmpty);
      expect(events.whereType<EnemyAttackMissed>(), isEmpty);
    });
  });

  group('special attacks', () {
    test('never from fewer than four enemies', () {
      for (var seed = 1; seed <= 20; seed++) {
        final battle = Battle(
          setupFor(
            enemyKeys: const ['troll_hunter', 'troll_hunter', 'troll_hunter'],
            seed: seed,
          ),
        );
        final result = runBattle(battle, alwaysAttack);
        expect(result.events.whereType<EnemyAbilityUsed>(), isEmpty);
      }
    });

    test('with four they come, and luck or the roll decides', () {
      final found = firstBattleWith(
        (seed) => setupFor(
          party: [
            for (var i = 0; i < 5; i++)
              knight(
                slot: i,
                name: 'k$i',
                strength: 2,
                weaponPower: 5,
                luck: 0,
              ),
          ],
          enemyKeys: const [
            'troll_hunter',
            'troll_hunter',
            'troll_hunter',
            'troll_hunter',
            'troll_hunter',
          ],
          seed: seed,
        ),
        (e) => e is MemberAfflicted && !e.mass,
      );
      expect(found, isNotNull);
      final landed = found!.events.whereType<MemberAfflicted>().first;
      expect(landed.ability, EnemySpecial.knockOut);
      expect(found.events.whereType<EnemyAbilityUsed>(), isNotEmpty);
    });
  });

  group('Part 3\'s supernatural abilities', () {
    test('전체 회복 wakes the fallen one stage at a time', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['dark_healer', 'orc_soldier', 'orc_soldier'],
          enemyOverrides: const {
            1: EnemyOverride(hp: 0, unconscious: 1),
            2: EnemyOverride(hp: 0, unconscious: 1, dead: 1),
          },
        ),
      );
      final events = playOneRound(battle, holdStill);
      final revived = events.whereType<EnemyRevivedAlly>().toList();
      expect(
        {for (final e in revived) e.targetIndex: e.fromDeath},
        {1: false, 2: true},
      );
      // Unconscious -> awake with at least one hit point.
      expect(battle.enemies[1].unconscious, 0);
      expect(battle.enemies[1].hp, 1);
      // Dead -> unconscious, no further.
      expect(battle.enemies[2].dead, 0);
      expect(battle.enemies[2].unconscious, 1);
    });

    test('동료 소환 calls one of its own list in', () {
      final battle = zeroBattle(
        setupFor(party: [knight()], enemyKeys: const ['troll_necromancer']),
      );
      final events = playOneRound(battle, holdStill);
      final called = events.whereType<EnemySummoned>().single;
      expect(called.callerIndex, 0);
      expect(battle.enemies, hasLength(2));
      final newcomer = battle.enemies[called.enemyIndex];
      expect(newcomer.summoned, isTrue);
      // 트롤강령술사 calls rows 1..5; a roll of zero is the first.
      expect(newcomer.key, 'death_messenger');
    });

    test('the enemy list never grows past eight', () {
      for (var seed = 1; seed <= 15; seed++) {
        final battle = Battle(
          setupFor(
            party: [knight(strength: 1, weaponPower: 5)],
            enemyKeys: const ['troll_necromancer', 'summoner_shaman'],
            seed: seed,
          ),
        );
        runBattle(battle, holdStill, stepLimit: 20000);
        expect(battle.enemies.length, lessThanOrEqualTo(maxEnemies));
      }
    });

    test('분신 fills the list to eight and hides the real one', () {
      final battle = Battle(
        setupFor(party: [knight()], enemyKeys: const ['orc_revenant'], seed: 5),
      );
      final events = playOneRound(battle, holdStill);
      expect(battle.enemies, hasLength(8));
      expect(battle.enemies.where((e) => e.isClone), hasLength(7));
      expect(battle.enemies.where((e) => e.acts), hasLength(1));
      final shifted = events.whereType<EnemyClonesShifted>().first;
      expect(shifted.indices, [0, 1, 2, 3, 4, 5, 6, 7]);
      for (final e in battle.enemies) {
        expect(e.nameKey, 'orc_revenant');
        expect(e.showsAsClone, isTrue);
        if (e.isClone) {
          expect(e.hp, 1);
          expect(e.paysGold, isFalse);
          expect(e.paysExperience, isFalse);
        }
      }
    });

    test('the real one moves among its images', () {
      final battle = Battle(
        setupFor(party: [knight()], enemyKeys: const ['orc_revenant'], seed: 5),
      );
      final places = <int>{};
      for (var round = 0; round < 12 && !battle.isFinished; round++) {
        playOneRound(battle, holdStill);
        places.add(battle.enemies.indexWhere((e) => e.acts));
      }
      expect(places.length, greaterThan(1));
    });

    test('an image that falls stands again, and images alone are no fight', () {
      final battle = Battle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['orc_revenant'],
          // The real one is down from the start; only its turn would
          // make images, and it has none.
          enemyOverrides: const {0: EnemyOverride(hp: 0, unconscious: 1)},
        ),
      );
      final result = runBattle(battle, alwaysAttack);
      expect(result.outcome.resultCode, BattleResultCode.win);
    });

    test('정신 지배 takes the assistant, and the seat is reported empty', () {
      final found = firstBattleWith(
        (seed) => setupFor(
          party: [knight(), assistant()],
          enemyKeys: const ['kobold_king'],
          seed: seed,
        ),
        (e) => e is MemberAbducted,
      );
      expect(found, isNotNull, reason: 'no seed produced a mind control');
      final taken = found!.events.whereType<MemberAbducted>().first;
      expect(taken.slot, assistantSeat);
      final turned = found.battle.enemies[taken.newEnemyIndex];
      expect(turned.wasAssistant, isTrue);
      expect(turned.displayName, 'Helper');
      expect(turned.paysGold, isFalse);
      expect(found.outcome.departedSlots, [assistantSeat]);
      expect(
        found.outcome.combatants.any((c) => c.slot == assistantSeat),
        isFalse,
      );
      expect(found.outcome.newAssistant, isNull);
    });

    test('a crystal creature cannot be taken', () {
      for (var seed = 1; seed <= 40; seed++) {
        final battle = Battle(
          setupFor(
            party: [knight(), assistant(immune: true)],
            enemyKeys: const ['kobold_king'],
            seed: seed,
          ),
        );
        final result = runBattle(battle, alwaysAttack, stepLimit: 20000);
        expect(result.events.whereType<MemberAbducted>(), isEmpty);
        expect(result.outcome.departedSlots, isEmpty);
      }
    });

    test('갑옷 파괴 lowers armour for good and the outcome says by how much', () {
      final found = firstBattleWith(
        (seed) => setupFor(
          party: [
            knight(ac: 9, luck: 0),
            knight(slot: 1, name: 'Second', ac: 9, luck: 0),
          ],
          enemyKeys: const ['archdraconian'],
          seed: seed,
        ),
        (e) => e is ArmourBreakAttempted && e.broken,
      );
      expect(found, isNotNull, reason: 'no seed produced an armour break');
      final broken = found!.events
          .whereType<ArmourBreakAttempted>()
          .where((e) => e.broken)
          .toList();
      for (final result in found.outcome.combatants) {
        final count = broken.where((e) => e.slot == result.slot).length;
        expect(result.acLoss, count, reason: 'slot ${result.slot}');
      }
      expect(
        found.outcome.combatants.fold(0, (a, c) => a + c.acLoss),
        greaterThan(0),
      );
    });

    test('luck saves a member\'s armour', () {
      // luck 21 always beats rand(21).
      for (var seed = 1; seed <= 30; seed++) {
        final battle = Battle(
          setupFor(
            party: [knight(ac: 9, luck: 21)],
            enemyKeys: const ['archdraconian'],
            seed: seed,
          ),
        );
        final result = runBattle(battle, alwaysAttack, stepLimit: 20000);
        expect(result.outcome.combatants.single.acLoss, 0);
      }
    });

    test('전체 중독 only comes against a full party', () {
      final found = firstBattleWith(
        (seed) => setupFor(
          party: [
            for (final m in partyOfFive())
              // Too weak to end it quickly, too unlucky to shrug it off.
              CombatantSnapshot(
                slot: m.slot,
                name: m.name,
                level: 5,
                endurance: 20,
                hp: 1000,
                maxHp: 1000,
              ),
            assistant(),
          ],
          enemyKeys: const ['wraith'],
          seed: seed,
        ),
        (e) => e is MemberAfflicted && e.mass,
        answer: holdStill,
      );
      expect(found, isNotNull);
      final caught = found!.events.whereType<MemberAfflicted>().first;
      expect(caught.ability, EnemySpecial.poison);
      expect(caught.mass, isTrue);

      // Two members: it never fires.
      for (var seed = 1; seed <= 20; seed++) {
        final battle = Battle(
          setupFor(
            party: [knight(), knight(slot: 1)],
            enemyKeys: const ['wraith'],
            seed: seed,
          ),
        );
        final result = runBattle(battle, alwaysAttack, stepLimit: 20000);
        expect(
          result.events.whereType<MemberAfflicted>().where((e) => e.mass),
          isEmpty,
        );
      }
    });
  });

  group('Parts 1 and 2: the supernatural grade', () {
    test('a graded enemy calls a row 17 to 20 below its own', () {
      final found = firstBattleWith(
        (seed) => setupFor(
          episode: 1,
          party: [knight(strength: 1, weaponPower: 5)],
          enemyKeys: const ['draconian'],
          seed: seed,
        ),
        (e) => e is EnemySummoned,
        answer: holdStill,
      );
      expect(found, isNotNull);
      for (final called in found!.events.whereType<EnemySummoned>()) {
        final id = found.battle.enemies[called.enemyIndex].data.legacyId;
        // Draconian is row 62.
        expect(id, inInclusiveRange(42, 45));
      }
    });

    test('Part 2\'s last guardian calls 51..54', () {
      final found = firstBattleWith(
        (seed) => setupFor(
          episode: 2,
          party: [knight(strength: 1, weaponPower: 5)],
          enemyKeys: const ['last_guardian'],
          seed: seed,
        ),
        (e) => e is EnemySummoned,
        answer: holdStill,
      );
      expect(found, isNotNull);
      for (final called in found!.events.whereType<EnemySummoned>()) {
        final key = found.battle.enemies[called.enemyIndex].key;
        expect(key, isIn(['euryale', 'medusa', 'minotaur', 'dragon']));
      }
    });
  });

  group('position still does its work on top', () {
    test('a blow out of reach is strained, not lost', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight(rank: 3)],
          // No resistance, so a roll of zero cannot stop the blow.
          enemyKeys: const ['orc_villager'],
          enemyRanks: const [3],
          initialGap: 2,
        ),
      );
      final events = playOneRound(battle, alwaysAttack);
      expect(events.whereType<AttackStrained>(), hasLength(1));
      expect(events.whereType<EnemyDamaged>(), hasLength(1));
    });

    test('the leader can move the formation and loses the swing', () {
      final battle = Battle(
        setupFor(
          party: [knight(), knight(slot: 1)],
          enemyKeys: const ['zombie'],
          initialGap: 2,
        ),
      )..advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.orders));
      final orders = battle.pendingDecision! as OrderDecision;
      expect(orders.options, contains(BattleAction.advanceFormation));
      expect(orders.options, isNot(contains(BattleAction.retreatFormation)));
      battle.applyCommand(const ChooseAction(0, BattleAction.advanceFormation));
      battle.applyCommand(const ChooseAction(1, BattleAction.brace));
      final events = <BattleEvent>[];
      while (battle.pendingDecision == null && !battle.isFinished) {
        events.addAll(battle.advance());
      }
      final moved = events.whereType<FormationResolved>().single;
      expect(moved.partyAdvanced, isTrue);
      expect(moved.to, lessThan(moved.from));
      expect(
        events.whereType<AttackDeclared>().where((e) => e.slot == 0),
        isEmpty,
      );
    });

    test('auto-battle: fighters swing, a mage throws its first spell', () {
      final battle = Battle(
        setupFor(
          party: [knight(), mage()],
          enemyKeys: const ['zombie'],
          seed: 2,
        ),
      )..advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.orders));
      battle.applyCommand(const ChooseAction(0, BattleAction.autoBattle));
      // Nobody else is asked this round.
      expect(battle.pendingDecision, isNull);
      final events = <BattleEvent>[];
      while (battle.pendingDecision == null && !battle.isFinished) {
        events.addAll(battle.advance());
      }
      expect(
        events.whereType<AttackDeclared>().where((e) => e.slot == 0),
        hasLength(1),
      );
      final cast = events.whereType<SpellCast>().single;
      expect([cast.slot, cast.magicId], [1, 101]);
      // It lasts one round: the next one asks again.
      expect(battle.pendingDecision, isA<ActionDecision>());
    });

    test('cancelling a sub-question returns to the menu; cancelling the '
        'menu gives the turn up', () {
      final battle = Battle(
        setupFor(
          party: [knight(), knight(slot: 1)],
          enemyKeys: const ['zombie', 'zombie'],
        ),
      )..advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.attack));
      expect(battle.pendingDecision, isA<EnemyTargetDecision>());
      expect(battle.applyCommand(const CancelChoice(0)), isEmpty);
      expect(battle.pendingDecision, isA<ActionDecision>());
      expect(battle.pendingDecision!.slot, 0);
      final skipped = battle.applyCommand(const CancelChoice(0));
      expect(skipped.single, isA<ActionSkipped>());
      expect(battle.pendingDecision!.slot, 1);
    });

    test('one candidate is not asked about', () {
      final battle = Battle(
        setupFor(party: [knight()], enemyKeys: const ['zombie']),
      )..advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.attack));
      // One enemy: straight to resolution.
      expect(battle.pendingDecision, isNull);
    });

    test('the leader is asked first, then front to back', () {
      final battle = Battle(
        setupFor(
          party: [
            knight(slot: 0, rank: 3),
            knight(slot: 1, rank: 2),
            knight(slot: 2, rank: 1),
            knight(slot: 3, rank: 1),
          ],
          enemyKeys: const ['zombie'],
        ),
      )..advance();
      final asked = <int>[];
      while (battle.pendingDecision != null) {
        final d = battle.pendingDecision!;
        asked.add(d.slot);
        battle.applyCommand(ChooseAction(d.slot, BattleAction.brace));
      }
      expect(asked, [0, 2, 3, 1]);
    });
  });
}
