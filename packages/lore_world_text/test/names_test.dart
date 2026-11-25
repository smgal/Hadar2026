import 'dart:math';

import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart';
import 'package:test/test.dart';

void main() {
  group('조사', () {
    test('받침에 따라 고른다', () {
      expect(josa('카노푸스', '은/는'), '카노푸스는');
      expect(josa('알골', '은/는'), '알골은');
      expect(josa('알골', '으로/로'), '알골로');
      expect(josa('검', '으로/로'), '검으로');
      expect(josa('베가', '이/가'), '베가가');
      expect(josa('미자르', '을/를'), '미자르를');
      expect(josa('장검', '와/과'), '장검과');
    });

    test('쌍의 순서는 상관없다', () {
      expect(josa('카노푸스', '는/은'), '카노푸스는');
      expect(josa('알골', '가/이'), '알골이');
    });

    test('영문과 숫자는 소리를 어림한다', () {
      expect(josa('Joe', '이/가'), 'Joe가');
      expect(josa('Ahn', '이/가'), 'Ahn이');
      expect(josa('안타레스 Jr.', '은/는'), '안타레스 Jr.는');
      expect(josa('50', '이/가'), '50이');
      expect(josa('15', '이/가'), '15가');
      expect(josa('7', '으로/로'), '7로');
    });
  });

  group('이름표에 빠진 것이 없다', () {
    test('계급', () {
      for (final c in classTable) {
        expect(classNames[c.key], isNotNull, reason: c.key);
      }
      expect(classNameOf(Family.fighter, ClassId.paladin), '전사');
      expect(classNameOf(Family.mage, ClassId.timewalker), '타임워커');
      // 계급이 없는 계열은 계열 이름
      expect(classNameOf(Family.golem, 0), '고렘족');
    });

    test('기술치 — 전사의 둘째 자리는 치료 마법', () {
      for (final k in [...fighterSkillKeys, ...mageSkillKeys, 'skill.cure']) {
        expect(skillNames[k], isNotNull, reason: k);
        expect(skillShortNames[k], isNotNull, reason: k);
      }
      expect(skillNameOf(Family.fighter, ClassId.paladin, 1), '치료 마법 능력치');
      expect(skillNameOf(Family.fighter, ClassId.knight, 1), '찍는 무기 기술치');
      expect(skillNameOf(Family.mage, ClassId.mage, 4), '초자연력 능력치');
    });

    test('무기 · 방패 · 갑옷 · 물품 · 크리스탈', () {
      final keys = [
        for (final w in weaponTable) w.key,
        for (final s in shieldTable) s.key,
        for (final a in armourTable) a.key,
        for (final c in consumableTable) c.key,
        for (final c in crystalTable) c.key,
        SupplyKey.gold,
        SupplyKey.food,
        SupplyKey.arrows,
      ];
      for (final k in keys) {
        expect(itemName(k), isNot(k), reason: k);
      }
      expect(itemName('weapon.flamberge'), '프렘버그');
      expect(itemName('armour.obsidian'), '흑요석 갑옷');
    });

    test('마법과 초능력', () {
      for (final s in spellTable) {
        expect(spellNames[s.key], isNotNull, reason: s.key);
      }
      for (final p in FieldEsp.values) {
        expect(spellNames[fieldEspKey(p)], isNotNull, reason: p.name);
      }
    });

    test('세 편의 동료', () {
      for (final ep in Episode.values) {
        for (final key in rosterOf(ep).keys) {
          expect(companionName(ep, key), isNot(key), reason: '${ep.name} $key');
        }
      }
      expect(companionName(Episode.ep3, 'antares_jr'), '안타레스 Jr.');
      expect(companionName(Episode.ep1, 'betelgeuse'), '베텔규스');
    });

    test('소환수와 그 무기', () {
      final defs = [
        for (final pool in summonPools) ...pool,
        ...otherDimensionCreatures,
        crystalDragon,
        crystalGolem,
        archangel,
      ];
      for (final d in defs) {
        expect(nameOf(d.key), isNot(d.key), reason: d.key);
      }
      final summon = buildSummon(crystalDragon, skill: 0, rng: _NoRandom());
      expect(memberName(summon), '크리스탈 드래곤');
      expect(weaponNameOf(summon), isNot(startsWith('natural.')));
      expect(weaponNameOf(summon), isNot(startsWith('breath.')));
    });
  });

  group('memberName', () {
    test('지은 이름이 있으면 그것', () {
      final m = rosterEp3['canopus']!.build()..name = '카노';
      expect(memberName(m), '카노');
    });

    test('명부 인물은 편에 맞는 이름', () {
      expect(memberName(rosterEp3['canopus']!.build()), '카노푸스');
      expect(memberName(rosterEp1['algol']!.build(), episode: Episode.ep1), '알골');
      expect(
        memberName(rosterEp3['draco_prisoner']!.build()),
        '드라코니안 수감자',
      );
    });
  });
}

class _NoRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}
