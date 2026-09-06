import 'package:hd_battle/hd_battle.dart';

/// B6-04 — 간격이 도망 확률을 얼마나 바꾸는가.
///
/// ```bash
/// dart run tool/escape_odds.dart
/// ```
///
/// 5인 기본 파티(민첩·행운 평균)가 적 평균 민첩별로 간격 0·1·2 에서
/// 도망에 성공하는 비율. 시드 10,000 개. `GROUND_TRUTH` 부록에 붙는 표다.
void main() {
  const trials = 10000;
  // 5인 기본 파티의 평균 — `hd_battle_console/tool/make_fixtures.dart`
  // `standardParty()`: 민첩 12·15·10·9·11, 행운 전부 0 에 가깝다.
  const partyAgility = 11;
  const partyLuck = 2;

  print('5인 파티(민첩 $partyAgility · 행운 $partyLuck) 의 도망 성공률 — 시드 $trials 개');
  print('');
  print('| 적 평균 민첩 | 간격 0 | 간격 1 | 간격 2 |');
  print('|---|---|---|---|');
  for (final enemyAgility in [5, 10, 15, 20, 25, 30]) {
    final cells = <String>[];
    for (var gap = 0; gap <= maxGap; gap++) {
      var wins = 0;
      for (var seed = 0; seed < trials; seed++) {
        if (escapeSucceeds(
          agility: partyAgility,
          luck: partyLuck,
          averageEnemyAgility: enemyAgility,
          gap: gap,
          rng: SeededRng(seed),
        )) {
          wins++;
        }
      }
      cells.add('${(wins * 100 / trials).toStringAsFixed(0)}%');
    }
    print('| $enemyAgility | ${cells.join(" | ")} |');
  }
  print('');
  print('한 칸이 +$escapeGapBonus — `rand(20)` 의 폭보다 크다. '
      '두 번 물러선 뒤 달아나는 것이 결정이 되는 이유다.');
}
