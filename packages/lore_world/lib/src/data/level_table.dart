/// 레벨 표(제7장 7.6). `levelTable[n - 1]` 이 레벨 n 의 필요 누적 수련치다.
const List<int> levelTable = [
  0, // 1
  1500,
  6000,
  20000,
  50000, // 5
  150000,
  250000,
  500000,
  800000,
  1050000, // 10
  1320000,
  1620000,
  1950000,
  2320000,
  2700000, // 15
  3120000,
  3570000,
  4050000,
  4560000,
  5100000, // 20
  6000000,
  7000000,
  8000000,
  9000000,
  10000000, // 25
  12000000,
  14000000,
  16000000,
  18000000,
  20000000, // 30
  25000000,
  30000000,
  35000000,
  40000000,
  45000000, // 35
  50000000,
  55000000,
  60000000,
  65000000,
  70000000, // 40
];

const int maxLevel = 40;

/// 그 레벨이 되려면 필요한 누적 수련치. 표 밖은 양 끝 값으로 붙인다.
int trainedExpForLevel(int level) {
  if (level <= 1) return 0;
  if (level >= maxLevel) return levelTable[maxLevel - 1];
  return levelTable[level - 1];
}

/// 누적 수련치로 도달한 가장 높은 레벨(1~40).
int levelForTrainedExp(int trainedExp) {
  var level = 1;
  for (var i = 0; i < levelTable.length; i++) {
    if (trainedExp >= levelTable[i]) level = i + 1;
  }
  return level;
}

/// 기술치 1 올리는 비용(제7장 7.6). 훈련소 15, 마법 학교 10.
int trainingCost({required bool military, required int currentSkill}) =>
    (military ? 15 : 10) * currentSkill * currentSkill;
