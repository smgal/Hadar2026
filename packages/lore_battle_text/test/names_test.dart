import 'package:lore_battle/lore_battle.dart';
import 'package:lore_battle_text/lore_battle_text.dart';
import 'package:test/test.dart';

final _hangul = RegExp(r'[가-힣]');

void main() {
  group('enemy names, one table per part', () {
    test('every row of all three tables has a Korean name', () {
      for (final episode in const [1, 2, 3]) {
        for (final row in enemyTableFor(episode)) {
          final name = enemyName(episode, row.key);
          expect(name, isNot(row.key), reason: 'ep$episode ${row.key}');
          expect(_hangul.hasMatch(name), isTrue, reason: 'ep$episode $name');
        }
      }
    });

    test('the tables are the size the documents say', () {
      expect(enemyNamesEp1, hasLength(75));
      expect(enemyNamesEp2, hasLength(75));
      expect(enemyNamesEp3, hasLength(74));
    });

    test('spot checks against the documents', () {
      expect(enemyName(3, 'orc_soldier'), '오크병사');
      expect(enemyName(3, 'death_messenger'), '저승사자');
      expect(enemyName(3, 'lord_ahn'), '로드안');
      expect(enemyName(1, 'orc'), '오크');
      expect(enemyName(1, 'neo_necromancer'), '네오 네크로만서');
      expect(enemyName(2, 'lizard_man'), '도마뱀 인간');
      expect(enemyName(2, 'mephistopheles'), '메피스토펠레스');
    });

    test('the same key in two parts is two names', () {
      // Part 1 keeps the original's transliteration, Part 2 its own word.
      expect(enemyName(1, 'vampire'), '뱀파이어');
      expect(enemyName(2, 'vampire'), '흡혈귀');
      expect(enemyName(3, 'vampire'), '흡혈귀');
    });

    test('every variant resolves to a name', () {
      for (final episode in const [1, 2, 3]) {
        for (final entry in enemyVariantsFor(episode).entries) {
          final battle = Battle(
            BattleSetup(
              party: const [
                CombatantSnapshot(slot: 0, name: 'a', hp: 10, maxHp: 10),
              ],
              enemyKeys: [entry.key],
              seed: 1,
              episode: episode,
            ),
          );
          final name = enemyDisplayName(battle.enemies.single);
          expect(
            _hangul.hasMatch(name),
            isTrue,
            reason: 'ep$episode ${entry.key} -> $name',
          );
        }
      }
    });

    test('renamed enemies show the alias, not the row they borrow', () {
      final battle = Battle(
        const BattleSetup(
          party: [CombatantSnapshot(slot: 0, name: 'a', hp: 10, maxHp: 10)],
          enemyKeys: ['troll_magic_user_lv5', 'dracon_emperor_17'],
          seed: 1,
        ),
      );
      expect(enemyDisplayName(battle.enemies[0]), '트롤매직유저');
      expect(enemyDisplayName(battle.enemies[1]), '17대 드라콘제왕');
    });

    test('a literal name from the RPG wins', () {
      final battle = Battle(
        const BattleSetup(
          party: [CombatantSnapshot(slot: 0, name: 'a', hp: 10, maxHp: 10)],
          enemyKeys: ['orc_soldier'],
          enemyOverrides: {0: EnemyOverride(displayName: '분신')},
          seed: 1,
        ),
      );
      expect(enemyDisplayName(battle.enemies.single), '분신');
    });
  });

  group('name keys the battle makes up', () {
    test('summons and persuaded enemies resolve', () {
      expect(resolveNameKey('summon.ifrit'), '이프리트');
      expect(resolveNameKey('summon.crystal_golem'), '크리스탈 고렘');
      expect(resolveNameKey('enemy.3.orc_soldier'), '오크병사');
      expect(resolveNameKey('enemy.1.goblin'), '고블린');
    });

    test('every summon form and its weapon has a name', () {
      final specs = [
        for (final tier in summonTiers.values) ...tier,
        crystalDragon,
        crystalGolem,
      ];
      for (final spec in specs) {
        expect(weaponNameKeys, contains(spec.weaponNameKey));
        for (final form in spec.forms) {
          final name = resolveNameKey(form.nameKey);
          expect(_hangul.hasMatch(name), isTrue, reason: form.nameKey);
          if (form.weaponNameKey != null) {
            expect(weaponNameKeys, contains(form.weaponNameKey));
          }
        }
      }
    });

    test('a member is shown by name, else by key', () {
      const named = CombatantSnapshot(slot: 0, name: '리라', hp: 1, maxHp: 1);
      const keyed = CombatantSnapshot(
        slot: 5,
        name: '',
        nameKey: 'summon.gnome',
        weaponNameKey: 'natural.earthquake',
        hp: 1,
        maxHp: 1,
      );
      expect(memberDisplayName(named), '리라');
      expect(memberDisplayName(keyed), '놈');
      expect(weaponDisplayName(keyed), '지진');
      expect(weaponDisplayName(named), '맨손');
    });
  });

  group('skills and items', () {
    test('every skill id has a name', () {
      const everything = CombatantSnapshot(
        slot: 0,
        name: 'a',
        family: Family.mage,
        skills: [100, 100, 100, 100, 100, 100],
        hp: 1,
        maxHp: 1,
      );
      final ids = castableSkills(everything, episode: 1);
      // 10 + 10 + (1 + 10) + 10 + 6 + 10.
      expect(ids, hasLength(57));
      for (final id in ids) {
        expect(magicName(id), isNot('알 수 없는 마법'), reason: '$id');
      }
      expect(magicName(101), '마법 화살');
      expect(magicName(210), '차원 이탈');
      expect(magicName(300), '독');
      expect(magicName(301), '한명 기술 무력화');
      expect(magicName(310), '모두 탈 초인화');
      expect(magicName(405), '한명 복합 치료');
      expect(magicName(406), '모두 치료');
      expect(magicName(501), '독심');
      expect(magicName(506), '유체 이탈');
      expect(magicName(609), '용을 부름');
      expect(magicName(999), '알 수 없는 마법');
    });

    test('every usable item has a name and a glyph', () {
      for (final item in battleItemList) {
        expect(itemNames, contains(item.key));
        expect(itemGlyph(item.key), isNotEmpty);
        expect(itemLine(item.key), contains(itemName(item.key)));
      }
      expect(itemName(ItemKey.ebonyCrystal), '에보니 크리스탈');
    });

    test('every enemy spell has a name', () {
      for (final kind in EnemySpellKind.values) {
        expect(enemySpellNames, contains(kind));
      }
    });
  });

  group('particles follow the final consonant', () {
    test('the pairs', () {
      expect(HDNoun('오크병사').obj, '를');
      expect(HDNoun('드라코니안킹').obj, '을');
      expect(HDNoun('리라').sub1, '는');
      expect(HDNoun('아르젠').sub1, '은');
      // ㄹ 받침은 '로'.
      expect(HDNoun('마법 화살').withJosa, '로');
      expect(HDNoun('공기 폭풍').withJosa, '으로');
    });
  });
}
