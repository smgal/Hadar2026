import 'package:flutter_test/flutter_test.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/title_flow.dart';

import 'fake_hosts.dart';

/// 제목 화면에서 제1부를 고르고, 캐릭터를 만들고, 동행할 넷을 골라
/// 로어성 알현실에 서기까지 (1st/04 §4.1~4.2).
int _answer(List<String> items) {
  final q = items.first;
  if (q.contains('3부작')) return 1; // 제1부 「또 다른 지식의 성전」
  if (q.contains('성별')) return 1;
  if (q.contains('당신의 선택은')) return 1;
  if (q.contains('민첩성에 줄 점수')) return 15;
  if (q.contains('정확성에 줄 점수')) return 9;
  if (q.contains('이대로 하겠습니까')) return 1;
  if (q.contains('계급을 고르십시오')) return 1;
  if (q.contains('점수를 더하겠습니까')) return 1;
  if (q.contains('만족합니까')) return 1;
  if (q.contains('동행할 용사')) return 1; // 남은 사람 중 맨 앞 — 헤라클레스부터 넷
  if (q.contains('일행에 참석시킬까요')) return 1;
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

  test('제목 → 제1부 → 캐릭터 만들기 → 동료 넷 → 로어성 알현실 (51,31)', () async {
    await HDTitleFlow().run();

    final engine = HDScriptEngine();
    expect(engine.pendingNavigation?.path, 'E1_CastleLore');
    await engine.executePendingNavigation();

    final session = HDGameSession();
    final world = session.party.world;

    expect(ui.plainLines.any((l) => l.contains('LORE의 세계에 당신을 초대합니다')), isTrue);
    expect(world.episode, Episode.ep1);

    // 원작 순서의 맨 앞 넷이 2~5번에.
    expect(
      [for (var s = 1; s <= 4; s++) world.member(s)?.nameKey],
      ['companion.hercules', 'companion.titan', 'companion.merlin', 'companion.betelgeuse'],
    );
    expect(world.member(Seat.assistant), isNull);

    // 1st/07 §7.4 — 특수 마법과 초자연력 수련은 잠겨 있다.
    expect(world.specialMagicUnlocked, isFalse);
    expect(world.espTrainingUnlocked, isFalse);

    expect(session.mapInfo?.name, 'E1_CastleLore');
    expect((session.party.x, session.party.y), (50, 30));
    expect(world.calendar.year, 771);
    expect((world.calendar.month, world.calendar.day, world.calendar.hour), (3, 1, 9));
  });
}
