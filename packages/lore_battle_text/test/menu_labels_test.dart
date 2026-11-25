import 'package:lore_battle/lore_battle.dart';
import 'package:lore_battle_text/lore_battle_text.dart';
import 'package:test/test.dart';

CombatantSnapshot _mage(int skill, {int mp = 5000}) => CombatantSnapshot(
  slot: 0,
  name: '리라',
  family: Family.mage,
  level: 5,
  skills: [skill, skill, skill, skill, skill, skill],
  hp: 100,
  maxHp: 100,
  mp: mp,
  maxMp: 5000,
);

void main() {
  group('the six lines', () {
    test('every action has a label', () {
      for (final action in BattleAction.values) {
        expect(actionLabel(action, weaponName: '장검'), isNotEmpty);
      }
      expect(
        actionLabel(BattleAction.attack, weaponName: '장검'),
        contains('장검으로'),
      );
      expect(
        actionLabel(BattleAction.attack, weaponName: '단도'),
        contains('단도로'),
      );
      expect(orderLabel(BattleAction.autoBattle), '일행에게 무조건 공격 할 것을 지시');
      expect(actionMenuHeader('리라'), '리라의 전투 모드 ===>');
    });

    test('cancel means two different things', () {
      expect(cancelLabelFor(const ActionDecision(0, [])), cancelTopLabel);
      expect(cancelLabelFor(const EnemyTargetDecision(0, [])), cancelBackLabel);
    });
  });

  group('the skill list', () {
    test('a beginner sees one short list', () {
      final options = skillOptions(_mage(10), mp: 5000, episode: 3);
      // 공격 1 + 전체 1 + 특수 1 + 치료 1 (초능력은 20부터, 소환 1).
      expect(options.map((o) => o.magicId), [101, 201, 301, 401, 601]);
      expect(skillListFolds(options), isFalse);
    });

    test('a master folds into groups, in list order', () {
      final options = skillOptions(_mage(100), mp: 5000, episode: 3);
      expect(options, hasLength(56));
      expect(skillListFolds(options), isTrue);
      final groups = skillGroups(options);
      expect(
        [for (final g in groups) g.options.length],
        [
          10, // 한 명 공격
          10, // 전체 공격
          5, // 특수 한 명
          5, // 특수 모두
          5, // 치료 한 명
          5, // 치료 모두
          5, // 초능력 한 명 (독심 · 공포 · 환상 · 신진 대사 · 유체 이탈)
          1, // 초능력 전체 (수소 핵융합)
          10, // 소환
        ],
      );
      // 묶음을 다시 펴면 원래 목록이다 — 빠지는 것이 없다.
      expect(
        {for (final g in groups) ...g.options.map((o) => o.magicId)},
        {for (final o in options) o.magicId},
      );
      for (final g in groups) {
        expect(skillGroupLabel(g), isNotEmpty);
        expect(skillGroupHeader(g), endsWith('===>'));
      }
    });

    test('a line shows glyph, name and cost', () {
      final options = skillOptions(_mage(100), mp: 5000, episode: 3);
      SkillOption of(int id) => options.firstWhere((o) => o.magicId == id);
      expect(skillLine(of(101)), contains('🎯 마법 화살'));
      expect(skillLine(of(101)), contains('MP 10'));
      // 전체 공격은 적마다 낸다.
      expect(skillCostLabel(of(201)), 'MP 10×적');
      // 초능력은 같은 마법 지수를 쓴다.
      expect(skillLine(of(502)), contains('🔮 수소 핵융합'));
      expect(skillCostLabel(of(502)), 'MP 100');
      // 의식 돌림은 대상에 따라 다르다.
      expect(skillCostLabel(of(403)), 'MP ~');
      expect(skillCostLabel(of(406)), 'MP 10×명');
      expect(skillLine(of(610)), contains('🌀 라이칸스로프 소환'));
    });

    test('what cannot be paid for stays on the list, dimmed', () {
      final options = skillOptions(_mage(100, mp: 50), mp: 50, episode: 3);
      final fusion = options.firstWhere((o) => o.magicId == 502);
      expect(fusion.affordable, isFalse);
      expect(skillLine(fusion), contains('(부족)'));
      expect(skillLine(fusion), startsWith('@8'));
    });
  });

  group('name colours (ch.8.7)', () {
    int color(int hp, {int episode = 3}) =>
        enemyNameColor(hp: hp, unconscious: 0, dead: 0, episode: episode);

    test('Parts 2 and 3 bands', () {
      expect(color(1), TextColor.lightRed);
      expect(color(199), TextColor.lightRed);
      expect(color(200), TextColor.red);
      expect(color(499), TextColor.red);
      expect(color(500), TextColor.brown);
      expect(color(1000), TextColor.yellow);
      expect(color(2000), TextColor.green);
      expect(color(3999), TextColor.green);
      expect(color(4000), TextColor.lightGreen);
      expect(color(120000), TextColor.lightGreen);
    });

    test('Part 1 bands are a tenth', () {
      expect(color(19, episode: 1), TextColor.lightRed);
      expect(color(20, episode: 1), TextColor.red);
      expect(color(50, episode: 1), TextColor.brown);
      expect(color(100, episode: 1), TextColor.yellow);
      expect(color(200, episode: 1), TextColor.green);
      expect(color(300, episode: 1), TextColor.lightGreen);
    });

    test('unconscious is grey, dead is black', () {
      expect(
        enemyNameColor(hp: 0, unconscious: 1, dead: 0),
        TextColor.darkGray,
      );
      expect(enemyNameColor(hp: 0, unconscious: 1, dead: 1), TextColor.black);
    });

    test('an image and its owner are always bright', () {
      expect(
        enemyNameColor(hp: 1, unconscious: 0, dead: 0, alwaysBright: true),
        TextColor.lightGreen,
      );
      expect(
        enemyNameColor(hp: 0, unconscious: 1, dead: 0, alwaysBright: true),
        TextColor.lightGreen,
      );
    });

    test('party condition colours, worst first', () {
      expect(
        conditionColor(hp: 10, poison: 0, unconscious: 0, dead: 0),
        TextColor.white,
      );
      expect(
        conditionColor(hp: 10, poison: 2, unconscious: 0, dead: 0),
        TextColor.lightMagenta,
      );
      expect(
        conditionColor(hp: 0, poison: 2, unconscious: 5, dead: 0),
        TextColor.lightGray,
      );
      expect(
        conditionColor(hp: 0, poison: 2, unconscious: 5, dead: 1),
        TextColor.darkGray,
      );
    });
  });

  group('reach and order', () {
    test('the verdict says what is being risked', () {
      final spear = weaponFor('spear').attacks.first;
      expect(reachVerdict(attack: spear, distance: 1), contains('닿음'));
      expect(reachVerdict(attack: spear, distance: 3), contains('1칸 부족'));
    });

    test('display order: leader first, then front to back', () {
      CombatantSnapshot m(int slot, int rank) => CombatantSnapshot(
        slot: slot,
        name: 'm$slot',
        hp: 10,
        maxHp: 10,
        rank: rank,
      );
      final battle = Battle(
        BattleSetup(
          party: [m(0, 3), m(1, 2), m(2, 1), m(5, 1)],
          enemyKeys: const ['orc_soldier', 'kobold_wizard'],
          enemyRanks: const [2, 1],
          seed: 1,
        ),
      );
      expect(leaderSlotOf(battle), 0);
      expect(
        [for (final c in partyInDisplayOrder(battle)) c.slot],
        [0, 2, 5, 1],
      );
      expect(enemiesInDisplayOrder(battle), [1, 0]);
    });
  });
}
