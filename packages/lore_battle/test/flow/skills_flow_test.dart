import 'package:lore_battle/lore_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

/// A battle where every roll is zero: every blow lands at full strength,
/// nothing with a resistance of zero resists, and the higher agility
/// moves first. Lets a flow test state the exact number.
Battle zeroBattle(BattleSetup setup) =>
    Battle(setup, rng: ScriptedRng(const [0], repeat: true));

Combatant seat(Battle battle, int slot) =>
    battle.party.firstWhere((c) => c.slot == slot);

void main() {
  group('weapon blows, end to end', () {
    test('the document\'s steps, then the affinity layer on top', () {
      final battle = zeroBattle(
        setupFor(party: [knight()], enemyKeys: const ['orc_villager']),
      );
      final events = playOneRound(battle, alwaysAttack);
      final hit = events.whereType<EnemyDamaged>().single;
      // 16 x 40 x 50 / 10 = 3200, no deviation, less armour 1 x 1 x 1,
      // doubled because flesh is weak to an edge.
      expect(hit.amount, (3200 - 1) * 2);
      expect(hit.source, DamageSource.physical);
      expect(events.whereType<AttackDeclared>().single.enemyIndex, 0);
      expect(events.whereType<EnemyCollapsed>(), hasLength(1));
      // Level 1: one point of experience to the one who did it.
      final paid = events.whereType<ExperienceGained>().single;
      expect([paid.slot, paid.amount], [0, 1]);
      expect(battle.outcome!.resultCode, BattleResultCode.win);
      expect(battle.outcome!.goldGained, 1);
    });

    test('a monk hits with strength x skill x 5', () {
      final battle = zeroBattle(
        setupFor(party: [monk(slot: 0)], enemyKeys: const ['orc_villager']),
      );
      final events = playOneRound(battle, alwaysAttack);
      // 17 x 60 x 5 = 5100, less 1, halved: muscle absorbs a fist.
      expect(events.whereType<EnemyDamaged>().single.amount, (5100 - 1) ~/ 2);
      final affinity = events.whereType<AffinityApplied>().single;
      expect(affinity.result, AffinityKind.resisted);
    });

    test('a shooting weapon spends an arrow a shot and stops without one', () {
      final battle = Battle(
        setupFor(
          party: [hunter(slot: 0)],
          enemyKeys: const ['zombie'],
          arrows: 1,
          seed: 2,
        ),
      );
      final first = playOneRound(battle, alwaysAttack);
      expect(first.whereType<OutOfArrows>(), isEmpty);
      expect(battle.arrows, 0);
      final second = playOneRound(battle, alwaysAttack);
      expect(second.whereType<OutOfArrows>(), hasLength(1));
      expect(
        second.whereType<AttackDeclared>().where((e) => e.slot == 0),
        isEmpty,
      );
    });

    test('arrows used come back in the outcome', () {
      final battle = Battle(
        setupFor(
          party: [hunter(slot: 0), knight(slot: 1)],
          enemyKeys: const ['orc_soldier', 'orc_soldier'],
          arrows: 30,
        ),
      );
      final result = runBattle(battle, alwaysAttack);
      final shots = result.events
          .whereType<AttackDeclared>()
          .where((e) => e.slot == 0)
          .length;
      expect(result.outcome.arrowsUsed, shots);
      expect(result.outcome.arrowsUsed, greaterThan(0));
      expect(battle.arrows, 30 - shots);
    });
  });

  group('attack magic, end to end', () {
    test('one enemy: cost paid, damage as the table says', () {
      final battle = zeroBattle(
        setupFor(party: [mage(slot: 0)], enemyKeys: const ['orc_villager']),
      );
      final events = playOneRound(battle, castEveryRound(0, 101));
      // Tier 1 at skill 100: 300, less armour 1.
      expect(events.whereType<EnemyDamaged>().single.amount, 299);
      expect(seat(battle, 0).mp, 900 - 10);
      final cast = events.whereType<SpellCast>().single;
      expect([cast.magicId, cast.enemyIndex], [101, 0]);
    });

    test('every enemy: paid once per enemy', () {
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0)],
          enemyKeys: const ['orc_villager', 'orc_villager', 'orc_villager'],
        ),
      );
      final events = playOneRound(battle, castEveryRound(0, 201));
      expect(
        [for (final e in events.whereType<SpellCast>()) e.enemyIndex],
        [0, 1, 2],
      );
      expect(seat(battle, 0).mp, 900 - 30);
      expect(events.whereType<EnemyCollapsed>(), hasLength(3));
    });

    test('it runs dry partway through and stops there', () {
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0, mp: 15)],
          enemyKeys: const ['orc_villager', 'orc_villager', 'orc_villager'],
        ),
      );
      final events = playOneRound(battle, castEveryRound(0, 201));
      expect(events.whereType<NotEnoughSpellPoints>(), hasLength(1));
      expect(events.whereType<EnemyCollapsed>(), hasLength(1));
      expect(seat(battle, 0).mp, 5);
      expect(battle.enemies[2].hp, 80);
    });

    test('a tier that cannot be paid for is refused and the menu returns', () {
      final battle = Battle(
        setupFor(party: [mage(slot: 0)], enemyKeys: const ['zombie']),
      )..advance();
      battle.applyCommand(const ChooseAction(0, BattleAction.castSkill));
      final list = battle.pendingDecision! as SpellDecision;
      final top = list.options.firstWhere((o) => o.magicId == 110);
      // 1000 against 900.
      expect(top.affordable, isFalse);
      final refused = battle.applyCommand(const ChooseSpell(0, 110));
      expect(refused.single, isA<NotEnoughSpellPoints>());
      expect(battle.pendingDecision, isA<ActionDecision>());
    });

    test('a fallen enemy is removed for nothing', () {
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0)],
          enemyKeys: const ['orc_villager', 'zombie'],
          enemyOverrides: const {0: EnemyOverride(hp: 0, unconscious: 1)},
        ),
      );
      final events = playOneRound(
        battle,
        castEveryRound(0, 101, enemyIndex: 0),
      );
      final finished = events.whereType<EnemyFinished>().single;
      expect(finished.source, DamageSource.spell);
      expect(battle.enemies[0].dead, 1);
      expect(seat(battle, 0).mp, 900);
    });
  });

  group('cure magic, end to end', () {
    test('a paladin heals by level x 20 for level x 2', () {
      final battle = Battle(
        setupFor(
          party: [knight(hp: 100), paladin()],
          enemyKeys: const ['zombie'],
          seed: 3,
        ),
      );
      final events = playOneRound(battle, castEveryRound(2, 401, allySlot: 0));
      final healed = events.whereType<MemberHealed>().single;
      expect([healed.slot, healed.amount], [0, 100]);
      expect(seat(battle, 2).mp, 300 - 10);
    });

    test('a party-wide cure pays for each member it helps', () {
      final battle = Battle(
        setupFor(
          party: [
            knight(hp: 100),
            mage(hp: 100),
            knight(slot: 2, name: 'Whole'),
          ],
          enemyKeys: const ['orc_villager'],
          enemyOverrides: const {0: EnemyOverride(strength: 0, hp: 99999)},
          seed: 3,
        ),
      );
      final events = playOneRound(battle, castEveryRound(1, 406));
      // Two were hurt; the third needed nothing and cost nothing.
      expect(
        {for (final e in events.whereType<MemberHealed>()) e.slot},
        {0, 1},
      );
      expect(seat(battle, 1).mp, 900 - 20);
    });

    test('waking is priced by how far gone the member is', () {
      final battle = Battle(
        setupFor(
          party: [mage(slot: 0), knight(slot: 1, hp: 0, unconscious: 7)],
          enemyKeys: const ['orc_villager'],
          enemyOverrides: const {0: EnemyOverride(strength: 0, hp: 99999)},
        ),
      );
      final events = playOneRound(battle, castEveryRound(0, 403, allySlot: 1));
      expect(events.whereType<MemberRevived>().single.slot, 1);
      expect(seat(battle, 1).unconscious, 0);
      expect(seat(battle, 1).hp, 1);
      expect(seat(battle, 0).mp, 900 - 70);
    });
  });

  group('special magic, end to end', () {
    test('the every-enemy form pays per enemy and passes over the fallen', () {
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0)],
          enemyKeys: const ['troll_hunter', 'troll_hunter', 'troll_hunter'],
          enemyOverrides: const {1: EnemyOverride(hp: 0, unconscious: 1)},
        ),
      );
      final events = playOneRound(battle, castEveryRound(0, 306));
      expect(
        [for (final e in events.whereType<DebuffApplied>()) e.enemyIndex],
        [0, 2],
      );
      expect(battle.enemies[0].special, EnemySpecial.none);
      expect(battle.enemies[1].special, EnemySpecial.knockOut);
      expect(battle.enemies[2].special, EnemySpecial.none);
      expect(seat(battle, 0).mp, 900 - 400);
    });
  });

  group('ESP, end to end', () {
    test('독심: the enemy leaves the fight and takes the sixth seat', () {
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0)],
          // The second one has to outlast the round, and carry no
          // resistance a roll of zero could hide behind.
          enemyKeys: const ['orc_soldier', 'troll_soldier'],
          enemyOverrides: const {1: EnemyOverride(hp: 5000)},
        ),
      );
      final events = playOneRound(
        battle,
        castEveryRound(0, 501, enemyIndex: 0),
      );
      expect(events.whereType<EnemyRecruited>().single.enemyIndex, 0);
      final joined = events.whereType<AssistantJoined>().single;
      expect(joined.source, AssistantSource.persuasion);
      expect(joined.replaced, isFalse);
      expect(battle.enemies[0].recruited, isTrue);
      expect(battle.enemies[0].isConscious, isFalse);
      expect(seat(battle, 0).mp, 900 - 15);

      final helper = seat(battle, assistantSeat);
      expect(helper.snapshot.nameKey, 'enemy.3.orc_soldier');
      expect(helper.snapshot.family, Family.unknown);
      expect(helper.snapshot.level, 3);
      expect(helper.snapshot.weaponPower, 16);
      // It joins whole, whatever it had left as an enemy.
      expect(helper.snapshot.hp, 360);

      // The rest of the fight: it attacks on its own and is never asked.
      final asked = <int>{};
      final result = runBattle(battle, (d) {
        asked.add(d.slot);
        return alwaysAttack(d);
      });
      expect(asked, {0});
      expect(result.outcome.resultCode, BattleResultCode.win);
      // The persuaded one pays no gold; the troll soldier pays 3³ x 2.
      expect(result.outcome.goldGained, 54);
      expect(result.outcome.newAssistant, isNotNull);
      expect(result.outcome.newAssistant!.slot, assistantSeat);
      expect(result.outcome.newAssistant!.nameKey, 'enemy.3.orc_soldier');
      expect([for (final c in result.outcome.combatants) c.slot], [0, 5]);
      expect(result.outcome.enemies[0].left, isTrue);
      expect(result.outcome.departedSlots, isEmpty);
    });

    test('독심 does nothing to an enemy that cannot be talked to', () {
      final battle = zeroBattle(
        setupFor(party: [mage(slot: 0)], enemyKeys: const ['zombie']),
      );
      final events = playOneRound(battle, castEveryRound(0, 501));
      final failed = events.whereType<MindControlFailed>().single;
      expect(failed.reason, MindControlFailure.immune);
      expect(battle.party, hasLength(1));
    });

    test('수소 핵융합 lands on everyone and finishes the fallen', () {
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0)],
          enemyKeys: const ['orc_villager', 'orc_villager', 'zombie'],
          enemyOverrides: const {1: EnemyOverride(hp: 0, unconscious: 1)},
        ),
      );
      final events = playOneRound(battle, castEveryRound(0, 502));
      expect(events.whereType<FusionUnleashed>(), hasLength(1));
      // concentration 15 x level 5.
      expect(battle.enemies[0].hp, 80 - 75);
      expect(battle.enemies[1].dead, 1);
      expect(battle.enemies[2].hp, 2400 - 75);
      expect(seat(battle, 0).mp, 900 - 100);
      expect(events.whereType<EnemyFinished>().single.enemyIndex, 1);
    });

    test('공포 생성 can drive an enemy off the field', () {
      // Rolls of zero: rand(40) < resistance 0 is false, rand(60) > 15
      // is false - so it flees.
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0)],
          enemyKeys: const ['troll_soldier', 'zombie'],
        ),
      );
      final events = playOneRound(
        battle,
        castEveryRound(0, 503, enemyIndex: 0),
      );
      expect(events.whereType<EnemyFled>().single.enemyIndex, 0);
      expect(battle.enemies[0].fled, isTrue);
      // The caster is paid for it: level 3.
      expect(seat(battle, 0).experienceGained, 27);
      expect(battle.enemies[0].toState().left, isTrue);
    });

    test('유체 이탈 drops an enemy where it stands and pays for it', () {
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0, mp: 2000)],
          enemyKeys: const ['troll_soldier', 'zombie'],
        ),
      );
      final events = playOneRound(
        battle,
        castEveryRound(0, 506, enemyIndex: 0),
      );
      expect(events.whereType<EnemyStruckDown>().single.enemyIndex, 0);
      expect(battle.enemies[0].hp, 0);
      expect(battle.enemies[0].unconscious, 1);
      expect(seat(battle, 0).experienceGained, 27);
      expect(seat(battle, 0).mp, 2000 - 1000);
    });
  });

  group('summoning, end to end', () {
    test('a summon takes the sixth seat and attacks the same round', () {
      final battle = Battle(
        setupFor(party: [mage(slot: 0)], enemyKeys: const ['zombie'], seed: 6),
      );
      final events = playOneRound(battle, castEveryRound(0, 601));
      final joined = events.whereType<AssistantJoined>().single;
      expect(joined.source, AssistantSource.summon);
      expect(joined.replaced, isFalse);
      final summon = seat(battle, assistantSeat);
      expect(summon.snapshot.nameKey, startsWith('summon.'));
      expect(summon.snapshot.family, Family.elemental);
      expect(summon.snapshot.level, 20);
      expect(summon.joinedInBattle, isTrue);
      // The fork's own price: skill x tier² / 10.
      expect(seat(battle, 0).mp, 900 - 10);
      expect(
        events.whereType<AttackDeclared>().where(
          (e) => e.slot == assistantSeat,
        ),
        hasLength(1),
      );
    });

    test('a second summon replaces the first', () {
      final battle = Battle(
        setupFor(
          party: [mage(slot: 0)],
          enemyKeys: const ['zombie'],
          enemyOverrides: const {0: EnemyOverride(strength: 0, hp: 9999999)},
          seed: 6,
        ),
      );
      playOneRound(battle, castEveryRound(0, 601));
      final events = playOneRound(battle, castEveryRound(0, 608));
      expect(events.whereType<AssistantJoined>().single.replaced, isTrue);
      expect(battle.party, hasLength(2));
      expect(seat(battle, assistantSeat).snapshot.family, Family.golem);
      expect(seat(battle, 0).mp, 900 - 10 - 640);
    });

    test('the outcome hands the new assistant back whole', () {
      final battle = Battle(
        setupFor(
          party: [mage(slot: 0), assistant()],
          enemyKeys: const ['orc_soldier', 'orc_soldier'],
          seed: 9,
        ),
      );
      var cast = false;
      final result = runBattle(battle, (d) {
        if (!cast && d is ActionDecision) {
          cast = true;
          return ChooseAction(d.slot, BattleAction.castSkill);
        }
        if (d is SpellDecision) return ChooseSpell(d.slot, 607);
        return alwaysAttack(d);
      });
      final joined = result.events.whereType<AssistantJoined>().single;
      expect(joined.replaced, isTrue, reason: 'someone was sitting there');
      final handed = result.outcome.newAssistant!;
      expect(handed.slot, assistantSeat);
      expect(handed.family, Family.giant);
      expect(handed.nameKey, startsWith('summon.'));
      final row = result.outcome.combatants.firstWhere(
        (c) => c.slot == assistantSeat,
      );
      expect(handed.hp, row.hp);
      expect(handed.poison, row.poison);
      expect(result.outcome.departedSlots, isEmpty);
    });

    test('an assistant who was there all along is not handed back', () {
      final battle = Battle(
        setupFor(
          party: [knight(), assistant()],
          enemyKeys: const ['orc_villager'],
        ),
      );
      final result = runBattle(battle, alwaysAttack);
      expect(result.outcome.newAssistant, isNull);
      expect([for (final c in result.outcome.combatants) c.slot], [0, 5]);
    });
  });

  group('herbs and potions', () {
    test('a potion restores 1000 to the one who drinks it', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight(hp: 100)],
          enemyKeys: const ['orc_villager'],
          consumables: const {ItemKey.hpPotion: 2},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.hpPotion),
      );
      // Capped at the maximum of 750.
      expect(events.whereType<MemberHealed>().single.amount, 650);
      expect(battle.consumables[ItemKey.hpPotion], 1);
    });

    test('the magic potion is for those who hold magic', () {
      final battle = zeroBattle(
        setupFor(
          party: [mage(slot: 0, mp: 100)],
          enemyKeys: const ['orc_villager'],
          consumables: const {ItemKey.mpPotion: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.mpPotion),
      );
      expect(events.whereType<MemberMpRestored>().single.amount, 800);
      expect(seat(battle, 0).mp, 900);
    });

    test('the two herbs for the fallen ask who', () {
      final battle = zeroBattle(
        setupFor(
          party: [
            knight(),
            knight(slot: 1, name: 'Down', hp: 0, unconscious: 9),
            knight(slot: 2, name: 'Gone', hp: 0, unconscious: 5, dead: 2),
          ],
          enemyKeys: const ['orc_villager'],
          enemyOverrides: const {0: EnemyOverride(strength: 0, hp: 99999)},
          consumables: const {ItemKey.awakeningHerb: 1, ItemKey.revivalHerb: 1},
        ),
      );
      final woke = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.awakeningHerb, allySlot: 1),
      );
      expect(woke.whereType<MemberRevived>().single.slot, 1);
      expect(seat(battle, 1).unconscious, 0);
      expect(seat(battle, 1).hp, 1);

      final raised = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.revivalHerb, allySlot: 2),
      );
      expect(raised.whereType<MemberResurrected>().single.slot, 2);
      // Back from the dead, and still unconscious.
      expect(seat(battle, 2).dead, 0);
      expect(seat(battle, 2).unconscious, 5);
    });

    test('what was used comes back in the outcome', () {
      final battle = Battle(
        setupFor(
          party: [knight(hp: 100), knight(slot: 1)],
          enemyKeys: const ['orc_soldier'],
          consumables: const {ItemKey.hpPotion: 1, ItemKey.antidoteHerb: 3},
        ),
      );
      final result = runBattle(battle, useItemEveryRound(0, ItemKey.hpPotion));
      expect(result.outcome.consumedItems, {ItemKey.hpPotion: 1});
    });
  });

  group('crystals (ch.9.8)', () {
    test('화염: 32,500 on one enemy, less its armour', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['orc_villager'],
          consumables: const {ItemKey.flameCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.flameCrystal),
      );
      final hit = events.whereType<EnemyDamaged>().single;
      expect(hit.amount, 32500 - 1);
      expect(hit.source, DamageSource.spell);
    });

    test('화염 has no roll to hit but magic resistance still stops it', () {
      // A roll of zero is under the zombie's resistance of 20.
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['zombie'],
          consumables: const {ItemKey.flameCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.flameCrystal),
      );
      final blocked = events.whereType<EnemyBlocked>().first;
      expect(blocked.kind, BlockKind.resisted);
      expect(blocked.source, DamageSource.spell);
      // Used up all the same.
      expect(battle.consumables[ItemKey.flameCrystal], 0);
    });

    test('한파: 20,000 on each enemy', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['orc_villager', 'orc_villager'],
          consumables: const {ItemKey.frostCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.frostCrystal),
      );
      expect(
        [for (final e in events.whereType<EnemyDamaged>()) e.amount],
        [19999, 19999],
      );
    });

    test('다크 alone does not react and is not used up', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['zombie'],
          consumables: const {ItemKey.darkCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.darkCrystal),
      );
      final silent = events.whereType<CrystalDidNotReact>().single;
      expect(silent.reason, CrystalSilence.needsItsPair);
      expect(battle.consumables[ItemKey.darkCrystal], 1);
    });

    test('다크 + 에보니 answer only to 로드안', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['zombie'],
          consumables: const {ItemKey.darkCrystal: 1, ItemKey.ebonyCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.ebonyCrystal),
      );
      final silent = events.whereType<CrystalDidNotReact>().single;
      expect(silent.reason, CrystalSilence.wrongEnemy);
      expect(battle.consumables[ItemKey.darkCrystal], 1);
      expect(battle.consumables[ItemKey.ebonyCrystal], 1);
    });

    test('다크 + 에보니 halve everything 로드안 has', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['lord_ahn'],
          consumables: const {ItemKey.darkCrystal: 1, ItemKey.ebonyCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.darkCrystal),
      );
      expect(events.whereType<EnemyAged>().single.enemyIndex, 0);
      final ahn = battle.enemies.single;
      expect(
        [
          ahn.level,
          ahn.strength,
          ahn.mentality,
          ahn.endurance,
          ahn.physicalResistance,
          ahn.magicResistance,
          ahn.agility,
          ahn.accuracyPhysical,
          ahn.accuracyMagic,
          ahn.ac,
        ],
        [30, 100, 100, 100, 100, 100, 10, 25, 25, 10],
      );
      // Hit points are left alone.
      expect(ahn.hp, 120000);
      expect(battle.consumables[ItemKey.darkCrystal], 0);
      expect(battle.consumables[ItemKey.ebonyCrystal], 0);
    });

    test('영혼 halves what an enemy has left', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['zombie'],
          consumables: const {ItemKey.spiritCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.spiritCrystal),
      );
      expect(events.whereType<EnemySoulWithered>().single.amount, 1200);
      expect(battle.enemies.single.hp, 1200);
    });

    test('소환 calls a crystal creature into the sixth seat', () {
      final battle = zeroBattle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['zombie'],
          consumables: const {ItemKey.summonCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.summonCrystal),
      );
      final joined = events.whereType<AssistantJoined>().single;
      expect(joined.source, AssistantSource.crystal);
      final creature = seat(battle, assistantSeat);
      // A roll of zero is the dragon.
      expect(creature.snapshot.nameKey, 'summon.crystal_dragon');
      expect(creature.snapshot.level, 30);
      expect(creature.snapshot.maxHp, 9000);
      expect(creature.snapshot.immuneToMindControl, isTrue);
    });

    test('에너지 wakes the living whole and raises the dead with one', () {
      final battle = zeroBattle(
        setupFor(
          party: [
            knight(hp: 10),
            knight(slot: 1, name: 'Down', hp: 0, unconscious: 9),
            knight(slot: 2, name: 'Gone', hp: 0, unconscious: 5, dead: 2),
          ],
          enemyKeys: const ['orc_villager'],
          enemyOverrides: const {0: EnemyOverride(strength: 0, hp: 99999)},
          consumables: const {ItemKey.energyCrystal: 1},
        ),
      );
      final events = playOneRound(
        battle,
        useItemEveryRound(0, ItemKey.energyCrystal),
      );
      expect(events.whereType<PartyRestored>(), hasLength(1));
      expect(seat(battle, 0).hp, 750);
      expect(seat(battle, 1).hp, 750);
      expect(seat(battle, 1).unconscious, 0);
      expect(seat(battle, 2).dead, 0);
      expect(seat(battle, 2).unconscious, 0);
      expect(seat(battle, 2).hp, 1);
    });
  });

  group('the contract round-trips through JSON', () {
    test('setup', () {
      final setup = setupFor(
        party: [knight(), mage(), assistant(attacksAll: true, immune: true)],
        enemyKeys: const ['troll_magic_user_lv5', 'orc_soldier'],
        episode: 3,
        consumables: const {ItemKey.hpPotion: 2, ItemKey.frostCrystal: 1},
        arrows: 12,
        initialGap: 1,
        enemyRanks: const [3, 1],
        enemyOverrides: const {
          1: EnemyOverride(
            nameKey: 'draconian_believer',
            level: 9,
            special: EnemySpecial.slay,
            abilities: {EnemyAbility.clone, EnemyAbility.healAll},
            givesGold: false,
          ),
        },
        canEscape: false,
        enemyActsFirst: true,
        attackUnconscious: false,
      );
      final back = BattleSetup.fromJson(setup.toJson());
      expect(back.toJson(), setup.toJson());
      expect(back.episode, 3);
      expect(back.arrows, 12);
      expect(back.canEscape, isFalse);
      expect(back.enemyActsFirst, isTrue);
      expect(back.attackUnconscious, isFalse);
      expect(back.enemyOverrides[1]!.abilities, {
        EnemyAbility.clone,
        EnemyAbility.healAll,
      });
      expect(back.enemyOverrides[1]!.special, EnemySpecial.slay);
      expect(back.party[2].attacksAll, isTrue);
      expect(back.party[2].immuneToMindControl, isTrue);
      expect(back.party[1].family, Family.mage);
      expect(back.party[1].skills, setup.party[1].skills);
      // And the two play out identically.
      BattleOutcome play(BattleSetup s) =>
          runBattle(Battle(s), alwaysAttack).outcome;
      expect(play(back).toJson(), play(setup).toJson());
    });

    test('outcome', () {
      final battle = Battle(
        setupFor(
          party: [
            mage(slot: 0),
            knight(slot: 1, weaponKind: WeaponKind.shoot),
          ],
          enemyKeys: const ['orc_soldier', 'orc_soldier'],
          consumables: const {ItemKey.hpPotion: 1},
          seed: 12,
        ),
      );
      final outcome = runBattle(battle, castEveryRound(0, 601)).outcome;
      final back = BattleOutcome.fromJson(outcome.toJson());
      expect(back.toJson(), outcome.toJson());
      expect(back.resultCode, outcome.resultCode);
      expect(back.newAssistant?.nameKey, outcome.newAssistant?.nameKey);
      expect(back.enemies, hasLength(2));
      expect(back.arrowsUsed, outcome.arrowsUsed);
    });

    test('commands', () {
      const commands = <BattleCommand>[
        ChooseAction(0, BattleAction.castSkill),
        ChooseSpell(0, 502),
        ChooseEnemyTarget(1, 2),
        ChooseItem(2, ItemKey.flameCrystal),
        ChooseAllyTarget(3, 5),
        CancelChoice(4),
      ];
      for (final command in commands) {
        final back = BattleCommand.fromJson(command.toJson());
        expect(back.runtimeType, command.runtimeType);
        expect(back.toJson(), command.toJson());
      }
    });

    test('the shared vocabulary', () {
      expect(assistantSeat, 5);
      expect(maxEnemies, 8);
      expect(
        [for (final f in Family.values) f.name],
        ['fighter', 'mage', 'elemental', 'giant', 'golem', 'dragon', 'unknown'],
      );
      expect(
        [for (final k in WeaponKind.values) k.name],
        ['bare', 'slash', 'chop', 'pierce', 'shoot', 'special'],
      );
      expect(
        [ClassId.fighter, ClassId.knight, ClassId.paladin, ClassId.timewalker],
        [1, 2, 7, 7],
      );
      expect([ClassId.esper, ClassId.demigod], [8, 9]);
      expect(
        [for (final item in battleItemList) item.key],
        [
          'item.hp_potion',
          'item.mp_potion',
          'item.antidote_herb',
          'item.awakening_herb',
          'item.revival_herb',
          'crystal.flame',
          'crystal.frost',
          'crystal.dark',
          'crystal.ebony',
          'crystal.spirit',
          'crystal.summon',
          'crystal.energy',
        ],
      );
    });
  });
}
