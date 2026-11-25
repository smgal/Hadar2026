import 'package:flutter_test/flutter_test.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/title_flow.dart';

import 'fake_hosts.dart';

/// 1부 예언 — 원작 LOREMENU.PAS:643~697 (ReturnPredict) 를 그대로 옮겼는지 본다.
///
/// 원작은 위에서부터 정하고 뒤의 줄이 덮지만, 워터 필드 표는 결과가 13 일 때만
/// 적용된다. 그래서 13(가이아 테라 들판)·14(와이번 동굴)이 덮이지 않는다.
int _answer(List<String> items) {
  final q = items.first;
  if (q.contains('3부작')) return 1;
  if (q.contains('동행할 용사')) return 1;
  return 1;
}

void main() {
  late ScriptedUi ui;
  final session = HDGameSession();
  final engine = HDScriptEngine();

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

  Future<String> predict(String map, Map<String, int> vars, {Set<String> flags = const {}}) async {
    session.gameOption.mapName = map;
    for (final e in vars.entries) {
      session.gameOption.variables[e.key] = e.value;
    }
    for (final f in flags) {
      session.gameOption.flags[f] = true;
    }
    final before = ui.plainLines.length;
    await engine.runEpisode(HDScriptMode.prophecy);
    return ui.plainLines.sublist(before).last;
  }

  const base = {'LORD_STAGE': 6, 'LASTDITCH_QUEST': 3, 'GAIA_QUEST': 6, 'WATERFIELD_QUEST': 0};

  test('13 · 14 는 그 맵에서 나오고 덮이지 않는다', () async {
    expect(await predict('E1_Wivern', base), '당신은 WATER FIELD로 갈 것이다');
    expect(await predict('E1_Gaia', base), '당신은 북동쪽의 WIVERN 동굴에 갈 것이다');
    expect(await predict('E1_CastleLore', base), '당신은 WATER FIELD의 군주를 만날 것이다');
    // 원작은 이 두 줄에서 워터 필드 의뢰 단계를 보지 않는다
    expect(await predict('E1_Gaia', {...base, 'WATERFIELD_QUEST': 3}), '당신은 북동쪽의 WIVERN 동굴에 갈 것이다');
    expect(await predict('E1_CastleLore', {...base, 'WATERFIELD_QUEST': 3}), '당신은 LOCKUP 속의 Dragon을 물리칠 것이다');
  });

  test('로드안 단계와 라스트디치 — 8 은 원작에서도 9 에 덮인다', () async {
    expect(await predict('E1_LastDitch', {'LORD_STAGE': 6, 'LASTDITCH_QUEST': 0, 'GAIA_QUEST': 0, 'WATERFIELD_QUEST': 0}),
        '당신은 LASTDITCH의 성주를 만날 것이다');
    expect(await predict('E1_CastleLore', {'LORD_STAGE': 3, 'LASTDITCH_QUEST': 0, 'GAIA_QUEST': 0, 'WATERFIELD_QUEST': 0}),
        '당신은 MENACE를 탐험할 것이다');
    expect(await predict('E1_LastDitch', {'LORD_STAGE': 6, 'LASTDITCH_QUEST': 3, 'GAIA_QUEST': 0, 'WATERFIELD_QUEST': 0}),
        '당신은 GAIA TERRA의 성주를 만날 것이다');
  });

  test('늪의 대륙과 용암의 대륙', () async {
    final swamp = {...base, 'WATERFIELD_QUEST': 5};
    expect(await predict('E1_SwampGate', swamp), '당신은 위쪽의 게이트를 통해 SWAMP KEEP으로 갈 것이다');
    expect(await predict('E1_Muddy', swamp), '당신은 SWAMP 대륙에 존재하는 두 개의 봉인을 풀 것이다');
    expect(await predict('E1_Lava', {...swamp, 'EVILGOD_SEAL': 1}, flags: {'MUDDY_SEAL'}),
        '당신은 적의 집결지인 EVIL CONCENTRATION으로 갈 것이다');
    expect(await predict('E1_Chamber', swamp), '당신은 Necromancer와 마지막 결전을 벌일 것이다');
  });
}
