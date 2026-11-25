import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore2026_app/application/field_rules.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/map_navigation.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/tile_event_dispatcher.dart';
import 'package:lore2026_app/application/title_flow.dart';
import 'package:lore2026_app/application/window_manager.dart';
import 'package:lore2026_app/domain/window/scenery_window_data.dart';

import 'fake_hosts.dart';

/// `Map::GetTile` · `Map::IsTile` — 칸에 지금 깔린 원작 타일 번호를 읽는다.
///
/// 코볼트성(E3_Kobold)은 원작이 칸을 읽어 갈래를 나누는 곳이 다섯 군데다.
/// 기대값의 번호는 공략집의 원작 맵 데이터(Walkthrough/3rd/maps/maps.json)에서
/// 옮겼다 — (9,30) 40 · (8,30) 0 · (58,100) 22 · (46,47) 50 · (108,53) 21.
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
  if (q.contains('용암을 건너게 해주겠소')) return 2; // 「건널 필요는 없다」
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

    // 제3부를 시작한 뒤 코볼트성 입구 (6,30) 으로 옮긴다.
    await HDTitleFlow().run();
    await engine.executePendingNavigation();
    engine.pendingNavigation = (
      path: 'E3_Kobold',
      hasExplicit: true,
      nx: 5,
      ny: 29,
    );
    session.clearCurrentMap();
    await engine.executePendingNavigation();
    expect(session.mapInfo?.name, 'E3_Kobold');
  });

  tearDown(HDHosts().reset);

  int tile(int x, int y) => engine.evaluateOnMap('Map::GetTile($x, $y)') as int;
  int isTile(int x, int y, int t) =>
      engine.evaluateOnMap('Map::IsTile($x, $y, $t)') as int;

  /// 스크립트 좌표(1부터)의 칸을 밟는다.
  Future<void> step(int x, int y) async {
    session.party.setPosition(x - 1, y - 1);
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: x - 1,
      y: y - 1,
    );
  }

  int count(String line) => ui.plainLines.where((l) => l == line).length;

  test('원작 번호를 읽는다', () async {
    expect(tile(9, 30), 40); // 무늬 바닥
    expect(tile(8, 30), 0); // 숨은 사건 칸
    expect(tile(58, 100), 22);
    expect(tile(46, 47), 50); // 용암
    expect(tile(108, 53), 21); // 닫힌 벽
    expect(tile(0, 0), -1); // 맵 밖
    expect(isTile(46, 47, 50), 1);
    expect(isTile(46, 47, 49), 0);
    // 숨은 칸은 기본 바닥(43)과 그림은 같지만 행동이 달라서 43 이 아니다.
    expect(isTile(8, 30, 43), 0);
    expect(isTile(8, 30, 0), 1);

    // 바꾼 칸은 바꾼 번호로 읽힌다.
    session.tileTable.entry('E3_Kobold', 49).applyTo(session.map!.getUnit(45, 46)!);
    expect(tile(46, 47), 49);
  });

  test('(8,30) 의 푯말은 한 번만 솟는다', () async {
    const rise = '갑자기 땅에서 푯말이 솟아 나왔다.';
    await step(8, 30);
    expect(count(rise), 1);
    expect(tile(9, 30), 53);
    // (8,30) 은 바닥으로 바뀌지 않는다 — 다시 밟으면 (9,30) 이 이미 푯말이라 아무 일도 없다.
    expect(tile(8, 30), 0);
    await step(8, 30);
    expect(count(rise), 1);
  });

  test('(58,101) 의 늪길은 (58,100) 이 아직 늪이 아닐 때만 생긴다', () async {
    const lean = '당신이 무심코 벽에 팔을 기대자 벽은 안으로 쑥 들어가 버렸다. 그리고는 새로운 길이 나타났다.';
    await step(58, 101);
    expect(count(lean), 1);
    for (var y = 86; y <= 100; y++) {
      expect(isTile(58, y, 49), 1, reason: '(58,$y) 이 늪이 아니다');
    }
    expect(tile(58, 85), 0);
    await step(58, 101);
    expect(count(lean), 1);
  });

  test('(48,73) 은 북쪽 용암 76칸을 늪으로, (45,46) 은 활 모양 강 57칸을 물로', () async {
    int countIn(int x1, int y1, int x2, int y2, int t) {
      var n = 0;
      for (var y = y1; y <= y2; y++) {
        for (var x = x1; x <= x2; x++) {
          n += isTile(x, y, t);
        }
      }
      return n;
    }

    expect(countIn(37, 42, 54, 50, 50), 76);
    // (48,73) 은 처음에 평범한 바닥이다. 푯말 (54,63) 에서 「건널 필요는 없다」를 고르면 숨은 칸이 된다.
    expect(tile(48, 73), 43);
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: 53,
      y: 62,
      isInteraction: true,
    );
    expect(tile(48, 73), 0);
    await step(48, 73);
    expect(countIn(37, 42, 54, 50, 50), 0);
    expect(countIn(37, 42, 54, 50, 49), 76);

    expect(countIn(56, 51, 60, 74, 50), 57);
    await step(45, 46);
    expect(countIn(56, 51, 60, 74, 50), 0);
    expect(countIn(56, 51, 60, 74, 48), 57);
  });

  test('(64,25) 는 (108,53) 이 닫혀 있을 때만 암흑 구역의 벽을 연다', () async {
    const rumble = '성의 남동쪽에서 돌연히 커다란 진동음과 함께 기계 소리가 들렸다.';
    // (64,25) 는 처음에 평범한 바닥이다 — 유압 연쇄 3단계가 숨은 칸으로 만든다.
    session.tileTable.entry('E3_Kobold', 0).applyTo(session.map!.getUnit(63, 24)!);
    await step(64, 25);
    expect(count(rumble), 1);
    expect(tile(108, 53), 0);
    expect(tile(64, 25), 43);

    // 벽이 이미 열려 있으면 장치는 아무 일도 하지 않는다.
    session.tileTable.entry('E3_Kobold', 0).applyTo(session.map!.getUnit(63, 24)!);
    await step(64, 25);
    expect(count(rumble), 1);
  });

  test('크리스탈 볼 — 다음 원혼이 있는 자리의 9×11칸을 그 맵의 그림으로 비춘다', () async {
    // 오크의 원혼을 아직 봉인하지 않았다 — 가이아 테라 (92,12) 가 비친다
    session.gameOption.variables['SPIRITS_SEALED'] = 0;
    engine.pendingNavigation = (path: 'E3_Ground1', hasExplicit: true, nx: 19, ny: 11);
    session.clearCurrentMap();
    await engine.executePendingNavigation();

    engine.usedItemKey = 'crystal.ball';
    final run = engine.runMapMode(HDScriptMode.item);
    // 창이 뜰 때까지 기다렸다가 닫는다 (사람이 아무 키나 누르는 것과 같다)
    HDSceneryWindow? window;
    for (var i = 0; i < 200 && window == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      window = HDWindowManager().windows.whereType<HDSceneryWindow>().firstOrNull;
    }
    expect(window, isNotNull);
    expect(ui.plainLines, contains('당신은 수정 구슬을 통해 낯선 풍경을 보았다.'));
    expect((window!.columns, window.rows), (9, 11));
    // 가운데 칸이 (92,12) — 그 맵 파일의 칸이다
    final ground2 = (await HDMapNavigation().loadByName('E3_Ground2'))!.json!;
    final centre = window.units[5 * 9 + 4]!;
    final want = ground2.getUnit(91, 11)!;
    expect((centre.ixTile, centre.ixObj0), (want.ixTile, want.ixObj0));
    window.close();
    await run;
    expect(HDWindowManager().windows.whereType<HDSceneryWindow>(), isEmpty);
  });

  test('Map::ScatterTile — 돔 공사 현장은 칸마다 10분의 1 확률로 45번, 나머지는 47번', () async {
    HDFieldRules().rng = Random(1);
    session.gameOption.variables['DOME_STAGE'] = 1;
    engine.pendingNavigation = (path: 'E3_Dome', hasExplicit: true, nx: 24, ny: 49);
    session.clearCurrentMap();
    await engine.executePendingNavigation();
    var t45 = 0, t47 = 0;
    for (var y = 1; y <= 100; y++) {
      for (var x = 1; x <= 50; x++) {
        if (isTile(x, y, 45) == 1) t45++;
        if (isTile(x, y, 47) == 1) t47++;
      }
    }
    expect(t45 + t47, 5000);
    // 5000칸의 10분의 1 — 이항분포의 표준편차는 약 21칸
    expect(t45, inInclusiveRange(430, 570));
    HDFieldRules().rng = Random();
  });

  test('임페리움 제작자 — 말을 거는 동안만 제작자 그림이고, 끝나면 주민 칸이 그대로 돌아온다', () async {
    engine.pendingNavigation = (path: 'E3_Imperium', hasExplicit: true, nx: 17, ny: 18);
    session.clearCurrentMap();
    await engine.executePendingNavigation();
    final before = tile(18, 18);
    expect(before, 49); // 원작 지도의 주민 칸

    // 제작자를 세우는 순간을 붙잡는다 — 대사가 나올 때 배우가 서 있어야 한다
    var shownWhileTalking = false;
    ui.onLine = (line) {
      if (line.contains('안녕하시오')) {
        final a = session.actors['안영기'];
        shownWhileTalking = a != null && a.strip == 24 && tile(18, 18) == 47;
      }
    };
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: 17,
      y: 17,
      isInteraction: true,
    );
    ui.onLine = null;
    expect(shownWhileTalking, isTrue);
    expect(session.actors, isEmpty);
    expect(tile(18, 18), before);
  });
}
