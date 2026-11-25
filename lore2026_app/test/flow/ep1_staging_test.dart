import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/title_flow.dart';

import 'fake_hosts.dart';

/// 1편의 두 연출 — 원작(LoreTrilogy_1993 의 1부 Pascal 소스)과 맞춘다.
///
/// - 반신반인 장면 (LORESPEC.PAS:2045~2065): 판저 바이퍼를 이기면 지도 칸에
///   로드안 · 에인션트 이블 두 이름만 띄운 채 화자 없이 말하고, 일행이 반신반인이 된다.
/// - 엔딩 「공헌한 인물」 (LOREEND.PAS:127~153): 줄마다 1부 인물 그림이 붙는다.
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
  // 전투 — 공격이 있으면 공격, 그 밖의 물음(대상 고르기 등)은 첫 줄
  final attack = items.skip(1).toList().indexWhere((o) => o.contains('공격'));
  return attack >= 0 ? attack + 1 : 1;
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
  });

  tearDown(HDHosts().reset);

  test('반신반인 장면 — 두 이름을 띄우고 화자 없이 말한 뒤 이름을 거둔다', () async {
    engine.pendingNavigation =
        (path: 'E1_DungeonEvil', hasExplicit: true, nx: 24, ny: 44);
    session.clearCurrentMap();
    await engine.executePendingNavigation();
    expect(session.mapInfo?.name, 'E1_DungeonEvil');
    ui.nameLists.clear();

    // 전투를 거치지 않고 DungeonEvil 의 「이긴 뒤」 줄만 떼어 돌린다 — 이 시험은 승패가 아니라 장면을 본다
    final src = File('assets/ep1/DungeonEvil.cm2').readAsLinesSync();
    final from = src.indexWhere((l) => l.contains('Flag::Set("PANZER_VIPER_DEAD")'));
    final to = src.indexWhere((l) => l.contains('일행 전원이 반신반인이 되었다'));
    expect(from, greaterThan(0));
    expect(to, greaterThan(from));
    await engine.loadFromString([
      'include("common/const.cm2")',
      for (final l in src.sublist(from, to + 1)) l.trim(),
    ].join('\n'));
    await engine.run();
    final world = session.party.world;

    expect(session.gameOption.flag('PANZER_VIPER_DEAD'), isTrue);

    // 이름 목록: 두 이름을 띄웠다가 거뒀다 (빈 목록)
    final shown = ui.nameLists.where((l) => l.isNotEmpty).toList();
    expect(shown, hasLength(1));
    expect(shown.single.map((e) => e.text), ['로드안', '에인션트 이블']);
    expect(ui.nameLists.last, isEmpty);

    // 화자 이름 없이 말한다 — 원작은 회색 Print 만 썼다
    expect(
      ui.plainLines.where((l) => l.startsWith('매우 수고하시는군요.')),
      hasLength(1),
    );
    expect(ui.plainLines.where((l) => l.startsWith('로드안 :')), isEmpty);

    // 일행 전원이 반신반인
    for (final m in world.seats.whereType<Member>()) {
      expect(m.classId, ClassId.demigod);
    }
  });

  test('엔딩 「공헌한 인물」 — 원작 그림 번호와 제작진 방식', () async {
    // 결전을 거치지 않고 Chamber 의 편지 줄만 떼어 돌린다
    final src = File('assets/ep1/Chamber.cm2').readAsLinesSync();
    final from = src.indexWhere((l) => l.contains('공헌한 인물@@'));
    final to = src.indexWhere((l) => l.contains('LETTER_CREDITS'));
    expect(from, greaterThan(0));
    expect(to, greaterThan(from));
    final body = [
      'include("common/const.cm2")',
      'Letter::Clear()',
      for (final l in src.sublist(from, to + 1)) l.trim(),
    ].join('\n');
    await engine.loadFromString(body);
    await engine.run();

    expect(ui.letters.last, (color: 10, mode: 3));
    final pics = ui.letterPictures.last!;
    expect(pics, [
      null, // 제목
      [
        [4],
      ],
      [
        [8, 8, 12],
      ],
      [
        [10, 14, 18],
        [11, 15, 19],
      ],
      [
        [9],
      ],
      [
        [23],
      ],
      [
        [22],
      ],
      [
        [26],
      ],
      [
        [25],
      ],
      [
        [16],
        [17],
      ],
    ]);
  });
}
