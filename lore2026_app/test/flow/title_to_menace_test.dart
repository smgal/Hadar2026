import 'package:flutter_test/flutter_test.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/tile_event_dispatcher.dart';
import 'package:lore2026_app/application/title_flow.dart';
import 'package:lore2026_app/domain/map/tile_properties.dart';

import 'fake_hosts.dart';

/// 제목 화면에서 제3부를 고르고 캐릭터를 만들어 메너스 금광에 서기까지.
///
/// 화면을 누르는 대신 메뉴마다 정해 둔 답을 넣는다. 앱이 실제로 쓰는
/// 흐름(`HDTitleFlow`) · 스크립트 엔진 · 맵 불러오기를 그대로 탄다.
int _answer(List<String> items) {
  final q = items.first;
  if (q.contains('3부작')) return 3; // 제3부 「비전 속으로」
  if (q.contains('성별')) return 1; // 남성
  if (q.contains('당신의 선택은')) return 1; // 성격 질문은 모두 1번
  if (q.contains('민첩성에 줄 점수')) return 15; // 0 부터이므로 14
  if (q.contains('정확성에 줄 점수')) return 9; // 6 부터이므로 14 → 행운 12
  if (q.contains('이대로 하겠습니까')) return 1;
  if (q.contains('계급을 고르십시오')) return 1; // 투사
  if (q.contains('점수를 더하겠습니까')) return 1; // 베는 무기에 5씩
  if (q.contains('만족합니까')) return 1;
  throw StateError('물음이 예상 밖이다: $q');
}

void main() {
  late ScriptedUi ui;

  setUp(() async {
    ui = ScriptedUi(_answer);
    HDHosts().bind(
      ui: ui,
      movement: InstantMovement(HDGameSession().party.move),
      assets: DiskAssets(),
    );
    await HDGameSession().init();
    // 앞 시험이 남긴 맵·플래그를 지우고 제목 화면 상태에서 시작한다.
    HDGameSession().resetToTitle();
  });

  tearDown(HDHosts().reset);

  test('제목 → 제3부 → 캐릭터 만들기 → 메너스 금광 (27,29)', () async {
    await HDTitleFlow().run();

    // 편 스크립트의 FLAG_START 가 맵을 정했다 — 셸이 하는 대로 옮긴다.
    final engine = HDScriptEngine();
    expect(engine.pendingNavigation?.path, 'E3_Menace');
    await engine.executePendingNavigation();

    final session = HDGameSession();
    final world = session.party.world;

    // 여는 편지가 캐릭터 만들기 전에 나왔다.
    expect(ui.plainLines.any((l) => l.contains('타임워커 알비레오')), isTrue);

    // 만든 주인공 — 성격 답이 모두 1번이면 체력 20 · 전투사 계열.
    final hero = world.protagonist!;
    expect(hero.name, '슴갈');
    expect(hero.family, Family.fighter);
    expect(hero.classId, ClassId.fighter);
    expect(hero.strength, 20);
    expect([hero.agility, hero.accuracy, hero.luck], [14, 14, 12]);
    expect(hero.skills.reduce((a, b) => a + b), 60);

    // 메너스 금광, 기획서 좌표 (27,29) — 엔진 좌표는 0 부터.
    expect(session.mapInfo?.name, 'E3_Menace');
    expect(session.map, isNotNull);
    expect((session.party.x, session.party.y), (26, 28));
    expect(world.calendar.year, 673);
    expect((world.calendar.month, world.calendar.day), (11, 27));
    expect(world.calendar.hour, 16);
    expect(world.torch, 4);

    // 맵에 들어오며 프롤로그 배치와 첫 문장이 나왔다.
    expect(ui.plainLines, contains('여기는 로어 대륙의 메너스 금광.'));
    final overseer = session.map!.getUnit(26, 31);
    expect(HDTileProperties.getUnitAction(overseer), HDTileAction.talk);
  });

  test('광산 감독에게 말을 걸면 일당 4를 받는다', () async {
    await HDTitleFlow().run();
    await HDScriptEngine().executePendingNavigation();
    final session = HDGameSession();
    expect(session.party.world.gold, 0);

    // (27,32) 에 서 있는 감독에게 부딪힌다.
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: 26,
      y: 31,
      isInteraction: true,
    );

    expect(session.party.world.gold, 4);
    expect(session.gameOption.flag('MENACE_WAGE_PAID'), isTrue);
    expect(ui.plainLines, contains('광산 감독 : 오, 슴갈.'));
    // 감독은 (27,38) 까지 걸어가 사라졌고, 그 자리는 이제 지나갈 수 있다.
    expect(
      HDTileProperties.getUnitAction(session.map!.getUnit(26, 31)),
      HDTileAction.move,
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('출구의 살인 누명 → 로어성 재판', () async {
    await HDTitleFlow().run();
    final engine = HDScriptEngine();
    await engine.executePendingNavigation();
    final session = HDGameSession();

    // (25,45) 출구 줄은 밟으면 일어나는 칸이다.
    final exit = session.map!.getUnit(24, 44);
    expect(HDTileProperties.getUnitAction(exit), HDTileAction.event);

    session.party.setPosition(24, 43);
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: 24,
      y: 44,
    );
    expect(ui.plainLines.any((l) => l.contains('창에 찔린 채로')), isTrue);
    expect(session.party.world.torch, 10);
    expect(engine.pendingNavigation?.path, 'E3_Lore');

    await engine.executePendingNavigation();
    expect(session.mapInfo?.name, 'E3_Lore');
    expect(ui.plainLines, contains('로드안이 병사에게 말했다.'));
    expect(
      ui.plainLines.any((l) => l.startsWith('로드안 : 이자는 누구인데')),
      isTrue,
    );
  }, timeout: const Timeout(Duration(seconds: 90)));
}
