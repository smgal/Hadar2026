import 'package:flutter_test/flutter_test.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore2026_app/application/field_magic.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/title_flow.dart';

import 'fake_hosts.dart';

/// `Map::SetMagicBarrier` — 걸어서 지나가야 하는 줄을 이동 마법이 건너뛰지 못한다.
///
/// 이블 실의 문 줄(y 49~50)과 와이번 동굴의 와이번 줄(17~24,10). 예는 공략집
/// 리메이크 메모의 것이다 — 원작은 (26,51) 에서 북쪽 3칸 공간 이동으로 (26,48)
/// 에 내려섰고, (20,12) 에서 북쪽 기화 이동으로 와이번 줄을 넘었다.
int _answer(List<String> items) {
  final q = items.first;
  if (q.contains('3부작')) return 1;
  if (q.contains('성별')) return 1;
  if (q.contains('당신의 선택은')) return 1;
  if (q.contains('민첩성에 줄 점수')) return 15;
  if (q.contains('정확성에 줄 점수')) return 9;
  if (q.contains('이대로 하겠습니까')) return 1;
  if (q.contains('계급을 고르십시오')) return 1;
  if (q.contains('점수를 더하겠습니까')) return 1;
  if (q.contains('만족합니까')) return 1;
  if (q.contains('동행할 용사')) return 1;
  if (q.contains('일행에 참석시킬까요')) return 1;
  throw StateError('물음이 예상 밖이다: $q');
}

const _repelled = '알 수 없는 힘이 당신의 마법을 배척합니다.';

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
  });

  tearDown(HDHosts().reset);

  Future<void> goTo(String map, int x, int y) async {
    engine.pendingNavigation = (path: map, hasExplicit: true, nx: x - 1, ny: y - 1);
    session.clearCurrentMap();
    await engine.executePendingNavigation();
    expect(session.mapInfo?.name, map);
  }

  /// 스크립트 좌표로 서서 북쪽을 본다.
  void standFacingNorth(int x, int y) {
    session.party
      ..setPosition(x - 1, y - 1)
      ..setFace(0, -1);
  }

  (int, int) here() => (session.party.x + 1, session.party.y + 1);

  test('이블 실 — 문 줄을 넘는 공간 이동은 배척된다', () async {
    await goTo('E1_EvilSeal', 25, 70);
    standFacingNorth(26, 51);
    await HDFieldMagic().perform(
      const MapActionNeeded(MapAction.teleport, distance: 3),
    );
    expect(ui.plainLines.last, _repelled);
    expect(here(), (26, 51));

    // 문 줄에 닿지 않는 공간 이동은 된다 — (24,64) 에서 북쪽 2 → (24,62)
    standFacingNorth(24, 64);
    await HDFieldMagic().perform(
      const MapActionNeeded(MapAction.teleport, distance: 2),
    );
    expect(ui.plainLines.last, '공간 이동 마법이 성공했습니다.');
    expect(here(), (24, 62));
  });

  test('와이번 동굴 — 와이번 줄을 넘는 공간 이동은 배척된다', () async {
    await goTo('E1_Wivern', 20, 35);
    standFacingNorth(20, 12);
    await HDFieldMagic().perform(
      const MapActionNeeded(MapAction.teleport, distance: 3),
    );
    expect(ui.plainLines.last, _repelled);
    expect(here(), (20, 12));
  });

  test('장벽은 세이브에 실린다', () async {
    await goTo('E1_Wivern', 20, 35);
    final json = session.mapRuntime.toJson();
    session.mapRuntime.fromJson(json);
    expect(session.mapRuntime.isBarrier(19, 9), isTrue); // (20,10) — 엔진 좌표
    expect(session.mapRuntime.isBarrier(19, 10), isFalse);
  });
}
