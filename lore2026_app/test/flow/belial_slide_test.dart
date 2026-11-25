import 'package:flutter_test/flutter_test.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/tile_event_dispatcher.dart';
import 'package:lore2026_app/application/title_flow.dart';

import 'fake_hosts.dart';

/// 베리알의 동굴 미끄럼 칸 — 부록 A #29 의 리메이크 규칙.
///
/// 걸어온 방향으로 3칸 미끄러진다. 사이의 벽은 넘고, 3칸 앞에 설 수 없으면
/// 그 앞에서 멈춘다. 내려선 칸의 사건은 일어난다(`Event::StepAgain`) — 또
/// 미끄럼 칸이면 이어서 미끄러진다. 좌표는 원작 맵 데이터로 계산했다.
int _answer(List<String> items) {
  final q = items.first;
  if (q.contains('3부작')) return 2;
  if (q.contains('성별')) return 1;
  if (q.contains('당신의 선택은')) return 1;
  if (q.contains('민첩성에 줄 점수')) return 15;
  if (q.contains('정확성에 줄 점수')) return 9;
  if (q.contains('이대로 하겠습니까')) return 1;
  if (q.contains('계급을 고르십시오')) return 1;
  if (q.contains('점수를 더하겠습니까')) return 1;
  if (q.contains('만족합니까')) return 1;
  throw StateError('물음이 예상 밖이다: $q');
}

void main() {
  late ScriptedUi ui;
  final engine = HDScriptEngine();
  final session = HDGameSession();

  setUp(() async {
    ui = ScriptedUi(_answer);
    HDHosts().bind(
      ui: ui,
      movement: InstantMovement(session.party.move),
      assets: DiskAssets(),
    );
    await session.init();
    session.resetToTitle();
    await HDTitleFlow().run();
    await engine.executePendingNavigation();
    engine.pendingNavigation = (
      path: 'E2_Belial',
      hasExplicit: true,
      nx: 24,
      ny: 43,
    );
    session.clearCurrentMap();
    await engine.executePendingNavigation();
    expect(session.mapInfo?.name, 'E2_Belial');
  });

  tearDown(HDHosts().reset);

  /// 스크립트 좌표 ([fromX],[fromY]) 에서 ([dx],[dy]) 쪽으로 한 걸음 걸어
  /// 다음 칸을 밟는다. 끝난 자리를 스크립트 좌표로 돌려준다.
  Future<(int, int)> walk(int fromX, int fromY, int dx, int dy) async {
    final party = session.party;
    party.setPosition(fromX - 1 + dx, fromY - 1 + dy);
    party.setFace(dx, dy);
    await HDTileEventDispatcher().check(
      map: session.map,
      party: party,
      host: ui,
      x: party.x,
      y: party.y,
    );
    return (party.x + 1, party.y + 1);
  }

  int passable(int x, int y) =>
      engine.evaluateOnMap('Map::IsPassable($x, $y)') as int;

  test('Map::IsPassable — 걷기와 같은 판정', () {
    expect(passable(13, 18), 1); // 바닥
    expect(passable(13, 19), 1); // 미끄럼 칸(보이지 않는 사건 칸)도 들어설 수 있다
    expect(passable(21, 33), 0); // 벽
    expect(passable(0, 0), 0); // 맵 밖
  });

  test('내려선 칸이 또 미끄럼 칸이면 이어서 미끄러진다', () async {
    // (11,21) 에서 남쪽으로 (11,22) 를 밟는다 → (11,25) → (11,28) → (11,31) 바닥
    expect(await walk(11, 21, 0, 1), (11, 31));
  });

  test('3칸 앞이 벽이면 그 앞에서 멈춘다 (원작은 벽 칸에 내려섰다)', () async {
    // (21,29) 에서 남쪽으로 (21,30) 을 밟는다 → 3칸 앞 (21,33) 은 벽 → (21,32)
    expect(await walk(21, 29, 0, 1), (21, 32));
  });
}
