import 'package:hd_battle/hd_battle.dart';

/// 열 가중 대상 선택이 실제로 앞열을 더 맞게 하는지 실측한다 (B5-04).
///
///   dart run tool/target_share.dart
///
/// 전에는 균등 추첨이라 이 표가 전부 20% 였다 — 그래서 대열이 전투에
/// 아무 영향이 없었고, 방패를 아무리 좋게 해도 적이 그 사람을 안 때렸다.
void main() {
  const ranks = {
    '전원 앞': [1, 1, 1, 1, 1],
    '기본 대열 (1/2/1/3/3)': [1, 2, 1, 3, 3],
    '전원 뒤': [3, 3, 3, 3, 3],
    '한 명만 앞': [1, 3, 3, 3, 3],
  };

  // 무기 사거리가 감쇠 폭을 정한다 — 창은 앞을 지나쳐 고르고 철퇴는 앞을 친다.
  const reach = 2; // 장검 기준
  for (final gap in const [0, 1, 2]) {
    final lines = <String>[];
    for (final entry in ranks.entries) {
      final hits = List.filled(entry.value.length, 0);
      final rng = SeededRng(1234);
      const trials = 200000;
      for (var i = 0; i < trials; i++) {
        hits[pickByRank(
          candidateRanks: entry.value,
          attackerRank: 1,
          gap: gap,
          reach: reach,
          rng: rng,
        )]++;
      }
      final pct = [
        for (var i = 0; i < hits.length; i++)
          '${(hits[i] * 100 / trials).toStringAsFixed(0)}%',
      ];
      lines.add(
        '| ${entry.key.padRight(22)} | ${entry.value.join("/")} '
        '| ${pct.join(" | ")} |',
      );
    }
    // ignore: avoid_print
    print('''
간격 $gap · 사거리 $reach 인 적이 노리는 비율

| 대열 | 열 | 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|---|
${lines.join('\n')}
''');
  }
  endToEnd();
}

/// 실제 전투를 끝까지 돌려서 누가 맞았는지 센다.
///
/// 위의 표는 뽑기 함수만 본 것이고, 이쪽은 **전투 전체**를 통과한 결과다.
/// 마법·특수 능력은 열 가중을 쓰지 않으므로 물리 피해만 센다.
void endToEnd() {
  const names = ['슴갈(1열)', '유리(2열)', '방패병(1열)', '술사(3열)', '치유사(3열)'];
  const ranks = [1, 2, 1, 3, 3];

  CombatantSnapshot member(int slot) => CombatantSnapshot(
    slot: slot,
    rank: ranks[slot],
    name: names[slot],
    strength: 12,
    endurance: 14,
    agility: 10,
    ac: 5,
    hp: 400,
    maxHp: 400,
    accuracyPhysical: 10,
    levelPhysical: 1,
    powOfWeapon: 8,
  );

  final hits = List.filled(5, 0);
  for (var seed = 1; seed <= 400; seed++) {
    final battle = Battle(
      BattleSetup(
        party: [for (var i = 0; i < 5; i++) member(i)],
        // 물리로만 때리는 적. 마법은 열 가중을 안 쓴다.
        enemyKeys: const ['orc', 'orc', 'orc', 'orc'],
        initialGap: 0,
        seed: seed,
      ),
    );
    var guard = 0;
    while (!battle.isFinished && guard++ < 4000) {
      final d = battle.pendingDecision;
      if (d == null) {
        for (final e in battle.advance()) {
          if (e is MemberDamaged) hits[e.slot]++;
        }
        continue;
      }
      battle.applyCommand(switch (d) {
        ActionDecision() => ChooseAction(d.slot, BattleAction.attack),
        EnemyTargetDecision() => ChooseEnemyTarget(
          d.slot,
          d.enemyIndices.first,
        ),
        _ => CancelChoice(d.slot),
      });
    }
  }
  final total = hits.reduce((a, b) => a + b);
  final rows = [
    for (var i = 0; i < 5; i++)
      '| ${names[i].padRight(12)} | ${hits[i].toString().padLeft(5)} '
          '| ${(hits[i] * 100 / total).toStringAsFixed(1)}% |',
  ];
  // ignore: avoid_print
  print('''
전투 400판을 끝까지 돌렸을 때 실제로 물리 피해를 받은 횟수 (Orc 넷, 간격 0)

| 파티원 | 피격 | 비율 |
|---|---|---|
${rows.join('\n')}
| 합계 | $total | 100% |
''');
}
