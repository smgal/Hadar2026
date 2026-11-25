import 'package:lore_battle/lore_battle.dart';
import 'package:test/test.dart';

/// Every formula of design chapters 8 and 9, pinned against chosen
/// rolls. `ScriptedRng` refuses a value outside the range a rule asks
/// for, so a wrong `rand(N)` shows up as a thrown error rather than a
/// quietly different number.
ScriptedRng rolls(List<int> script) => ScriptedRng(script);

EnemyInstance enemy(String key, {int episode = 3, EnemyOverride? override}) =>
    EnemyInstance(
      enemyByKey(episode, key)!,
      episode: episode,
      override: override,
    );

void main() {
  group('a member\'s weapon blow (ch.8.5)', () {
    test('rand(20) > accuracy misses - a roll equal to it hits', () {
      for (var roll = 0; roll < 20; roll++) {
        expect(
          memberAttackMisses(accuracy: 10, rng: rolls([roll])),
          roll > 10,
          reason: 'roll $roll',
        );
      }
      expect(memberAttackMisses(accuracy: 19, rng: rolls([19])), isFalse);
    });

    test('base damage: strength x weapon power x skill / 10', () {
      expect(
        memberBaseDamage(
          strength: 16,
          weaponPower: 40,
          skill: 50,
          fixedCoefficient: false,
        ),
        3200,
      );
    });

    test('monks and assassins: strength x skill x 5, weapon ignored', () {
      expect(
        memberBaseDamage(
          strength: 17,
          weaponPower: 999,
          skill: 60,
          fixedCoefficient: true,
        ),
        5100,
      );
    });

    test('the assistant: strength x weapon power x level / 2', () {
      expect(assistantBaseDamage(strength: 12, weaponPower: 22, level: 6), 792);
    });

    test('deviation keeps 51..100 percent', () {
      expect(applyDeviation(1000, rolls([0])), 1000);
      expect(applyDeviation(1000, rolls([49])), 510);
      for (var roll = 0; roll < 50; roll++) {
        final kept = applyDeviation(1000, rolls([roll]));
        expect(kept, inInclusiveRange(510, 1000));
      }
    });

    test('rand(100) < physical resistance stops the blow', () {
      expect(enemyBlocksBlow(physicalResistance: 30, rng: rolls([29])), isTrue);
      expect(
        enemyBlocksBlow(physicalResistance: 30, rng: rolls([30])),
        isFalse,
      );
      expect(enemyBlocksBlow(physicalResistance: 0, rng: rolls([0])), isFalse);
      // 100 or more is immunity.
      expect(
        enemyBlocksBlow(physicalResistance: 100, rng: rolls([99])),
        isTrue,
      );
    });

    test('armour takes ac x level x (1..10)', () {
      expect(enemyDefence(ac: 2, level: 3, rng: rolls([0])), 6);
      expect(enemyDefence(ac: 2, level: 3, rng: rolls([9])), 60);
    });

    test('the weapon kind picks the skill slot', () {
      CombatantSnapshot with_(WeaponKind kind, {int level = 4}) =>
          CombatantSnapshot(
            slot: 0,
            name: 'a',
            level: level,
            skills: const [11, 22, 33, 44, 55, 66],
            hp: 1,
            maxHp: 1,
            weaponKind: kind,
          );
      expect(with_(WeaponKind.slash).weaponSkill, 11);
      expect(with_(WeaponKind.chop).weaponSkill, 22);
      expect(with_(WeaponKind.pierce).weaponSkill, 33);
      expect(with_(WeaponKind.shoot).weaponSkill, 44);
      expect(with_(WeaponKind.bare).weaponSkill, 66);
      // The assistant's natural weapon: level x 5.
      expect(with_(WeaponKind.special, level: 7).weaponSkill, 35);
    });
  });

  group('an enemy\'s weapon blow (ch.8.6)', () {
    test('rand(20) >= accuracy misses', () {
      expect(enemyAttackMisses(accuracyPhysical: 9, rng: rolls([9])), isTrue);
      expect(enemyAttackMisses(accuracyPhysical: 9, rng: rolls([8])), isFalse);
    });

    test('strength x level x (1..10) / 5', () {
      expect(enemyWeaponDamage(strength: 10, level: 3, rng: rolls([0])), 6);
      expect(enemyWeaponDamage(strength: 10, level: 3, rng: rolls([9])), 60);
    });

    test('the shield: rand(550) < skill x power', () {
      expect(
        shieldBlocks(shieldSkill: 30, shieldPower: 2, rng: rolls([59])),
        isTrue,
      );
      expect(
        shieldBlocks(shieldSkill: 30, shieldPower: 2, rng: rolls([60])),
        isFalse,
      );
      // The best shield in the best hands still lets one in eleven by.
      expect(
        shieldBlocks(shieldSkill: 100, shieldPower: 5, rng: rolls([500])),
        isFalse,
      );
      // Bracing adds to the same threshold.
      expect(
        shieldBlocks(
          shieldSkill: 30,
          shieldPower: 2,
          bonus: 247,
          rng: rolls([306]),
        ),
        isTrue,
      );
    });

    test('a member\'s armour takes ac x level x (1..10) / 10', () {
      expect(memberDefence(ac: 4, level: 5, rng: rolls([0])), 2);
      expect(memberDefence(ac: 4, level: 5, rng: rolls([9])), 20);
    });
  });

  group('attack magic (ch.9.2)', () {
    test('the table for a skill of 100', () {
      expect(
        [for (var j = 1; j <= 10; j++) attackMagicCost(skill: 100, tier: j)],
        [10, 40, 90, 160, 250, 360, 490, 640, 810, 1000],
      );
      expect(
        [for (var j = 1; j <= 10; j++) attackMagicDamage(skill: 100, tier: j)],
        [300, 1200, 2700, 4800, 7500, 10800, 14700, 19200, 24300, 30000],
      );
    });

    test('the cost is rounded, not truncated', () {
      expect(attackMagicCost(skill: 15, tier: 1), 2); // 1.5
      expect(attackMagicCost(skill: 14, tier: 1), 1); // 1.4
      expect(attackMagicCost(skill: 25, tier: 3), 23); // 22.5
    });

    test('a skill of ten opens a tier', () {
      expect(tiersOpened(9), 0);
      expect(tiersOpened(10), 1);
      expect(tiersOpened(55), 5);
      expect(tiersOpened(100), 10);
      expect(tiersOpened(250), 10);
    });

    test('rand(20) >= accuracy misses, rand(100) < resistance stops it', () {
      expect(magicAttackMisses(accuracy: 10, rng: rolls([10])), isTrue);
      expect(magicAttackMisses(accuracy: 10, rng: rolls([9])), isFalse);
      expect(enemyResistsMagic(magicResistance: 50, rng: rolls([49])), isTrue);
      expect(enemyResistsMagic(magicResistance: 50, rng: rolls([50])), isFalse);
      // 대제사장: 255 never lets a spell through.
      expect(enemyResistsMagic(magicResistance: 255, rng: rolls([99])), isTrue);
    });
  });

  group('cure magic (ch.9.4)', () {
    CureApplied step(
      CureStep s, {
      int hp = 50,
      int maxHp = 500,
      int poison = 0,
      int unconscious = 0,
      int dead = 0,
      int mp = 1000,
      int level = 5,
      bool free = false,
    }) => applyCureStep(
      s,
      hp: hp,
      maxHp: maxHp,
      poison: poison,
      unconscious: unconscious,
      dead: dead,
      deathThreshold: 75,
      casterMp: mp,
      casterLevel: level,
      free: free,
    );

    test('the tiers a skill opens: 1..5 for one, 6..10 for all', () {
      expect(castableCureTiers(0), isEmpty);
      expect(castableCureTiers(10), [1]);
      expect(castableCureTiers(50), [1, 2, 3, 4, 5]);
      expect(castableCureTiers(59), [1, 2, 3, 4, 5]);
      expect(castableCureTiers(60), [1, 2, 3, 4, 5, 6]);
      expect(castableCureTiers(100), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(cureTierTargetsAll(5), isFalse);
      expect(cureTierTargetsAll(6), isTrue);
    });

    test('the fifth of each half runs all four, deepest first', () {
      expect(cureStepsForTier(1), [CureStep.heal]);
      expect(cureStepsForTier(7), [CureStep.antidote]);
      expect(cureStepsForTier(3), [CureStep.recoverConsciousness]);
      expect(cureStepsForTier(9), [CureStep.revitalize]);
      expect(cureStepsForTier(5), cureStepsForTier(10));
      expect(cureStepsForTier(5), [
        CureStep.revitalize,
        CureStep.recoverConsciousness,
        CureStep.antidote,
        CureStep.heal,
      ]);
    });

    test('heal: costs level x 2, restores level x 20, up to the maximum', () {
      final healed = step(CureStep.heal);
      expect(healed.applied, isTrue);
      expect(healed.mpSpent, 10);
      expect(healed.amount, 100);
      expect(healed.hp, 150);
      final capped = step(CureStep.heal, hp: 480);
      expect(capped.hp, 500);
      expect(capped.amount, 20);
    });

    test('heal refuses the poisoned, the unconscious, the dead, the whole', () {
      expect(step(CureStep.heal, poison: 1).applied, isFalse);
      expect(step(CureStep.heal, unconscious: 1, hp: 0).applied, isFalse);
      expect(step(CureStep.heal, dead: 1, hp: 0).applied, isFalse);
      expect(step(CureStep.heal, hp: 500).applied, isFalse);
      final broke = step(CureStep.heal, mp: 9);
      expect(broke.applied, isFalse);
      expect(broke.shortOfMp, isTrue);
    });

    test('antidote: 15, and not through unconsciousness', () {
      final cured = step(CureStep.antidote, poison: 4);
      expect(cured.poison, 0);
      expect(cured.mpSpent, 15);
      expect(step(CureStep.antidote, poison: 0).applied, isFalse);
      expect(
        step(CureStep.antidote, poison: 4, unconscious: 1).applied,
        isFalse,
      );
    });

    test('waking costs ten per point of unconsciousness', () {
      final woken = step(CureStep.recoverConsciousness, unconscious: 7, hp: 0);
      expect(woken.unconscious, 0);
      expect(woken.hp, 1);
      expect(woken.mpSpent, 70);
      expect(
        step(CureStep.recoverConsciousness, unconscious: 7, dead: 1).applied,
        isFalse,
      );
      expect(
        step(CureStep.recoverConsciousness, unconscious: 7, mp: 69).shortOfMp,
        isTrue,
      );
    });

    test('raising costs thirty per point of death and leaves them '
        'unconscious', () {
      final raised = step(
        CureStep.revitalize,
        dead: 3,
        unconscious: 200,
        hp: 0,
      );
      expect(raised.dead, 0);
      expect(raised.mpSpent, 90);
      // Pulled down to the threshold so they do not die again at once.
      expect(raised.unconscious, 75);
      final fresh = step(CureStep.revitalize, dead: 1, unconscious: 0, hp: 0);
      expect(fresh.unconscious, 1);
      expect(step(CureStep.revitalize, dead: 0).applied, isFalse);
    });

    test('the composite brings a dead member all the way back', () {
      final result = applyCure(
        5,
        hp: 0,
        maxHp: 500,
        poison: 2,
        unconscious: 4,
        dead: 1,
        deathThreshold: 75,
        casterMp: 1000,
        casterLevel: 5,
      );
      expect(result.dead, 0);
      expect(result.unconscious, 0);
      expect(result.poison, 0);
      // Woken at 1, then healed by level x 20.
      expect(result.hp, 101);
      // 30 x 1 + 10 x 4 + 15 + 5 x 2.
      expect(result.mpSpent, 30 + 40 + 15 + 10);
    });

    test('a herb runs the same step for nothing', () {
      final woken = step(
        CureStep.recoverConsciousness,
        unconscious: 50,
        hp: 0,
        mp: 0,
        free: true,
      );
      expect(woken.applied, isTrue);
      expect(woken.mpSpent, 0);
    });

    test('a paladin reads the cure skill from its second slot', () {
      const paladin = CombatantSnapshot(
        slot: 0,
        name: 'p',
        family: Family.fighter,
        classId: ClassId.paladin,
        skills: [40, 30, 10, 0, 40, 10],
        hp: 1,
        maxHp: 1,
      );
      const knight = CombatantSnapshot(
        slot: 0,
        name: 'k',
        family: Family.fighter,
        classId: ClassId.knight,
        skills: [40, 30, 10, 0, 40, 10],
        hp: 1,
        maxHp: 1,
      );
      expect(paladin.cureSkill, 30);
      expect(castableSkills(paladin, episode: 3), [401, 402, 403]);
      expect(paladin.holdsMagic, isTrue);
      // The same numbers on a knight are a chopping skill.
      expect(knight.cureSkill, 0);
      expect(castableSkills(knight, episode: 3), isEmpty);
      expect(knight.holdsMagic, isFalse);
    });
  });

  group('special magic (ch.9.5)', () {
    test('tiers 1..5 are the five, 6..10 the same five on everyone', () {
      expect(
        [for (var t = 1; t <= 5; t++) specialKindOfTier(t)],
        [
          SpecialKind.disarm,
          SpecialKind.weaken,
          SpecialKind.drain,
          SpecialKind.silence,
          SpecialKind.unmake,
        ],
      );
      for (var t = 1; t <= 5; t++) {
        expect(specialKindOfTier(t + 5), specialKindOfTier(t));
        expect(specialTierHitsAll(t), isFalse);
        expect(specialTierHitsAll(t + 5), isTrue);
      }
      expect(
        [
          for (final k in const [
            SpecialKind.disarm,
            SpecialKind.weaken,
            SpecialKind.drain,
            SpecialKind.silence,
            SpecialKind.unmake,
          ])
            specialSpells[k]!.cost,
        ],
        [200, 50, 100, 150, 400],
      );
    });

    test('기술 무력화 removes the special attack', () {
      final t = enemy('troll_hunter');
      expect(t.special, EnemySpecial.knockOut);
      final cast = castSpecial(
        SpecialKind.disarm,
        target: t,
        accuracy: 15,
        rng: rolls([0, 15]),
      );
      expect(cast.outcome, SpecialOutcome.applied);
      expect(t.special, EnemySpecial.none);
    });

    test('resisted on rand(100) < magic resistance, missed on rand(60) > '
        'accuracy', () {
      final wizard = enemy('kobold_wizard'); // magic resistance 50
      final resisted = castSpecial(
        SpecialKind.disarm,
        target: wizard,
        accuracy: 15,
        rng: rolls([49]),
      );
      expect(resisted.outcome, SpecialOutcome.resisted);

      final hunter = enemy('troll_hunter');
      final missed = castSpecial(
        SpecialKind.disarm,
        target: hunter,
        accuracy: 15,
        rng: rolls([0, 16]),
      );
      expect(missed.outcome, SpecialOutcome.missed);
      expect(hunter.special, EnemySpecial.knockOut);
    });

    test('방어 무력화: rolled against physical resistance; armour and both '
        'resistances drop', () {
      final t = enemy('orc_warrior'); // resist 25/25, armour 3
      final rng = rolls([99, 0]);
      castSpecial(SpecialKind.weaken, target: t, accuracy: 15, rng: rng);
      expect(t.ac, 2);
      expect(t.physicalResistance, 15);
      expect(t.magicResistance, 15);
      // Under 31 the armour always goes: no coin was tossed.
      expect(rng.draws, 2);
    });

    test('방어 무력화 on a resistant target tosses a coin for the armour', () {
      final kept = enemy('orc_king'); // resist 50/50, armour 5
      castSpecial(
        SpecialKind.weaken,
        target: kept,
        accuracy: 15,
        rng: rolls([99, 0, 1]),
      );
      expect(kept.ac, 5);
      expect(kept.physicalResistance, 40);
      expect(kept.magicResistance, 40);

      final lost = enemy('orc_king');
      castSpecial(
        SpecialKind.weaken,
        target: lost,
        accuracy: 15,
        rng: rolls([99, 0, 0]),
      );
      expect(lost.ac, 4);
    });

    test('방어 무력화 is rolled on 25 once armour is 5 or more', () {
      expect(
        specialAccuracyRange(specialSpells[SpecialKind.weaken]!, enemyAc: 4),
        40,
      );
      expect(
        specialAccuracyRange(specialSpells[SpecialKind.weaken]!, enemyAc: 5),
        25,
      );
      // A 30 is not a roll of rand(25): the scripted generator refuses.
      expect(
        () => castSpecial(
          SpecialKind.weaken,
          target: enemy('orc_king'),
          accuracy: 15,
          rng: rolls([99, 30]),
        ),
        throwsStateError,
      );
    });

    test('nothing goes below zero (the original wrapped to 251)', () {
      final t = enemy(
        'orc_soldier',
        override: const EnemyOverride(
          physicalResistance: 5,
          magicResistance: 3,
          ac: 0,
        ),
      );
      castSpecial(
        SpecialKind.weaken,
        target: t,
        accuracy: 15,
        rng: rolls([99, 0]),
      );
      expect(t.ac, 0);
      expect(t.physicalResistance, 0);
      expect(t.magicResistance, 0);
    });

    test('능력 저하: rolled on 200; level drops, never below 1', () {
      final t = enemy('orc_soldier'); // level 3, resist 5/5
      castSpecial(
        SpecialKind.drain,
        target: t,
        accuracy: 15,
        rng: rolls([199, 0]),
      );
      expect(t.level, 2);
      expect(t.physicalResistance, 0);
      // Level feeds the hit point ceiling and what a kill pays.
      expect(t.maxHp, 12 * 2 * 10);
      expect(t.experienceLevel, 2);
      final villager = enemy('orc_villager'); // level 1
      castSpecial(
        SpecialKind.drain,
        target: villager,
        accuracy: 15,
        rng: rolls([199, 0]),
      );
      expect(villager.level, 1);
    });

    test('마법 불능 takes one rung off the casting ladder', () {
      final t = enemy('orc_magic_user'); // cast level 2
      final first = castSpecial(
        SpecialKind.silence,
        target: t,
        accuracy: 99,
        rng: rolls([99, 99]),
      );
      expect(t.castLevel, 1);
      expect(first.effect, SpecialEffect.castingLowered);
      final second = castSpecial(
        SpecialKind.silence,
        target: t,
        accuracy: 99,
        rng: rolls([99, 99]),
      );
      expect(t.castLevel, 0);
      expect(second.effect, SpecialEffect.castingRemoved);
    });

    test('탈 초인화 removes the lowest ability - it does not add one', () {
      final king = enemy('draconian_king');
      final cast = castSpecial(
        SpecialKind.unmake,
        target: king,
        accuracy: 99,
        rng: rolls([99, 99]),
      );
      expect(king.abilities, isNot(contains(EnemyAbility.mindControl)));
      expect(king.abilities, hasLength(4));
      expect(cast.effect, SpecialEffect.superhumanLowered);

      final wraith = enemy('wraith'); // 전체중독 only
      final last = castSpecial(
        SpecialKind.unmake,
        target: wraith,
        accuracy: 99,
        rng: rolls([99, 99]),
      );
      expect(wraith.abilities, isEmpty);
      expect(last.effect, SpecialEffect.superhumanRemoved);
    });

    test('탈 초인화 in Parts 1 and 2 lowers the grade', () {
      final neo = enemy('neo_necromancer', episode: 1); // grade 3, resist 100
      final cast = castSpecial(
        SpecialKind.unmake,
        target: neo,
        accuracy: 99,
        rng: rolls([99, 99]),
      );
      // Resistance 100 always stops it: rand(100) < 100.
      expect(cast.outcome, SpecialOutcome.resisted);
      expect(neo.superLevel, 3);

      final draconian = enemy('draconian', episode: 1); // grade 1, resist 60
      castSpecial(
        SpecialKind.unmake,
        target: draconian,
        accuracy: 99,
        rng: rolls([60, 99]),
      );
      expect(draconian.superLevel, 0);
    });

    test('Part 1\'s 독 poisons, and is listed only in Part 1', () {
      final t = enemy('orc', episode: 1);
      castSpecial(
        SpecialKind.poison,
        target: t,
        accuracy: 15,
        rng: rolls([0, 0]),
      );
      expect(t.poison, 1);

      const mage = CombatantSnapshot(
        slot: 0,
        name: 'm',
        family: Family.mage,
        skills: [0, 0, 0, 20, 0, 0],
        hp: 1,
        maxHp: 1,
      );
      expect(castableSkills(mage, episode: 1), [300, 301, 302]);
      expect(castableSkills(mage, episode: 2), [301, 302]);
      expect(castableSkills(mage, episode: 3), [301, 302]);
      expect(specialKindOfSkill(300), SpecialKind.poison);
      expect(scopeOf(300), SkillScope.curse);
      expect(scopeOf(306), SkillScope.curseAll);
    });
  });

  group('ESP (ch.9.6)', () {
    test('each ability has its own threshold and price', () {
      expect(espAbilitiesFor(19), isEmpty);
      expect(espAbilitiesFor(20), [EspAbility.fusion]);
      expect(espAbilitiesFor(30), [EspAbility.fusion, EspAbility.fear]);
      expect(espAbilitiesFor(40), [
        EspAbility.persuade,
        EspAbility.fusion,
        EspAbility.fear,
      ]);
      expect(espAbilitiesFor(80), hasLength(4));
      expect(espAbilitiesFor(90), hasLength(5));
      expect(espAbilitiesFor(100), EspAbility.values);
      expect(
        {for (final s in espSpecs) s.ability: s.cost},
        {
          EspAbility.persuade: 15,
          EspAbility.fusion: 100,
          EspAbility.fear: 100,
          EspAbility.illusion: 300,
          EspAbility.metabolism: 500,
          EspAbility.astral: 1000,
        },
      );
      expect(skillIdOfEsp(EspAbility.persuade), 501);
      expect(skillIdOfEsp(EspAbility.astral), 506);
      expect(espAbilityOfSkill(502), EspAbility.fusion);
    });

    test('독심: an enemy that cannot be talked to draws nothing', () {
      final rng = rolls([]);
      expect(
        resolvePersuade(
          persuadable: false,
          enemyLevel: 1,
          casterLevel: 20,
          concentration: 20,
          rng: rng,
        ),
        PersuadeOutcome.immune,
      );
      expect(rng.draws, 0);
    });

    test('독심: a stronger enemy shrugs it off half the time', () {
      PersuadeOutcome cast(List<int> script) => resolvePersuade(
        persuadable: true,
        enemyLevel: 10,
        casterLevel: 5,
        concentration: 15,
        rng: rolls(script),
      );
      expect(cast([0]), PersuadeOutcome.outmatched);
      // (5 - 10) x 2 + 15 = 5.
      expect(cast([1, 5]), PersuadeOutcome.recruited);
      expect(cast([1, 6]), PersuadeOutcome.unmoved);
    });

    test('독심: rand(60) <= (level gap) x 2 + concentration', () {
      PersuadeOutcome cast(int roll) => resolvePersuade(
        persuadable: true,
        enemyLevel: 3,
        casterLevel: 5,
        concentration: 15,
        rng: rolls([roll]),
      );
      expect(cast(19), PersuadeOutcome.recruited);
      expect(cast(20), PersuadeOutcome.unmoved);
    });

    test('수소 핵융합: concentration x level', () {
      expect(fusionDamage(concentration: 15, level: 5), 75);
    });

    test('공포 생성: every branch leaves a mark', () {
      final resisted = enemy('orc_soldier'); // magic resistance 5
      expect(
        castFear(target: resisted, concentration: 15, rng: rolls([4])),
        EspEffect.resistanceLowered,
      );
      expect(resisted.magicResistance, 0);
      expect(resisted.physicalResistance, 0);

      final shaken = enemy('orc_soldier');
      expect(
        castFear(target: shaken, concentration: 15, rng: rolls([5, 16])),
        EspEffect.enduranceLowered,
      );
      expect(shaken.endurance, 7);

      final gone = enemy('orc_soldier');
      expect(
        castFear(target: gone, concentration: 15, rng: rolls([5, 15])),
        EspEffect.fled,
      );
    });

    test('환상 생성: two independent rolls', () {
      final hunter = enemy('troll_hunter'); // accuracy 20/0, resist 0
      expect(
        castIllusion(target: hunter, concentration: 15, rng: rolls([14, 0])),
        EspEffect.accuracyLowered,
      );
      expect(hunter.accuracyPhysical, 16);
      expect(hunter.accuracyMagic, 0);

      final wizard = enemy('kobold_wizard'); // resist 50, agility 15
      expect(
        castIllusion(target: wizard, concentration: 15, rng: rolls([15, 39])),
        EspEffect.agilityLowered,
      );
      expect(wizard.agility, 10);

      final both = enemy('kobold_wizard');
      expect(
        castIllusion(target: both, concentration: 15, rng: rolls([0, 0])),
        EspEffect.accuracyAndAgilityLowered,
      );
      expect(
        castIllusion(
          target: enemy('troll_hunter'),
          concentration: 15,
          rng: rolls([15, 0]),
        ),
        EspEffect.none,
      );
    });

    test('신진 대사 조절: poisons, then tears into the poisoned', () {
      final t = enemy('zombie');
      expect(
        castMetabolism(target: t, concentration: 15, rng: rolls([16])),
        EspEffect.none,
      );
      expect(
        castMetabolism(target: t, concentration: 15, rng: rolls([15])),
        EspEffect.poisoned,
      );
      expect(t.poison, 1);
      expect(
        castMetabolism(target: t, concentration: 15, rng: rolls([0])),
        EspEffect.heavyDamage,
      );
      expect(espHeavyDamage, 5000);
    });

    test('유체 이탈: resisted, hurt, or dropped outright', () {
      final resisted = enemy('orc_warrior'); // resist 25/25
      expect(
        castAstral(target: resisted, concentration: 15, rng: rolls([24])),
        EspEffect.resistanceLowered,
      );
      expect(resisted.magicResistance, 5);
      expect(resisted.physicalResistance, 5);
      expect(
        castAstral(
          target: enemy('orc_soldier'),
          concentration: 15,
          rng: rolls([5, 16]),
        ),
        EspEffect.heavyDamage,
      );
      expect(
        castAstral(
          target: enemy('orc_soldier'),
          concentration: 15,
          rng: rolls([5, 15]),
        ),
        EspEffect.struckDown,
      );
    });
  });

  group('summoning (ch.9.7)', () {
    test('the cost follows attack magic\'s curve - the fork\'s own choice', () {
      expect(summonCost(skill: 100, tier: 10), 1000);
      expect(summonCost(skill: 100, tier: 1), 10);
      expect(summonCost(skill: 30, tier: 3), 27);
      expect(
        summonCost(skill: 70, tier: 7),
        attackMagicCost(skill: 70, tier: 7),
      );
    });

    test('level is skill / 5; tiers are skill / 10', () {
      expect(summonLevel(100), 20);
      expect(summonLevel(10), 2);
      expect(summonLevel(4), 1);
      expect(castableSummonTiers(35), [1, 2, 3]);
      expect(castableSummonTiers(9), isEmpty);
      expect(summonTiers.keys, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('whatever answers sits in the sixth seat, whole and still', () {
      for (var tier = 1; tier <= 10; tier++) {
        for (var seed = 0; seed < 40; seed++) {
          final rng = SeededRng(seed);
          final pick = pickSummon(tier, rng);
          final s = rollSummon(
            spec: pick.spec,
            form: pick.form,
            summonSkill: 100,
            rng: rng,
          );
          final why = 'tier $tier seed $seed ${s.nameKey}';
          expect(s.slot, assistantSeat, reason: why);
          expect(s.name, isEmpty, reason: why);
          expect(s.nameKey, startsWith('summon.'), reason: why);
          expect(s.agility, 0, reason: why);
          expect(s.level, 20, reason: why);
          expect(s.hp, s.endurance * 20 * 10, reason: why);
          expect(s.hp, s.maxHp, reason: why);
          expect(s.weaponPower, greaterThan(0), reason: why);
          expect(weaponTable, contains(s.weaponKey), reason: why);
          expect(s.weaponNameKey, isNotEmpty, reason: why);
          // "10±5" unless the row says otherwise.
          expect(s.strength, inInclusiveRange(2, 17), reason: why);
          expect(s.luck, inInclusiveRange(5, 15), reason: why);
        }
      }
    });

    test('the fire spirit is the one elemental that strikes one enemy', () {
      final rng = SeededRng(3);
      final pick = pickSummon(1, rng);
      final fire = rollSummon(
        spec: pick.spec,
        form: pick.form,
        summonSkill: 50,
        rng: rng,
      );
      expect(fire.family, Family.elemental);
      expect(fire.attacksAll, isFalse);
      expect(fire.ac, 0);
      expect(fire.weaponPower, 150); // S x 3
      expect(fire.level, 10);

      final water = pickSummon(2, SeededRng(3));
      final wave = rollSummon(
        spec: water.spec,
        form: water.form,
        summonSkill: 50,
        rng: SeededRng(9),
      );
      expect(wave.attacksAll, isTrue);
      expect(wave.ac, 1);
      expect(wave.weaponPower, 100); // S x 2
      expect(wave.endurance, inInclusiveRange(3, 13));
      expect(wave.resistance, inInclusiveRange(7, 17));
    });

    test('the dead come back as a knight or a mage', () {
      final seen = <String>{};
      for (var seed = 0; seed < 40; seed++) {
        final rng = SeededRng(seed);
        final pick = pickSummon(5, rng);
        final s = rollSummon(
          spec: pick.spec,
          form: pick.form,
          summonSkill: 60,
          rng: rng,
        );
        seen.add(s.nameKey);
        if (s.nameKey == 'summon.ancient_knight') {
          expect(s.family, Family.fighter);
          expect(s.classId, ClassId.knight);
          expect(s.attacksAll, isFalse);
          expect(s.skills[SkillIndex.slash], 60);
          expect(s.skills[SkillIndex.shield], 60);
          expect(s.shieldPower, 2);
          expect(s.weaponPower, inInclusiveRange(50, 70));
          expect(s.ac, inInclusiveRange(2, 4));
          expect(s.mp, 0);
        } else {
          expect(s.family, Family.mage);
          expect(s.attacksAll, isTrue);
          expect(s.weaponPower, 2);
          // The new level, not the old assistant's (appendix A #13).
          expect(s.mp, s.mentality * 12);
          expect(s.maxMp, s.mp);
        }
      }
      expect(seen, {'summon.ancient_knight', 'summon.ancient_mage'});
    });

    test('golems sweep, giants and dragons do not; a breath is S x 1..5', () {
      for (var seed = 0; seed < 30; seed++) {
        final rng = SeededRng(seed);
        final golem = pickSummon(8, rng);
        expect(golem.spec.family, Family.golem);
        expect(golem.spec.attacksAll, isTrue);
        final giant = pickSummon(7, rng);
        expect(giant.spec.family, Family.giant);
        expect(giant.spec.attacksAll, isFalse);
        final pick = pickSummon(9, rng);
        final dragon = rollSummon(
          spec: pick.spec,
          form: pick.form,
          summonSkill: 90,
          rng: rng,
        );
        expect(dragon.family, Family.dragon);
        expect(dragon.attacksAll, isFalse);
        expect(dragon.weaponPower % 90, 0);
        expect(dragon.weaponPower ~/ 90, inInclusiveRange(1, 5));
        expect(dragon.endurance, inInclusiveRange(20, 40));
        expect(dragon.ac, 3);
      }
    });

    test('the lycanthropes have no spread at all', () {
      for (var seed = 0; seed < 20; seed++) {
        final rng = SeededRng(seed);
        final pick = pickSummon(10, rng);
        final s = rollSummon(
          spec: pick.spec,
          form: pick.form,
          summonSkill: 100,
          rng: rng,
        );
        if (s.nameKey == 'summon.werewolf') {
          expect(
            [s.endurance, s.resistance, s.accuracy, s.ac],
            [25, 15, 18, 2],
          );
          expect(s.weaponPower, 300);
          expect(s.family, Family.unknown);
        } else {
          expect(s.nameKey, 'summon.dragon_newt');
          expect(
            [s.endurance, s.resistance, s.accuracy, s.ac],
            [30, 18, 19, 4],
          );
          expect(s.weaponPower, 450); // S x 4.5
          expect(s.family, Family.dragon);
        }
      }
    });

    test('the summoning crystal: dragon one time in three, level 30', () {
      expect(pickCrystalSummon(rolls([0])), same(crystalDragon));
      expect(pickCrystalSummon(rolls([1])), same(crystalGolem));
      expect(pickCrystalSummon(rolls([2])), same(crystalGolem));
      final dragon = rollSummon(
        spec: crystalDragon,
        form: crystalDragon.forms.single,
        summonSkill: 0,
        rng: rolls([]),
      );
      expect(dragon.level, 30);
      expect(dragon.hp, 30 * 300);
      expect(dragon.weaponPower, 255);
      expect(dragon.ac, 4);
      expect(dragon.immuneToMindControl, isTrue);
      expect(dragon.attacksAll, isFalse);
      final golem = rollSummon(
        spec: crystalGolem,
        form: crystalGolem.forms.single,
        summonSkill: 0,
        rng: rolls([]),
      );
      expect(golem.hp, 40 * 300);
      expect(golem.weaponPower, 150);
      expect(golem.attacksAll, isTrue);
      expect(golem.immuneToMindControl, isTrue);
    });

    test('a persuaded enemy converts by ch.7.8\'s table', () {
      final joined = recruitFromEnemy(enemy('orc_soldier'));
      expect(joined.slot, assistantSeat);
      expect(joined.nameKey, 'enemy.3.orc_soldier');
      expect(joined.family, Family.unknown);
      expect(joined.attacksAll, isFalse);
      expect(joined.level, 3);
      expect(joined.strength, 10);
      expect(joined.endurance, 12);
      expect(joined.agility, 8);
      expect(joined.concentration, 0);
      expect(joined.resistance, 2); // 5 / 2
      expect(joined.accuracy, 9);
      expect(joined.luck, 10);
      expect(joined.hp, 360);
      expect(joined.mp, 0);
      expect(joined.ac, 2);
      expect(joined.weaponPower, 16); // level x 2 + 10
      // Part 1's worked example: a persuaded Minotaur.
      final minotaur = recruitFromEnemy(enemy('minotaur', episode: 1));
      expect(minotaur.resistance, 20);
      expect(minotaur.weaponPower, 40);
      expect(minotaur.ac, 10);
    });
  });

  group('the enemy decides (ch.8.6)', () {
    EnemyIntent intent(
      List<int> script, {
      EnemySpecial special = EnemySpecial.none,
      int castLevel = 0,
      int strength = 10,
      int agility = 20,
      int acting = 4,
      int accP = 10,
      int accM = 0,
    }) => chooseEnemyIntent(
      special: special,
      castLevel: castLevel,
      strength: strength,
      agility: agility,
      accuracyPhysical: accP,
      accuracyMagic: accM,
      actingEnemies: acting,
      rng: rolls(script),
    );

    test('a special attack needs four enemies able to act', () {
      expect(intent([0], special: EnemySpecial.poison), EnemyIntent.special);
      expect(
        intent([0, 5, 0], special: EnemySpecial.poison, acting: 3),
        EnemyIntent.weapon,
      );
      // rand(50) < min(agility, 20).
      expect(
        intent([20, 5, 0], special: EnemySpecial.poison, agility: 30),
        EnemyIntent.weapon,
      );
    });

    test('no special attack means no roll for one', () {
      // Two draws only: the weapon-versus-magic weighing.
      expect(intent([5, 0]), EnemyIntent.weapon);
    });

    test('weapon or magic, by the two accuracies; no strength, no swing', () {
      expect(intent([0, 5], castLevel: 3, accM: 10), EnemyIntent.cast);
      expect(intent([5, 0], castLevel: 3, strength: 0), EnemyIntent.cast);
      // Nothing to cast: it swings anyway rather than stand there.
      expect(intent([0, 0]), EnemyIntent.weapon);
      // The three healers have neither.
      expect(intent([0, 0], strength: 0, accP: 0), EnemyIntent.idle);
    });

    test('the spell follows the enemy\'s mentality', () {
      ({EnemySpellKind kind, int coefficient}) one(int m) =>
          enemySingleSpell(m);
      expect(one(0).kind, EnemySpellKind.shock);
      expect(one(3).coefficient, 1);
      expect(one(4).kind, EnemySpellKind.chill);
      expect(one(8).coefficient, 2);
      expect(one(9).kind, EnemySpellKind.pain);
      expect(one(10).coefficient, 4);
      expect(one(11).kind, EnemySpellKind.freeze);
      expect(one(14).coefficient, 6);
      expect(one(15).kind, EnemySpellKind.flame);
      expect(one(18).coefficient, 7);
      expect(one(19).kind, EnemySpellKind.lightning);
      expect(one(200).coefficient, 10);

      ({EnemySpellKind kind, int coefficient}) all(int m) => enemyAreaSpell(m);
      expect(all(6).kind, EnemySpellKind.heatWave);
      expect(all(6).coefficient, 1);
      expect(all(7).kind, EnemySpellKind.energy);
      expect(all(12).coefficient, 2);
      expect(all(13).kind, EnemySpellKind.ultrasonic);
      expect(all(16).coefficient, 3);
      expect(all(17).kind, EnemySpellKind.coldSnap);
      expect(all(20).coefficient, 5);
      expect(all(21).kind, EnemySpellKind.fireStorm);
      expect(all(21).coefficient, 8);
    });

    test('spell power and damage', () {
      expect(enemySpellPower(coefficient: 7, level: 10), 350);
      // power - rand(power / 2) - ac x level x (1..10) / 10.
      expect(
        enemySpellDamage(
          power: 350,
          memberAc: 4,
          memberLevel: 5,
          rng: rolls([0, 0]),
        ),
        348,
      );
      expect(
        enemySpellDamage(
          power: 350,
          memberAc: 4,
          memberLevel: 5,
          rng: rolls([174, 9]),
        ),
        156,
      );
      expect(enemySpellMisses(accuracyMagic: 10, rng: rolls([10])), isTrue);
      expect(enemySpellMisses(accuracyMagic: 10, rng: rolls([9])), isFalse);
      // A member's resistance is rolled on 50, not 100.
      expect(memberResistsSpell(resistance: 10, rng: rolls([9])), isTrue);
      expect(memberResistsSpell(resistance: 10, rng: rolls([10])), isFalse);
    });

    EnemySpellPlan ladder(
      int castLevel,
      List<int> script, {
      int hp = 100,
      int maxHp = 100,
      int able = 5,
      int enemies = 4,
      int totalHp = 400,
      int totalMax = 400,
      int partyAc = 3,
    }) => chooseEnemySpell(
      castLevel: castLevel,
      hp: hp,
      maxHp: maxHp,
      level: 10,
      mentality: 20,
      ableMembers: able,
      enemyCount: enemies,
      totalEnemyHp: totalHp,
      totalEnemyMaxHp: totalMax,
      averagePartyAc: partyAc,
      rng: rolls(script),
    );

    test('cast levels 0 to 3', () {
      expect(ladder(0, []), isA<NoSpell>());
      final one = ladder(1, []) as CastAtOne;
      expect(one.target, EnemySpellTarget.anyPresent);
      final two = ladder(2, []) as CastAtOne;
      expect(two.target, EnemySpellTarget.randomConscious);
      // rand(able members) < 2 is a single turn.
      expect(ladder(3, [1]), isA<CastAtOne>());
      expect(ladder(3, [2]), isA<CastAtAll>());
    });

    test('cast level 4 heals itself half the time under 30 percent', () {
      final heal = ladder(4, [0], hp: 29) as HealSelf;
      expect(heal.amount, 10 * 20 * 3);
      expect(ladder(4, [1, 2], hp: 29), isA<CastAtAll>());
      // At 30 percent it does not even roll for it.
      expect(ladder(4, [2], hp: 30), isA<CastAtAll>());
    });

    test('cast level 5 heals its side, or goes for the weakest', () {
      expect(ladder(5, [0], hp: 29), isA<HealSelf>());
      expect(ladder(5, [2]), isA<CastAtAll>());
      final weakest = ladder(5, [0]) as CastAtOne;
      expect(weakest.target, EnemySpellTarget.weakestConscious);
      // Three or more enemies, and under a third of their health.
      final side = ladder(5, [0, 0], totalHp: 133) as HealAllies;
      expect(side.amount, 10 * 20 * 2);
      expect(ladder(5, [0, 1], totalHp: 133), isA<CastAtOne>());
      expect(ladder(5, [0], totalHp: 133, enemies: 2), isA<CastAtOne>());
    });

    test('cast level 6 adds armour breaking and a 40 percent self-heal', () {
      expect(ladder(6, [0], hp: 39), isA<HealSelf>());
      expect(ladder(6, [0], partyAc: 5), isA<BreakArmour>());
      // Armour averaging 4 or less: no roll for it at all.
      expect(ladder(6, [0], partyAc: 4), isA<CastAtOne>());
      // Two times in three it heals a failing side.
      expect(ladder(6, [1], totalHp: 133), isA<HealAllies>());
      expect(ladder(6, [2, 0], totalHp: 133), isA<CastAtOne>());
      expect(ladder(6, [2, 2], totalHp: 133), isA<CastAtAll>());
    });

    test('special attacks: the enemy\'s agility, then the member\'s luck', () {
      SpecialAttackOutcome poison(List<int> script) => resolveSpecialAttack(
        EnemySpecial.poison,
        enemyAgility: 20,
        targetLuck: 10,
        rng: rolls(script),
      );
      expect(poison([21]), SpecialAttackOutcome.failed);
      expect(poison([20, 9]), SpecialAttackOutcome.evaded);
      expect(poison([20, 10]), SpecialAttackOutcome.applied);
      expect(specialAttackRange(EnemySpecial.poison), 40);
      expect(specialAttackRange(EnemySpecial.knockOut), 50);
      expect(specialAttackRange(EnemySpecial.slay), 60);
    });

    test('Part 3\'s abilities: when each one fires', () {
      expect(mindControlFires(rolls([0])), isTrue);
      expect(mindControlFires(rolls([1])), isFalse);

      final noRoll = rolls([]);
      expect(armourBreakFires(averagePartyAc: 4, rng: noRoll), isFalse);
      expect(noRoll.draws, 0);
      expect(armourBreakFires(averagePartyAc: 5, rng: rolls([0])), isTrue);
      expect(armourBreakFires(averagePartyAc: 5, rng: rolls([4])), isFalse);
      expect(armourBreakResisted(luck: 10, rng: rolls([9])), isTrue);
      expect(armourBreakResisted(luck: 10, rng: rolls([10])), isFalse);

      // Fewer than rand(3) + 2 still able to act.
      expect(summonAllyFires(actingEnemies: 1, rng: rolls([0])), isTrue);
      expect(summonAllyFires(actingEnemies: 4, rng: rolls([2])), isFalse);
      expect(summonAllyFires(actingEnemies: 3, rng: rolls([2])), isTrue);

      // Only against a full party: rand(3) + 5 or more.
      expect(massStatusFires(ableMembers: 5, rng: rolls([0])), isTrue);
      expect(massStatusFires(ableMembers: 4, rng: rolls([0])), isFalse);
      expect(massStatusFires(ableMembers: 6, rng: rolls([2])), isFalse);

      expect(massStatusRange(EnemyAbility.massPoison), 40);
      expect(massStatusRange(EnemyAbility.massStun), 30);
      expect(massStatusRange(EnemyAbility.massDeath), 22);
      expect(
        massStatusCatches(
          ability: EnemyAbility.massDeath,
          luck: 10,
          rng: rolls([11]),
        ),
        isTrue,
      );
      expect(
        massStatusCatches(
          ability: EnemyAbility.massDeath,
          luck: 10,
          rng: rolls([10]),
        ),
        isFalse,
      );
      expect(healAllAmount(level: 10, mentality: 20), 800);
    });

    test('who each summoner calls', () {
      expect(pickSummonedAlly('draconian_king', rolls([])), 50);
      expect(pickSummonedAlly('lord_ahn', rolls([])), 71);
      expect(pickSummonedAlly('kobold_king', rolls([0])), 39);
      expect(pickSummonedAlly('kobold_king', rolls([1])), 41);
      expect(pickSummonedAlly('troll_necromancer', rolls([4])), 5);
      expect(pickSummonedAlly('summoner_shaman', rolls([0])), 6);
      expect(pickSummonedAlly('summoner_dracon', rolls([4])), 15);
      // Anyone else: one of the first fifteen.
      expect(pickSummonedAlly('archdraconian', rolls([14])), 15);
      for (final ids in summonAllyCandidates.values) {
        for (final id in ids) {
          expect(enemyByLegacyId(3, id), isNotNull);
        }
      }
    });

    test('Parts 1 and 2: the supernatural grade', () {
      // Thinned out below rand(3) + 2, and then one time in three.
      expect(gradeSummonFires(notDeadEnemies: 1, rng: rolls([0, 0])), isTrue);
      expect(gradeSummonFires(notDeadEnemies: 1, rng: rolls([0, 1])), isFalse);
      expect(gradeSummonFires(notDeadEnemies: 4, rng: rolls([2])), isFalse);
      // A row 17 to 20 below its own number.
      expect(gradeSummonedLegacyId(casterLegacyId: 71, rng: rolls([0])), 51);
      expect(gradeSummonedLegacyId(casterLegacyId: 71, rng: rolls([3])), 54);
      expect(
        gradeSummonedLegacyId(casterLegacyId: 10, rng: rolls([0])),
        isNull,
      );
      expect(gradeAbductFires(notDeadEnemies: 6, rng: rolls([0])), isTrue);
      expect(gradeAbductFires(notDeadEnemies: 7, rng: rolls([])), isFalse);
      expect(
        gradeMassSlayFires(special: EnemySpecial.slay, rng: rolls([0])),
        isTrue,
      );
      expect(
        gradeMassSlayFires(special: EnemySpecial.none, rng: rolls([])),
        isFalse,
      );
    });
  });

  group('flight, falling and what it pays', () {
    test('rand(50) > agility fails; each step of gap is worth 15', () {
      expect(escapeSucceeds(agility: 10, rng: rolls([10])), isTrue);
      expect(escapeSucceeds(agility: 10, rng: rolls([11])), isFalse);
      expect(escapeSucceeds(agility: 10, gap: 2, rng: rolls([40])), isTrue);
      expect(escapeSucceeds(agility: 10, gap: 2, rng: rolls([41])), isFalse);
      expect(escapeChancePercent(agility: 10), 22);
      expect(escapeChancePercent(agility: 49), 100);
    });

    test('a fallen member\'s counters keep taking it', () {
      // Standing -> unconscious at zero.
      final dropped = applyMemberDamage(
        hp: 30,
        unconscious: 0,
        dead: 0,
        amount: 100,
        deathThreshold: 75,
      );
      expect(dropped.outcome, VitalsOutcome.collapsed);
      expect([dropped.hp, dropped.unconscious, dropped.dead], [0, 1, 0]);
      // Unconscious -> the counter grows; past endurance x level, dead.
      final deeper = applyMemberDamage(
        hp: 0,
        unconscious: 1,
        dead: 0,
        amount: 74,
        deathThreshold: 75,
      );
      expect(deeper.outcome, VitalsOutcome.deepened);
      expect(deeper.unconscious, 75);
      final died = applyMemberDamage(
        hp: 0,
        unconscious: 75,
        dead: 0,
        amount: 1,
        deathThreshold: 75,
      );
      expect(died.outcome, VitalsOutcome.died);
      expect(died.dead, 1);
      // Dead -> the death counter grows, which is what raising costs.
      final worse = applyMemberDamage(
        hp: 0,
        unconscious: 76,
        dead: 1,
        amount: 40,
        deathThreshold: 75,
      );
      expect(worse.dead, 41);
      // Battle poison stops feeding it at 10000.
      final capped = applyMemberDamage(
        hp: 0,
        unconscious: 76,
        dead: 10000,
        amount: 3,
        deathThreshold: 75,
        deadCap: battlePoisonDeadCap,
      );
      expect(capped.dead, 10000);
      expect(unconsciousDeathThreshold(endurance: 15, level: 5), 75);
    });

    test('enemy poison is 50 a round, 1 in Part 1', () {
      expect(enemyPoisonTick(3), 50);
      expect(enemyPoisonTick(2), 50);
      expect(enemyPoisonTick(1), 1);
    });

    test('experience is level cubed; gold is that times armour', () {
      expect(knockOutExperience(enemyLevel: 3), 27);
      expect(knockOutExperience(enemyLevel: 30), 27000);
      expect(goldFor(enemyLevel: 3, enemyAc: 2), 54);
      expect(goldFor(enemyLevel: 7, enemyAc: 0), 343);
      expect(goldFor(enemyLevel: 30, enemyAc: 8), 216000);
    });
  });

  group('the skill ids', () {
    test('category x 100 + tier, both ways', () {
      expect(skillId(SkillCategory.attackOne, 3), 103);
      expect(skillId(SkillCategory.summon, 10), 610);
      expect(categoryOfSkill(103), SkillCategory.attackOne);
      expect(categoryOfSkill(210), SkillCategory.attackAll);
      expect(categoryOfSkill(300), SkillCategory.special);
      expect(categoryOfSkill(410), SkillCategory.cure);
      expect(categoryOfSkill(506), SkillCategory.esp);
      expect(categoryOfSkill(601), SkillCategory.summon);
      expect(tierOfSkill(407), 7);
      // Not skills.
      expect(categoryOfSkill(100), isNull);
      expect(categoryOfSkill(111), isNull);
      expect(categoryOfSkill(507), isNull);
      expect(categoryOfSkill(45), isNull);
      expect(categoryOfSkill(700), isNull);
    });

    test('scope, targeting and cost of each kind', () {
      const m = CombatantSnapshot(
        slot: 0,
        name: 'm',
        family: Family.mage,
        level: 5,
        skills: [100, 100, 100, 100, 100, 100],
        hp: 1,
        maxHp: 1,
      );
      expect(scopeOf(101), SkillScope.oneEnemy);
      expect(scopeOf(201), SkillScope.allEnemies);
      expect(scopeOf(303), SkillScope.curse);
      expect(scopeOf(402), SkillScope.oneAlly);
      expect(scopeOf(407), SkillScope.allAllies);
      expect(scopeOf(502), SkillScope.allEnemies);
      expect(scopeOf(503), SkillScope.oneEnemy);
      expect(scopeOf(604), SkillScope.summon);
      expect(resourceOf(503), SkillResource.esp);
      expect(resourceOf(103), SkillResource.mp);
      expect(targetingOf(604), SkillTargeting.none);

      expect(costOf(103, m), (cost: 90, perTarget: false));
      expect(costOf(203, m), (cost: 90, perTarget: true));
      expect(costOf(301, m), (cost: 200, perTarget: false));
      expect(costOf(310, m), (cost: 400, perTarget: true));
      expect(costOf(401, m), (cost: 10, perTarget: false));
      expect(costOf(402, m), (cost: 15, perTarget: false));
      // Waking and raising are priced by the target.
      expect(costOf(403, m).cost, -1);
      expect(costOf(404, m).cost, -1);
      expect(costOf(406, m), (cost: 10, perTarget: true));
      expect(costOf(506, m), (cost: 1000, perTarget: false));
      expect(costOf(605, m), (cost: 250, perTarget: false));

      final options = skillOptions(m, mp: 100, episode: 3);
      expect(options, hasLength(56));
      final byId = {for (final o in options) o.magicId: o};
      expect(byId[103]!.affordable, isTrue);
      expect(byId[104]!.affordable, isFalse);
      expect(byId[403]!.affordable, isTrue);
      expect(byId[501]!.resource, SkillResource.esp);
    });

    test('a mage\'s list by family, and Part 1\'s two classes cast too', () {
      const esper = CombatantSnapshot(
        slot: 0,
        name: 'e',
        family: Family.fighter,
        classId: ClassId.esper,
        skills: [0, 0, 0, 0, 40, 0],
        hp: 1,
        maxHp: 1,
      );
      expect(esper.isCaster, isTrue);
      expect(castableSkills(esper, episode: 1), [501, 502, 503]);
    });
  });
}
