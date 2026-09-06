import 'package:hd_battle/hd_battle.dart';

/// 새 전투식의 피해 대역 실측 (B2-99 → **B5-05 로 갱신**).
///
///   dart run tool/damage_band.dart
///
/// 부록 H-2 를 만든 방식과 같이 뽑기 조합을 전수 계산하되, 수식을 복사하지
/// 않고 **출하된 함수를 직접 구동**한다.
///
/// **B5-05 이후 변동원이 하나다.** 예전에는 공격 굴림과 방어 굴림 둘이었는데,
/// 공격 쪽 변동이 회피 배율(`grazeScale`)로 나갔다. 그래서 이 표는
/// 배율 0~100 × 방어 굴림 0~9 를 훑는다.
({double hitRate, int maxDamage, double meanDamage}) band({
  required String enemyKey,
  required int worn,
  int memberLevel = 1,
  int agility = 10,
  int luck = 0,
  int shieldBlock = 0,
}) {
  final e = enemyByKey[enemyKey]!;
  var hits = 0;
  var cases = 0;
  var worst = 0;
  var total = 0;
  final evasion = evasionOf(
    agility: agility,
    luck: luck,
    shieldBlock: shieldBlock,
  );
  for (var roll = 0; roll < 100; roll++) {
    // 회피 배율을 그 상황에서 실제로 나올 값으로 굴린다.
    final graze = grazeScale(
      accuracy: e.accuracy[0],
      evasion: evasion,
      rng: ScriptedRng([roll]),
    );
    for (var defence = 0; defence < 10; defence++) {
      cases++;
      final damage = enemyPhysicalDamage(
        enemyStrength: e.strength,
        enemyLevel: e.level,
        memberAc: worn,
        memberLevelPhysical: memberLevel,
        rng: ScriptedRng([defence]),
        graze: graze,
      );
      if (damage > 0) {
        hits++;
        total += damage;
        if (damage > worst) worst = damage;
      }
    }
  }
  return (
    hitRate: hits * 100 / cases,
    maxDamage: worst,
    meanDamage: total / cases,
  );
}

void main() {
  // ignore: avoid_print
  void say(String s) => print(s);

  say('| 적 | 착용 ac | 피해 발생 % | 평균 피해 | 최대 피해 |');
  say('|---|---|---|---|---|');
  for (final key in ['orc', 'troll', 'giant', 'black_knight']) {
    for (final worn in [0, 2, 5, 10, 20]) {
      final r = band(enemyKey: key, worn: worn);
      say(
        '| ${enemyByKey[key]!.name} | $worn | '
        '${r.hitRate.toStringAsFixed(1)}% | '
        '${r.meanDamage.toStringAsFixed(1)} | ${r.maxDamage} |',
      );
    }
  }
  say('');
  say('아군 → 적 (슴갈: 힘 18 · 무기 10 · 물리 레벨 1, 회피 배율 포함)');
  say('');
  say('| 적 | 피해 발생 % | 평균 피해 | 최대 피해 |');
  say('|---|---|---|---|');
  for (final key in ['orc', 'troll', 'giant', 'black_knight']) {
    final e = enemyByKey[key]!;
    var hits = 0;
    var cases = 0;
    var worst = 0;
    var total = 0;
    for (var roll = 0; roll < 100; roll++) {
      final graze = grazeScale(
        accuracy: 15,
        evasion: evasionOf(agility: e.agility, luck: 0),
        rng: ScriptedRng([roll]),
      );
      for (var defence = 0; defence < 10; defence++) {
        cases++;
        final damage = physicalDamage(
          strength: 18,
          powOfWeapon: 10 * physicalPowerScale,
          levelPhysical: 1,
          enemyAc: e.ac,
          enemyLevel: e.level,
          rng: ScriptedRng([defence]),
          graze: graze,
        );
        if (damage > 0) {
          hits++;
          total += damage;
          if (damage > worst) worst = damage;
        }
      }
    }
    say(
      '| ${e.name} | ${(hits * 100 / cases).toStringAsFixed(1)}% | '
      '${(total / cases).toStringAsFixed(1)} | $worst |',
    );
  }
  say('');
  say('| 방패 블록 | 피해 발생 % | 평균 피해 (Troll, 착용 ac 5) |');
  say('|---|---|---|');
  for (final block in [0, 15, 30, 45, 60, 75, 100]) {
    final r = band(enemyKey: 'troll', worn: 5, shieldBlock: block);
    say(
      '| $block${block > maxShieldBlock ? " (상한 $maxShieldBlock)" : ""} | '
      '${r.hitRate.toStringAsFixed(1)}% | '
      '${r.meanDamage.toStringAsFixed(1)} |',
    );
  }
  say('');
  say('| 마법 순번 | 피해 (레벨 20) | 비용 |');
  say('|---|---|---|');
  for (var i = 1; i <= 6; i++) {
    say(
      '| $i | ${attackSpellPower(spellIndex: i, magicLevel: 20)} | '
      '${attackSpellCost(spellIndex: i, magicLevel: 20)} |',
    );
  }
}
