import 'package:flutter_test/flutter_test.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/tile_event_dispatcher.dart';
import 'package:lore2026_app/application/title_flow.dart';

import 'fake_hosts.dart';

/// 3편 로어성의 사면 장면 — 간수가 배우(`Actor::*`)로 걷는다.
///
/// 전에는 간수가 지나가는 칸을 사람 칸(53)으로 바꿨다가 바닥 번호로 되돌렸다.
/// 배우는 칸을 바꾸지 않으므로 장면이 끝난 뒤 맵이 장면 전과 같아야 한다.
int _answer(List<String> items) {
  final q = items.first;
  if (q.contains('3부작')) return 3;
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
  });

  tearDown(HDHosts().reset);

  int tile(int x, int y) => engine.evaluateOnMap('Map::GetTile($x, $y)') as int;

  test('간수가 배우로 걷고, 장면이 끝나면 맵은 장면 전과 같다', () async {
    await HDTitleFlow().run();
    await engine.executePendingNavigation();
    // 메너스 금광의 출구 → 살인 누명 → 로어성 재판 → 감방
    session.party.setPosition(24, 43);
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: 24,
      y: 44,
    );
    await engine.executePendingNavigation();
    expect(session.mapInfo?.name, 'E3_Lore');
    expect(session.gameOption.variable('MAIN_STAGE'), 0);

    // 장면 전의 칸 — 복도의 간수 (50,11) 과 알현실 통로 (50,31~36)
    final corridor = [for (var x = 46; x <= 50; x++) tile(x, 11)];
    final aisle = [for (var y = 31; y <= 36; y++) tile(50, y)];
    expect(corridor.last, 53); // 간수가 서 있다

    // (44,10) 감방 안 문 앞을 밟는다
    session.party.setPosition(43, 9);
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: 43,
      y: 9,
    );

    expect(ui.plainLines, contains('간수 : 어이, 슴갈. 로드안님이 널 찾으신다. 따라와!'));
    expect(session.gameOption.variable('MAIN_STAGE'), 2);
    expect((session.party.x + 1, session.party.y + 1), (51, 31));
    // 배우는 다 물러갔고 칸은 장면 전과 같다
    expect(session.actors, isEmpty);
    expect([for (var x = 46; x <= 50; x++) tile(x, 11)], corridor);
    expect([for (var y = 31; y <= 36; y++) tile(50, y)], aisle);
  }, timeout: const Timeout(Duration(seconds: 120)));
}
