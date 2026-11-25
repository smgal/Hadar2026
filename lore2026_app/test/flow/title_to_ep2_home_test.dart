import 'package:flutter_test/flutter_test.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/title_flow.dart';

import 'fake_hosts.dart';

/// 제목 화면에서 제2부를 고르고, 캐릭터를 만들어 로어성의 주인공의 집에서
/// 혼자 깨어나기까지 (2nd/04 §4.1).
int _answer(List<String> items) {
  final q = items.first;
  if (q.contains('3부작')) return 2; // 제2부 「다크 메이지 실리안 카미너스」
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

  setUp(() async {
    ui = ScriptedUi(_answer);
    HDHosts().bind(
      ui: ui,
      movement: InstantMovement(HDGameSession().party.move),
      assets: DiskAssets(),
    );
    await HDGameSession().init();
    HDGameSession().resetToTitle();
  });

  tearDown(HDHosts().reset);

  test('제목 → 제2부 → 캐릭터 만들기 → 로어성 주인공의 집 (10,48)', () async {
    await HDTitleFlow().run();

    final engine = HDScriptEngine();
    expect(engine.pendingNavigation?.path, 'E2_CastleLore');
    await engine.executePendingNavigation();

    final session = HDGameSession();
    final world = session.party.world;

    expect(ui.plainLines.any((l) => l.contains('타임워커 알비레오')), isTrue);
    expect(world.episode, Episode.ep2);
    // 혼자 시작한다 — 2~6번 자리가 비어 있다.
    expect([for (var s = 1; s < Seat.count; s++) world.member(s)], everyElement(isNull));

    expect(session.mapInfo?.name, 'E2_CastleLore');
    expect((session.party.x, session.party.y), (9, 47));
    expect(world.calendar.year, 774);
    expect((world.calendar.month, world.calendar.day, world.calendar.hour), (1, 19, 10));
  });
}
