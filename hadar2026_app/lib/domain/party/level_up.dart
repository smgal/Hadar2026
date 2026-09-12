/// 레벨이 오르는 규칙.
///
/// ## 왜 앱 쪽인가
///
/// 4차 판정: **전투 중에 레벨이 오르는 일은 없다.** 전투는 레벨을 개시 입력으로
/// 받고 경험치 총량만 돌려주므로 21단 경험치 표가 `packages/hd_battle` 에 아예
/// 없고 `purity_test.dart` 가 그것을 지킨다.
///
/// `packages/hd_world` 에도 두지 않는다 — 표의 값은 이 게임의 밸런스이고
/// 모델은 그것을 몰라야 다른 밸런스로 시험할 수 있다.
library;

import 'package:hd_world/hd_world.dart';

/// 원작의 경험치 표. 자리 n 이 레벨 n 에 필요한 총량이다.
///
/// 21칸이고 마지막이 상한이다 — 그 위로는 오르지 않는다.
const List<int> experienceTable = [
  0,
  0,
  1500,
  6000,
  20000,
  50000,
  150000,
  250000,
  500000,
  800000,
  1050000,
  1320000,
  1620000,
  1950000,
  2310000,
  2700000,
  3120000,
  3570000,
  4050000,
  4560000,
  5100000,
];

/// 오른 뒤의 이야기.
class LevelUpResult {
  const LevelUpResult({required this.gained, required this.toLevel});

  /// 몇 단 올랐나. 0 이면 아무 일도 없었다.
  final int gained;

  /// 오른 뒤의 물리 레벨.
  final int toLevel;

  bool get leveledUp => gained > 0;
}

/// 경험치가 표를 넘었으면 올린다.
///
/// 오르면 능력치가 자라고 **체력·마법·초능력 지수가 최대로 찬다** — 원작이
/// 그렇게 한다. 그래서 **정산이 끝난 뒤에** 불러야 회복분이 전투 결과로
/// 덮이지 않는다.
///
/// 최대치는 이제 장비까지 반영해 읽을 때 계산되므로 여기서 `maxHp` 를 쓰지
/// 않는다. 대신 **기본 최대치**(`baseMax*`)를 올린다 — 그것이 이전 모델이
/// `maxHp = endurance × level` 로 하던 일의 자리다.
LevelUpResult checkLevelUp(Member m, {required ItemCatalog catalog}) {
  var gained = 0;
  while (m.levels.physical < experienceTable.length - 1 &&
      m.experience >= experienceTable[m.levels.physical + 1]) {
    m.levels = m.levels.copyWith(physical: m.levels.physical + 1);

    final s = m.stats;
    m.stats = s.copyWith(
      strength: s.strength + 1 + (s.strength ~/ 10),
      endurance: s.endurance + 2,
      agility: s.agility + 1,
      mentality: s.mentality > 0 ? s.mentality + 1 : s.mentality,
      concentration: s.concentration > 0
          ? s.concentration + 1
          : s.concentration,
    );
    m.accuracy = Accuracy(
      physical: m.accuracy.physical + 1,
      magic: m.accuracy.magic,
      esp: m.accuracy.esp,
    );

    // **최대치는 내려가지 않는다** (부록 Z-8). 원작은 오를 때마다 공식으로
    // 덮어썼는데 시작 파티의 값이 공식과 맞지 않아서 — 슴갈은 인내력 15 ·
    // 레벨 1 에 최대 체력 150 — 처음 레벨 2가 되는 순간 150 이 34 로
    // 떨어졌다. 레벨을 올리면 약해지는 것은 규칙이 아니라 결함이다.
    m.baseMaxHitPoints = _atLeast(
      m.baseMaxHitPoints,
      m.stats.endurance * m.levels.physical,
    );
    m.baseMaxSpellPoints = _atLeast(
      m.baseMaxSpellPoints,
      m.stats.mentality * m.levels.magic,
    );
    m.baseMaxEspPoints = _atLeast(
      m.baseMaxEspPoints,
      m.stats.concentration * m.levels.esp,
    );

    final resolved = resolveStats(member: m, catalog: catalog);
    m.hitPoints = resolved[StatKey.maxHitPoints];
    m.spellPoints = resolved[StatKey.maxSpellPoints];
    m.espPoints = resolved[StatKey.maxEspPoints];

    gained++;
  }
  return LevelUpResult(gained: gained, toLevel: m.levels.physical);
}

int _atLeast(int current, int formula) => formula > current ? formula : current;
