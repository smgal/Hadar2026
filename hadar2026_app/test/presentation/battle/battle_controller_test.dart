import 'package:flutter_test/flutter_test.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hadar2026_app/presentation/panels/battle/battle_controller.dart';

/// B4-01 — 화면이 전투를 굴리는 방식.
///
/// **되감기가 이 파일의 요점이다.** 전투는 시드 + 명령 열이면 완전히
/// 재현되므로, 다른 수를 보려고 처음부터 다시 칠 필요가 없어야 한다.
/// 터미널에서 5인 파티를 라운드마다 다섯 번씩 치는 것이 힘들었던 이유가
/// 그것이다.

hb.BattleSetup setupFor({int seed = 3}) => hb.BattleSetup(
  party: [
    for (var i = 0; i < 2; i++)
      hb.CombatantSnapshot(
        slot: i,
        name: '용사$i',
        hp: 120,
        maxHp: 120,
        strength: 18,
        powOfWeapon: 10,
        levelPhysical: 1,
        accuracyPhysical: 15,
        weaponKey: 'dagger',
        rank: 1,
      ),
  ],
  enemyKeys: const ['orc', 'orc'],
  seed: seed,
);

/// 기다리지 않고 바로 다 흘리는 controller.
HDBattleController fast() => HDBattleController(setupFor())
  ..pace = Duration.zero
  ..start();

void main() {
  test('시작하면 물어볼 것이 생기고 줄이 찍힌다', () {
    final c = fast();
    expect(c.log, isNotEmpty, reason: '조우 줄이 나와야 한다');
    expect(c.decision, isA<hb.ActionDecision>());
    c.dispose();
  });

  test('아직 안 흘린 줄이 있으면 물음을 감춘다', () {
    // 방금 무슨 일이 있었는지 못 본 채로 다음 명령을 내리면 안 된다.
    final c = HDBattleController(setupFor())
      ..pace = const Duration(milliseconds: 50)
      ..start();
    expect(c.decision, isNull, reason: '흘릴 줄이 남아 있다');
    c.skipAhead();
    expect(c.decision, isNotNull);
    c.dispose();
  });

  test('답하면 model 이 나아간다', () {
    final c = fast();
    final first = c.decision as hb.ActionDecision;
    c.choose(hb.ChooseAction(first.slot, hb.BattleAction.attack));
    expect(c.canUndo, isTrue);
    expect(c.decision, isNot(same(first)));
    c.dispose();
  });

  // 이것이 없으면 다른 수를 보려고 처음부터 다시 쳐야 한다.
  test('물린 만큼 정확히 그 자리로 돌아간다', () {
    final c = fast();
    final start = _snapshot(c);

    // 한 라운드를 다 풀면 판이 실제로 움직인다 (명령 넷 = 2인 × 행동+대상).
    final played = _play(c, 4);
    expect(_snapshot(c), isNot(start), reason: '라운드가 풀렸어야 한다');

    for (var i = 0; i < played; i++) {
      c.undo();
    }
    expect(c.canUndo, isFalse);
    expect(_snapshot(c), start, reason: '시드가 같으니 판이 똑같아야 한다');
    c.dispose();
  });

  test('물린 뒤 다른 수를 두면 다른 길이 열린다', () {
    final c = fast();
    final first = c.decision as hb.ActionDecision;

    // 공격은 대상을 묻는다.
    c.choose(hb.ChooseAction(first.slot, hb.BattleAction.attack));
    expect(c.decision, isA<hb.EnemyTargetDecision>());

    // 물리고 버팀을 고르면 대상을 묻지 않고 다음 사람으로 넘어간다 —
    // 같은 자리에서 다른 수가 다른 물음을 낳는다. 그것이 되감기의 뜻이다.
    c.undo();
    final again = c.decision as hb.ActionDecision;
    expect(again.slot, first.slot);
    c.choose(hb.ChooseAction(again.slot, hb.BattleAction.brace));
    final next = c.decision;
    expect(next, isA<hb.ActionDecision>());
    expect(next!.slot, isNot(first.slot));
    c.dispose();
  });

  test('처음부터 는 명령을 전부 버린다', () {
    final c = fast();
    final start = _snapshot(c);
    _play(c, 4);
    c.restart();
    expect(c.canUndo, isFalse);
    expect(_snapshot(c), start);
    c.dispose();
  });

  test('끝까지 굴리면 정산 결과가 나온다', () {
    final c = fast();
    var guard = 0;
    while (!c.isFinished && guard++ < 4000) {
      final d = c.decision;
      if (d == null) break;
      c.choose(switch (d) {
        hb.ActionDecision() => hb.ChooseAction(d.slot, hb.BattleAction.attack),
        hb.EnemyTargetDecision() => hb.ChooseEnemyTarget(
          d.slot,
          d.enemyIndices.first,
        ),
        _ => hb.CancelChoice(d.slot),
      });
    }
    expect(c.isFinished, isTrue);
    expect(c.outcome, isNotNull);
    c.dispose();
  });
}

/// 판의 상태를 한 줄로. 되감기가 정확한지 보는 데 쓴다.
String _snapshot(HDBattleController c) => [
  c.battle.round,
  c.battle.gap,
  for (final p in c.battle.party) '${p.slot}:${p.hp}:${p.rank}',
  for (final e in c.battle.enemies) '${e.name}:${e.hp}:${e.rank}',
].join('|');

/// 물어보는 대로 무난하게 [count] 개 답한다. 실제로 답한 수를 돌려준다.
int _play(HDBattleController c, int count) {
  var done = 0;
  while (done < count && !c.isFinished) {
    final d = c.decision;
    if (d == null) break;
    c.choose(switch (d) {
      hb.ActionDecision() => hb.ChooseAction(d.slot, hb.BattleAction.attack),
      hb.EnemyTargetDecision() => hb.ChooseEnemyTarget(
        d.slot,
        d.enemyIndices.first,
      ),
      _ => hb.CancelChoice(d.slot),
    });
    done++;
  }
  return done;
}
