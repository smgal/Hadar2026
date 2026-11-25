import 'package:lore_battle/lore_battle.dart';
import 'package:test/test.dart';

import '../support/party.dart';

EnemyData row(int episode, String key) => enemyByKey(episode, key)!;

void main() {
  group('three tables, one per part', () {
    test('row counts are 75, 75 and 74', () {
      expect(enemyTableEp1, hasLength(75));
      expect(enemyTableEp2, hasLength(75));
      expect(enemyTableEp3, hasLength(74));
      expect(enemyTableFor(1), same(enemyTableEp1));
      expect(enemyTableFor(2), same(enemyTableEp2));
      expect(enemyTableFor(3), same(enemyTableEp3));
      expect(() => enemyTableFor(4), throwsArgumentError);
    });

    test('keys are unique and snake_case within each table', () {
      final shape = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final episode in const [1, 2, 3]) {
        final table = enemyTableFor(episode);
        expect({for (final e in table) e.key}, hasLength(table.length));
        for (final e in table) {
          expect(shape.hasMatch(e.key), isTrue, reason: e.key);
        }
      }
    });

    test('legacy ids are the original numbers, 1-based and in order', () {
      for (final episode in const [1, 2, 3]) {
        final table = enemyTableFor(episode);
        expect(
          [for (final e in table) e.legacyId],
          [for (var i = 1; i <= table.length; i++) i],
        );
        expect(enemyByLegacyId(episode, 1), same(table.first));
        expect(enemyByLegacyId(episode, 0), isNull);
      }
    });

    test('hit points follow each part\'s own formula', () {
      // Part 1: endurance x level. Parts 2 and 3: x 10.
      for (final episode in const [1, 2, 3]) {
        for (final e in enemyTableFor(episode)) {
          expect(
            e.hp,
            e.endurance * e.level * enemyHpScale(episode),
            reason: 'ep$episode ${e.key}',
          );
        }
      }
      expect(enemyHpScale(1), 1);
      expect(enemyHpScale(2), 10);
      expect(enemyHpScale(3), 10);
    });

    test('the same key in two parts is two different rows', () {
      expect(row(1, 'orc').hp, 8);
      expect(row(2, 'orc').hp, 80);
      expect(row(1, 'draconian').legacyId, 62);
      expect(row(3, 'draconian').legacyId, 48);
      expect(row(1, 'draconian').level, 19);
      expect(row(3, 'draconian').level, 12);
      // And a key of one part is not a key of another.
      expect(enemyByKey(1, 'orc_soldier'), isNull);
      expect(enemyByKey(3, 'neo_necromancer'), isNull);
      expect(enemyByKey(2, 'neo_necromancer'), isNull);
    });
  });

  group('Part 3 spot checks (ch.12.2)', () {
    test('19 오크병사', () {
      final e = row(3, 'orc_soldier');
      expect(e.legacyId, 19);
      expect(e.level, 3);
      expect(e.strength, 10);
      expect(e.mentality, 0);
      expect(e.endurance, 12);
      expect(e.physicalResistance, 5);
      expect(e.magicResistance, 5);
      expect(e.agility, 8);
      expect(e.accuracyPhysical, 9);
      expect(e.accuracyMagic, 0);
      expect(e.ac, 2);
      expect(e.special, EnemySpecial.none);
      expect(e.castLevel, 0);
      expect(e.abilities, isEmpty);
      expect(e.hp, 360);
      expect(e.persuadable, isTrue);
    });

    test('1 저승사자 pays no gold', () {
      final e = row(3, 'death_messenger');
      expect(e.legacyId, 1);
      expect(e.special, EnemySpecial.poison);
      expect(e.physicalResistance, 100);
      expect(e.magicResistance, 0);
      expect(e.givesGold, isFalse);
    });

    test('22 오크아키메이지 carries an undefined special and uses none', () {
      final e = row(3, 'orc_archmage');
      expect(e.special, EnemySpecial.none);
      expect(e.castLevel, 4);
      expect(EnemySpecial.fromWire(4), EnemySpecial.none);
      expect(EnemySpecial.fromWire(2), EnemySpecial.knockOut);
    });

    test('43 대제사장 has magic resistance 255', () {
      final e = row(3, 'high_priest');
      expect(e.magicResistance, 255);
      expect(e.abilities, {EnemyAbility.healAll});
      expect(e.castLevel, 5);
    });

    test('45 코볼트킹', () {
      final e = row(3, 'kobold_king');
      expect(e.level, 15);
      expect(e.strength, 0);
      expect(e.mentality, 25);
      expect(e.accuracyMagic, 30);
      expect(e.castLevel, 6);
      expect(e.abilities, {
        EnemyAbility.mindControl,
        EnemyAbility.summonAlly,
        EnemyAbility.healAll,
      });
      expect(e.hp, 3750);
    });

    test('59 드라코니안킹 and 73 · 74 로드안', () {
      final king = row(3, 'draconian_king');
      expect(king.abilities, {
        EnemyAbility.mindControl,
        EnemyAbility.armourBreak,
        EnemyAbility.summonAlly,
        EnemyAbility.massDeath,
        EnemyAbility.healAll,
      });
      final ahn = row(3, 'lord_ahn');
      expect(ahn.legacyId, 73);
      expect(ahn.level, 60);
      expect(ahn.hp, 120000);
      expect(ahn.agedByCrystals, isTrue);
      final old = row(3, 'lord_ahn_795');
      expect(old.legacyId, 74);
      expect(old.hp, 36000);
      expect(old.physicalResistance, 160);
    });

    test('the four revenants hide among images', () {
      for (final key in const [
        'orc_revenant',
        'troll_revenant',
        'kobold_revenant',
        'dracon_revenant',
      ]) {
        expect(row(3, key).abilities, {EnemyAbility.clone}, reason: key);
        expect(row(3, key).level, 25);
      }
    });

    test('the three healers end their turn after healing', () {
      expect(
        {
          for (final e in enemyTableEp3)
            if (e.endsTurnAfterHealAll) e.key,
        },
        {'dark_sorcerer', 'dark_healer', 'ice_elemental'},
      );
    });

    test('the persuadable ones are the sixteen ch.9.6 lists', () {
      expect(
        {
          for (final e in enemyTableEp3)
            if (e.persuadable) e.legacyId,
        },
        {6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 18, 19, 25, 26, 47, 64},
      );
    });

    test('experience and gold come out as the document prints them', () {
      // level³, and level³ x max(ac, 1).
      final soldier = row(3, 'orc_soldier');
      expect(knockOutExperience(enemyLevel: soldier.level), 27);
      expect(goldFor(enemyLevel: soldier.level, enemyAc: soldier.ac), 54);
      final ahn = row(3, 'lord_ahn');
      expect(knockOutExperience(enemyLevel: ahn.level), 216000);
      expect(goldFor(enemyLevel: ahn.level, enemyAc: ahn.ac), 4320000);
      // Armour 0 still pays level³.
      final wraith = row(3, 'wraith');
      expect(wraith.ac, 0);
      expect(goldFor(enemyLevel: wraith.level, enemyAc: wraith.ac), 512);
    });
  });

  group('Part 1 spot checks (1st/08 8.1)', () {
    test('1 오크, 35 스프라이트, 50 스테노, 75 네오 네크로만서', () {
      final orc = row(1, 'orc');
      expect([orc.level, orc.hp, orc.strength, orc.ac], [1, 8, 8, 1]);
      expect(orc.physicalResistance, 0);

      final sprite = row(1, 'sprite');
      expect(sprite.legacyId, 35);
      expect(sprite.hp, 18);
      expect(sprite.strength, 0);
      expect(sprite.special, EnemySpecial.slay);
      expect(sprite.castLevel, 5);
      expect(sprite.persuadable, isTrue);
      // One resistance column, carried by both fields.
      expect(sprite.physicalResistance, 80);
      expect(sprite.magicResistance, 80);

      final stheno = row(1, 'stheno');
      expect(stheno.physicalResistance, 255);
      expect(stheno.ac, 255);
      expect(stheno.special, EnemySpecial.poison);

      final neo = row(1, 'neo_necromancer');
      expect(neo.legacyId, 75);
      expect(neo.level, 30);
      expect(neo.hp, 1800);
      expect(neo.superLevel, 3);
      expect(neo.castLevel, 6);
      expect(neo.abilities, isEmpty);
    });

    test('the twelve persuadable rows, Draconian judged as level 17', () {
      expect(
        {
          for (final e in enemyTableEp1)
            if (e.persuadable) e.legacyId,
        },
        {6, 10, 20, 24, 27, 29, 33, 35, 40, 47, 53, 62},
      );
      expect(row(1, 'draconian').persuadeLevel, 17);
      expect(row(1, 'giant').persuadeLevel, isNull);
    });
  });

  group('Part 2 spot checks (2nd/08 8.1)', () {
    test('the slots are Part 1\'s with ten times the hit points', () {
      for (var id = 1; id <= 69; id++) {
        final one = enemyByLegacyId(1, id)!;
        final two = enemyByLegacyId(2, id)!;
        expect(two.hp, one.hp * 10, reason: 'row $id');
        expect(two.level, one.level, reason: 'row $id');
        expect(two.strength, one.strength, reason: 'row $id');
      }
    });

    test('70..75 are Part 2\'s own people', () {
      expect(
        [for (var id = 70; id <= 75; id++) enemyByLegacyId(2, id)!.key],
        [
          'southern_cross_warrior',
          'armored_viper',
          'belial',
          'moloch',
          'asmodeus',
          'mephistopheles',
        ],
      );
      final belial = row(2, 'belial');
      expect(belial.level, 27);
      expect(belial.hp, 9450);
      expect(belial.accuracyPhysical, 10);
      expect(belial.accuracyMagic, 25);
      expect(belial.castLevel, 6);
      expect(belial.superLevel, 1);
      expect(row(2, 'mephistopheles').hp, 18000);
      expect(row(2, 'southern_cross_warrior').persuadeLevel, 17);
    });

    test('59 도마뱀 인간', () {
      final e = row(2, 'lizard_man');
      expect(e.legacyId, 59);
      expect(e.level, 17);
      expect(e.hp, 5100);
      expect(e.special, EnemySpecial.knockOut);
    });
  });

  group('variants - a row fielded under another name', () {
    test('every variant resolves to a real row of its own part', () {
      for (final episode in const [1, 2, 3]) {
        for (final entry in enemyVariantsFor(episode).entries) {
          expect(
            enemyByKey(episode, entry.value.baseKey),
            isNotNull,
            reason: 'ep$episode ${entry.key}',
          );
          expect(
            enemyByKey(episode, entry.key),
            isNull,
            reason: 'a variant must not shadow a row: ${entry.key}',
          );
          expect(resolveEnemy(episode, entry.key), isNotNull);
        }
      }
      expect(resolveEnemy(3, 'nobody'), isNull);
    });

    test('트롤매직유저 raises the level and keeps 360 hit points', () {
      final battle = Battle(
        setupFor(
          enemyKeys: const ['troll_magic_user_lv5', 'troll_magic_user_lv6'],
        ),
      );
      expect(battle.enemies[0].level, 5);
      expect(battle.enemies[1].level, 6);
      expect(battle.enemies[0].hp, 360);
      expect(battle.enemies[1].hp, 360);
      expect(battle.enemies[0].nameKey, 'troll_magic_user');
      expect(battle.enemies[0].key, 'orc_magic_user');
    });

    test('the trapped chests raise the level and hit points follow', () {
      final battle = Battle(
        setupFor(enemyKeys: const ['death_messenger_lv30', 'cerberus_lv15']),
      );
      expect(battle.enemies[0].level, 30);
      expect(battle.enemies[0].hp, 10 * 30 * 10);
      expect(battle.enemies[1].level, 15);
      expect(battle.enemies[1].hp, 20 * 15 * 10);
    });

    test('17대 드라콘제왕 is 아키드라코니안 plus 분신', () {
      final battle = Battle(setupFor(enemyKeys: const ['dracon_emperor_17']));
      final e = battle.enemies.single;
      expect(e.abilities, contains(EnemyAbility.clone));
      expect(e.abilities, contains(EnemyAbility.mindControl));
      expect(e.level, 28);
      expect(e.showsAsClone, isTrue);
    });

    test('Part 1: 스핑크스 and 히드라의 머리', () {
      final battle = Battle(
        setupFor(
          episode: 1,
          enemyKeys: const ['sphinx', 'hydra_head', 'hydra_head_2'],
        ),
      );
      final sphinx = battle.enemies[0];
      expect(sphinx.level, 4);
      expect(sphinx.hp, 18);
      expect(sphinx.special, EnemySpecial.none);
      expect(sphinx.experienceLevel, 5);
      expect(sphinx.persuadable, isTrue);
      expect(battle.enemies[1].level, 8);
      expect(battle.enemies[1].hp, 260);
      expect(battle.enemies[2].level, 10);
    });

    test('Part 2: the eighth wisp and the last guardian', () {
      final battle = Battle(
        setupFor(episode: 2, enemyKeys: const ['wisp_eighth', 'last_guardian']),
      );
      expect(battle.enemies[0].hp, 2700);
      expect(battle.enemies[0].castLevel, 6);
      expect(battle.enemies[1].superLevel, 1);
      expect(battle.enemies[1].hp, 10400);
    });
  });

  group('per-enemy overrides', () {
    test('a field left out stays as the table has it', () {
      final battle = Battle(
        setupFor(
          enemyKeys: const ['orc_soldier', 'orc_soldier'],
          enemyOverrides: const {1: EnemyOverride(strength: 99, ac: 7)},
        ),
      );
      expect(battle.enemies[0].strength, 10);
      expect(battle.enemies[1].strength, 99);
      expect(battle.enemies[1].ac, 7);
      expect(battle.enemies[1].level, 3);
      expect(battle.enemies[1].hp, 360);
    });

    test('changing the level recomputes hit points unless hp is pinned', () {
      final battle = Battle(
        setupFor(
          enemyKeys: const ['orc_soldier', 'orc_soldier', 'orc_soldier'],
          enemyOverrides: const {
            0: EnemyOverride(level: 10),
            1: EnemyOverride(level: 10, hp: 50),
            2: EnemyOverride(endurance: 20),
          },
        ),
      );
      expect(battle.enemies[0].hp, 12 * 10 * 10);
      expect(battle.enemies[1].hp, 50);
      expect(battle.enemies[2].hp, 20 * 3 * 10);
    });

    test('every stat can be overridden', () {
      final battle = Battle(
        setupFor(
          enemyKeys: const ['orc_soldier'],
          enemyOverrides: const {
            0: EnemyOverride(
              nameKey: 'draconian_believer',
              displayName: 'Shade',
              level: 4,
              hp: 77,
              strength: 1,
              mentality: 2,
              endurance: 3,
              physicalResistance: 4,
              magicResistance: 5,
              agility: 6,
              accuracyPhysical: 7,
              accuracyMagic: 8,
              ac: 9,
              special: EnemySpecial.slay,
              castLevel: 3,
              abilities: {EnemyAbility.healAll},
              persuadable: false,
              persuadeLevel: 2,
              rewardLevel: 11,
              rewardAc: 12,
              givesGold: false,
              poison: 1,
            ),
          },
        ),
      );
      final e = battle.enemies.single;
      expect(e.nameKey, 'draconian_believer');
      expect(e.displayName, 'Shade');
      expect(
        [
          e.level,
          e.hp,
          e.strength,
          e.mentality,
          e.endurance,
          e.physicalResistance,
          e.magicResistance,
          e.agility,
          e.accuracyPhysical,
          e.accuracyMagic,
          e.ac,
          e.castLevel,
        ],
        [4, 77, 1, 2, 3, 4, 5, 6, 7, 8, 9, 3],
      );
      expect(e.special, EnemySpecial.slay);
      expect(e.abilities, {EnemyAbility.healAll});
      expect(e.persuadable, isFalse);
      expect(e.levelForPersuasion, 2);
      expect(e.experienceLevel, 11);
      expect(e.goldAc, 12);
      expect(e.paysGold, isFalse);
      expect(e.poison, 1);
    });

    test('an override on a variant is laid over the variant\'s own', () {
      final battle = Battle(
        setupFor(
          enemyKeys: const ['troll_magic_user_lv5'],
          enemyOverrides: const {0: EnemyOverride(level: 6, ac: 5)},
        ),
      );
      final e = battle.enemies.single;
      expect(e.level, 6);
      expect(e.ac, 5);
      // Still the variant's name and its pinned hit points.
      expect(e.nameKey, 'troll_magic_user');
      expect(e.hp, 360);
    });

    test('the reward basis changes what a kill pays', () {
      // Paid as level 1, armour 1 - Part 1's camp soldier.
      final battle = Battle(
        setupFor(
          episode: 1,
          party: [knight()],
          enemyKeys: const ['camp_soldier'],
        ),
      );
      final result = runBattle(battle, alwaysAttack);
      expect(result.outcome.resultCode, BattleResultCode.win);
      expect(result.outcome.goldGained, 1);
      final paid = result.events.whereType<ExperienceGained>();
      expect(paid.every((e) => e.amount == 1), isTrue);
    });

    test('an outcome\'s enemy state resumes a battle where it stopped', () {
      final first = Battle(
        setupFor(
          party: [knight(strength: 1, weaponPower: 5)],
          enemyKeys: const ['zombie'],
          seed: 4,
        ),
      );
      // One round, then stop and read the enemy off the live battle.
      playOneRound(first, alwaysAttack);
      final state = first.enemies.single.toState();
      final resumed = Battle(
        setupFor(
          party: [knight()],
          enemyKeys: const ['zombie'],
          enemyOverrides: {0: state.resume},
        ),
      );
      expect(resumed.enemies.single.hp, state.hp);
      expect(state.key, 'zombie');
      expect(state.left, isFalse);
    });
  });
}
