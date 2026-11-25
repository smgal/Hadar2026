import 'dart:math';

import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

void main() {
  test('ten tiers with the pool sizes of chapter 9.7', () {
    expect(
      [for (final p in summonPools) p.length],
      [4, 9, 5, 3, 2, 8, 6, 4, 12, 2],
    );
  });

  test('names are unique across every pool', () {
    final keys = [
      for (final pool in summonPools)
        for (final d in pool) d.key,
      crystalDragon.key,
      crystalGolem.key,
      archangel.key,
    ];
    expect(keys.toSet().length, keys.length);
    for (final k in keys) {
      expect(k, startsWith('summon.'));
    }
  });

  test('level = S ÷ 5, HP full, agility 0', () {
    final rng = Random(8);
    for (var tier = 1; tier <= 10; tier++) {
      for (var i = 0; i < 20; i++) {
        final m = summonByTier(tier, skill: 60, rng: rng)!;
        expect(m.level, 12, reason: m.nameKey);
        expect(m.hp, m.maxHp, reason: m.nameKey);
        expect(m.agility, 0, reason: m.nameKey);
        expect(m.gender, Gender.neutral);
        expect(m.trainedExp, trainedExpForLevel(12));
      }
    }
    expect(summonByTier(0, skill: 60, rng: rng), isNull);
    expect(summonByTier(11, skill: 60, rng: rng), isNull);
  });

  test('rolled abilities stay inside base ± spread', () {
    final rng = Random(21);
    for (var i = 0; i < 300; i++) {
      // 밴더스내치: 인내 15±5, 저항 8±5, 정확 12±5, 나머지 10±5.
      final m = buildSummon(otherDimensionCreatures[0], skill: 50, rng: rng);
      expect(m.endurance, inInclusiveRange(10, 20));
      expect(m.resistance, inInclusiveRange(3, 13));
      expect(m.accuracy, inInclusiveRange(7, 17));
      expect(m.strength, inInclusiveRange(5, 15));
      expect(m.luck, inInclusiveRange(5, 15));
    }
  });

  test('power is S times the multiplier of the row', () {
    final rng = Random(1);
    Member of(String key, int skill) => buildSummon(
      otherDimensionCreatures.firstWhere((d) => d.key == key),
      skill: skill,
      rng: rng,
    );
    expect(of('summon.bandersnatch', 60).weaponPower, 180);
    expect(of('summon.centaur', 60).weaponPower, 90);
    expect(of('summon.demogorgon', 60).weaponPower, 240);
    expect(of('summon.ettin', 60).weaponPower, 48);
    expect(of('summon.demogorgon', 60).ac, 4);
    expect(of('summon.dullahan', 60).resistance, 20);
  });

  test(
    'the fire spirit is an elemental that strikes one; the others sweep',
    () {
      final rng = Random(1);
      expect(
        summonByTier(1, skill: 10, rng: rng)!.attackMode,
        AttackMode.single,
      );
      for (final tier in [2, 3, 4]) {
        final m = summonByTier(tier, skill: 40, rng: rng)!;
        expect(m.family, Family.elemental);
        expect(m.attackMode, AttackMode.all);
      }
      expect(summonByTier(8, skill: 80, rng: rng)!.attackMode, AttackMode.all);
      expect(
        summonByTier(7, skill: 70, rng: rng)!.attackMode,
        AttackMode.single,
      );
      expect(
        summonByTier(9, skill: 90, rng: rng)!.attackMode,
        AttackMode.single,
      );
    },
  );

  test('a dragon breathes S × 1..5', () {
    final rng = Random(4);
    final seen = <int>{};
    for (var i = 0; i < 200; i++) {
      seen.add(summonByTier(9, skill: 90, rng: rng)!.weaponPower);
    }
    expect(seen, {90, 180, 270, 360, 450});
  });

  test(
    'the ancient knight is a knight with a long sword and a small steel shield',
    () {
      final rng = Random(2);
      for (var i = 0; i < 50; i++) {
        final m = buildSummon(summonPools[4][0], skill: 50, rng: rng);
        expect(m.family, Family.fighter);
        expect(m.classId, ClassId.knight);
        expect(m.weapon, 'weapon.long_sword');
        expect(m.weaponKind, WeaponKind.slash);
        expect(m.weaponPower, inInclusiveRange(50, 70));
        expect(m.shieldPower, 2);
        expect(m.skills[FighterSkill.slash], 50);
        expect(m.skills[FighterSkill.shield], 50);
        expect(m.ac, inInclusiveRange(2, 4));
        expect(m.attackMode, AttackMode.single);
      }
    },
  );

  test(
    'the ancient mage sweeps with flame 2 and starts with mentality × level MP',
    () {
      final m = buildSummon(summonPools[4][1], skill: 50, rng: Random(2));
      expect(m.family, Family.mage);
      expect(m.attackMode, AttackMode.all);
      expect(m.weaponPower, 2);
      expect(m.mp, m.mentality * m.level);
    },
  );

  test('the same seed summons the same creature', () {
    Map<String, Object?> run() =>
        summonByTier(6, skill: 60, rng: Random(77))!.toJson();
    expect(run(), run());
  });
}
