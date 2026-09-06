import 'package:hd_battle/hd_battle.dart';

/// 조우가 어떤 간격에서 열리는지 실측한다 (B5-01).
///
///   dart run tool/opening_gap.dart
///
/// 실전은 3~4 라운드다(부록 W-1). 간격 2 에서 시작해 붙는 데 2라운드가
/// 걸리면 전투의 절반이 걸어다니는 시간이 된다. 그래서 **대부분의 조우가
/// 0~1 에서 열려야** 위치가 뜻을 갖는다. 이 표가 그것을 확인한다.
void main() {
  // 5인 기본 파티에 준하는 값. 레벨은 물리 레벨이다.
  const partyAgility = [12, 15, 9, 11, 10];

  const levels = [1, 2, 3, 5, 8, 12, 20];

  final rows = <String>[];
  for (final level in levels) {
    final counts = <int, int>{0: 0, 1: 0, 2: 0};
    for (final data in enemyTable) {
      final gap = openingGap(
        partyAgility: partyAgility,
        partyLevel: List.filled(partyAgility.length, level),
        enemyAgility: [data.agility],
        enemyLevel: [data.level],
      );
      counts[gap] = counts[gap]! + 1;
    }
    final total = enemyTable.length;
    String pct(int n) => '${(n * 100 / total).toStringAsFixed(0)}%';
    rows.add(
      '| ${level.toString().padLeft(2)} '
      '| ${pct(counts[0]!)} | ${pct(counts[1]!)} | ${pct(counts[2]!)} |',
    );
  }

  // ignore: avoid_print
  print('''
적 ${enemyTable.length}종 각각을 혼자 세웠을 때, 파티 물리 레벨별 초기 간격 분포

| 파티 레벨 | 간격 0 (붙어서 시작) | 간격 1 | 간격 2 |
|---|---|---|---|
${rows.join('\n')}
''');

  // 실제 조우 몇 개를 그대로.
  const encounters = {
    'Orc x3': ['orc', 'orc', 'orc'],
    'Giant + Wolf': ['giant', 'wolf'],
    'Devil Hunter x7': [
      'devil_hunter',
      'devil_hunter',
      'devil_hunter',
      'devil_hunter',
      'devil_hunter',
      'devil_hunter',
      'devil_hunter',
    ],
    'Archi-Mage': ['archi_mage'],
    'Neo-Necromancer': ['neo_necromancer'],
  };
  final lines = <String>[];
  for (final e in encounters.entries) {
    final enemies = [for (final k in e.value) enemyByKey[k]!];
    final byLevel = [
      for (final level in const [1, 5, 20])
        openingGap(
          partyAgility: partyAgility,
          partyLevel: List.filled(partyAgility.length, level),
          enemyAgility: [for (final d in enemies) d.agility],
          enemyLevel: [for (final d in enemies) d.level],
        ),
    ];
    lines.add('| ${e.key} | ${byLevel.join(" | ")} |');
  }
  // ignore: avoid_print
  print('''
실제 조우의 초기 간격 (파티 레벨 1 / 5 / 20)

| 조우 | 레벨 1 | 레벨 5 | 레벨 20 |
|---|---|---|---|
${lines.join('\n')}
''');
}
