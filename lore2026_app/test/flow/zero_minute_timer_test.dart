import 'package:flutter_test/flutter_test.dart';
import 'package:lore2026_app/application/field_rules.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/tile_event_dispatcher.dart';
import 'package:lore2026_app/application/title_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_hosts.dart';

/// `Timer::Set(번호, 0)` 은 걸어 둔 스크립트가 끝나는 대로 울린다.
///
/// 3편 엔딩 다섯 개가 이 길로 불린다 — 대화(`FLAG_TALK`)가 끝난 뒤의 엔딩 C,
/// 맵에 들어선 직후(`FLAG_MAP`)의 엔딩 A · B. 전에는 한 걸음을 더 걸어야
/// 엔딩이 나왔다.
///
/// 시험은 엔딩 C(예약 번호 13)를 쓴다. 엔딩까지 가는 길(로드안과의 결전)을
/// 걷는 대신 예약을 먼저 걸어 두고, 엔딩과 상관없는 스크립트 하나를
/// 끝나게 한다.
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

const _endingC = '나는 로어성을 뒤로한 채 혼자만의 여행을 떠나고 있다.';

void main() {
  // 엔딩은 본 엔딩 목록을 저장소에 적는다 — 시험에서는 메모리 저장소를 쓴다.
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScriptedUi ui;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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

  /// 엔딩은 제목 화면으로 돌아가며 제목 흐름을 새로 띄운다. 그 흐름이
  /// 정해 둔 답으로 첫 맵까지 가서 멈출 때까지 기다린다 — 그러지 않으면
  /// [HDHosts.reset] 뒤에 화면을 찾다가 시험이 끝난 뒤에 실패한다.
  Future<void> waitForTitleRerun() async {
    final engine = HDScriptEngine();
    for (var i = 0; i < 300 && engine.pendingNavigation == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(engine.pendingNavigation?.path, 'E3_Menace');
  }

  test('대화가 끝나면 0분 예약이 걸음 없이 울린다', () async {
    await HDTitleFlow().run();
    await HDScriptEngine().executePendingNavigation();
    final session = HDGameSession();
    final (x, y) = (session.party.x, session.party.y);

    session.setTimer(13, 0);
    // (27,32) 의 광산 감독에게 부딪힌다 — 엔딩과 상관없는 대화다.
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: 26,
      y: 31,
      isInteraction: true,
    );

    // 감독의 말이 먼저, 엔딩 C 가 그 뒤에 나왔다. 일행은 한 걸음도 걷지 않았다.
    final talk = ui.plainLines.indexOf('광산 감독 : 오, 슴갈.');
    final ending = ui.plainLines.indexOf(_endingC);
    expect(talk, isNonNegative);
    expect(ending, greaterThan(talk));
    expect(ui.plainLines.any((l) => l.contains('<< The End >>')), isTrue);
    // 오프닝 편지는 흰 글씨로 위로 흐르고, 엔딩 C 는 노란 글씨에 번개다 (13 §13.7 · §13.10)
    expect(ui.letters.first, (color: 15, mode: 1));
    expect(ui.letters.last, (color: 14, mode: 2));
    expect((session.party.x, session.party.y), (x, y));
    expect(session.timer, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('lore2026_endings'), contains('ep3:C'));

    await waitForTitleRerun();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('맵에 들어선 직후 0분 예약이 울린다', () async {
    await HDTitleFlow().run();
    final engine = HDScriptEngine();
    await engine.executePendingNavigation();
    final session = HDGameSession();

    session.setTimer(13, 0);
    // 맵을 옮기는 스크립트(LoadScript)가 끝난 것과 같은 상태 — 아직 울리지 않는다.
    engine.pendingNavigation = (
      path: 'E3_Menace',
      hasExplicit: true,
      nx: 26,
      ny: 28,
    );
    session.clearCurrentMap();
    expect(ui.plainLines, isNot(contains(_endingC)));

    // 새 맵에 들어서고 그 맵의 FLAG_MAP 이 끝나면 울린다.
    await engine.executePendingNavigation();
    final arrived = ui.plainLines.lastIndexOf('여기는 로어 대륙의 메너스 금광.');
    final ending = ui.plainLines.indexOf(_endingC);
    expect(arrived, isNonNegative);
    expect(ending, greaterThan(arrived));
    expect(session.timer, isNull);

    await waitForTitleRerun();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('맵을 옮기는 중이면 예약은 새 맵까지 기다린다', () async {
    await HDTitleFlow().run();
    final engine = HDScriptEngine();
    await engine.executePendingNavigation();
    final session = HDGameSession();

    // (25,45) 출구 줄 — 살인 누명 장면이 로어성으로 옮긴다(LoadScript).
    session.setTimer(13, 0);
    session.party.setPosition(24, 43);
    await HDTileEventDispatcher().check(
      map: session.map,
      party: session.party,
      host: ui,
      x: 24,
      y: 44,
    );
    expect(engine.pendingNavigation?.path, 'E3_Lore');
    expect(ui.plainLines, isNot(contains(_endingC)));
    expect(session.timer, isNotNull);

    // 로어성의 재판 장면(FLAG_MAP)이 끝난 뒤에 엔딩이 나온다.
    await engine.executePendingNavigation();
    final trial = ui.plainLines.indexOf('로드안이 병사에게 말했다.');
    final ending = ui.plainLines.indexOf(_endingC);
    expect(trial, isNonNegative);
    expect(ending, greaterThan(trial));

    await waitForTitleRerun();
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('Arrival::Say — 도착한 맵의 시작 스크립트가 끝난 뒤에 나오고, 0분 예약보다 먼저다', () async {
    await HDTitleFlow().run();
    final engine = HDScriptEngine();
    await engine.executePendingNavigation();
    final session = HDGameSession();

    engine.arrivalLines.add('도착한 뒤에 듣는 말.');
    session.setTimer(13, 0);
    engine.pendingNavigation = (
      path: 'E3_Menace',
      hasExplicit: true,
      nx: 26,
      ny: 28,
    );
    session.clearCurrentMap();
    final before = ui.plainLines.length;
    await engine.executePendingNavigation();

    final lines = ui.plainLines.sublist(before);
    final arrived = lines.indexOf('여기는 로어 대륙의 메너스 금광.');
    final said = lines.indexOf('도착한 뒤에 듣는 말.');
    final ending = lines.indexOf(_endingC);
    expect(arrived, isNonNegative);
    expect(said, greaterThan(arrived));
    expect(ending, greaterThan(said));
    expect(engine.arrivalLines, isEmpty);

    await waitForTitleRerun();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('예약 2(도시 건설) — 에인션트 이블의 말은 세워진 도시에 들어선 뒤에 나온다', () async {
    await HDTitleFlow().run();
    final engine = HDScriptEngine();
    await engine.executePendingNavigation();
    final session = HDGameSession();
    const built = '에인션트 이블 : 휴... 저의 염력을 총동원하여 어느 정도 사람이 살 수 있는 도시를 건설해 보았습니다. 이제는 배리언트 피플즈의 사람들을 여기로 공간 이동시켜 보겠습니다. 이번에도 조금 기다려야 할 것입니다.';

    session.setTimer(2, 0);
    await HDFieldRules().fireDueTimerNow();
    // 예약 사건은 말을 쌓아 두고 돔으로 옮긴다 — 아직 말하지 않았다
    expect(engine.pendingNavigation?.path, 'E3_Dome');
    expect(ui.plainLines.any((l) => l.startsWith('에인션트 이블 : 휴...')), isFalse);
    expect(engine.arrivalLines, hasLength(1));

    await engine.executePendingNavigation();
    expect(session.mapInfo?.name, 'E3_Dome');
    expect(session.gameOption.variable('DOME_STAGE'), 2);
    expect(ui.plainLines.where((l) => l == built), hasLength(1));
    expect(engine.arrivalLines, isEmpty);
    // 다음 예약(30분 뒤 주민 이주)이 걸려 있다
    expect(session.timer?.id, 3);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('결말 A 에필로그 — 주인공 그림을 감춘 채 화면만 흐르고, 엔딩 A 뒤 다시 보인다', () async {
    await HDTitleFlow().run();
    final engine = HDScriptEngine();
    await engine.executePendingNavigation();
    final session = HDGameSession();
    session.gameOption.variables['ALLEGIANCE'] = 1;

    // 로어성의 결말 A 가 넘겨주는 자리 — 하데스 테라 (31,21)
    engine.pendingNavigation = (path: 'E3_UnderGrd', hasExplicit: true, nx: 30, ny: 20);
    session.clearCurrentMap();
    await engine.executePendingNavigation();
    expect(session.party.hidden, isTrue);
    expect(engine.pendingNavigation?.path, 'E3_Dome');

    // 빛의 지붕 — 화면이 내려가고 예약 11(0분)이 두 악마의 대화와 엔딩 A 를 낸다
    await engine.executePendingNavigation();
    expect(
      ui.plainLines.any((l) => l.startsWith('메피스토펠레스 : 아스모데우스여')),
      isTrue,
    );
    expect(ui.plainLines.any((l) => l.contains('<< The End >>')), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('lore2026_endings'), contains('ep3:A'));
    // 제목으로 돌아가면 일행 그림이 다시 보인다
    expect(session.party.hidden, isFalse);

    await waitForTitleRerun();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
