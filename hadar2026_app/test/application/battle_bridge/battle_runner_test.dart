import 'package:flutter_test/flutter_test.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_battle_text/hd_battle_text.dart' as tx;
import 'package:hadar2026_app/application/battle_bridge/battle_runner.dart';
import 'package:hadar2026_app/application/battle_bridge/setup_assembly.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/domain/party/party.dart';

/// 메뉴에는 늘 같은 번호를 답하고, 찍힌 줄을 다 모아 두는 화면.
///
/// **이것이 헤드리스 이음매다** — `packages/hd_battle` 이 화면을 모르고,
/// 이 운전자가 `UiHost` 하나만 보기 때문에 Flutter 없이 전투가 굴러간다.
class _ScriptedUi implements UiHost {
  _ScriptedUi({this.answer = 1});

  final int answer;
  final List<String> logs = [];
  final List<List<String>> menus = [];
  int refreshes = 0;
  int reads = 0;
  int clears = 0;

  @override
  Future<int> showWindowMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    int? x,
    int? y,
  }) async {
    menus.add(items);
    final choices = items.length - 1;
    return choices <= 0 ? 0 : (answer > choices ? 1 : answer);
  }

  @override
  Future<void> waitForAnyKey() async => reads++;

  @override
  void clearLogs() => clears++;

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async {
    logs.add(message);
  }

  @override
  void refresh() => refreshes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'the battle runner should only need showWindowMenu / addLog / '
    'waitForAnyKey / clearLogs / refresh, but it called '
    '${invocation.memberName}',
  );
}

void main() {
  hb.BattleSetup setupFor(List<String> enemies, {int seed = 3}) =>
      assembleSetup(party: HDParty(), enemyKeys: enemies, seed: seed);

  group('운전자가 전투를 끝까지 굴린다', () {
    test('메뉴를 물어보고 답을 model 로 돌려준다', () async {
      final ui = _ScriptedUi();
      final outcome = await HDBattleRunner(ui).run(setupFor(['orc', 'orc']));

      expect(ui.menus, isNotEmpty, reason: '물어본 것이 있어야 한다');
      expect(ui.logs, isNotEmpty, reason: '찍힌 줄이 있어야 한다');
      expect(outcome.resultCode, isNot(hb.BattleResultCode.none));
    });

    // 시작 파티의 슴갈은 마법 20 · ESP 20 이라 기술이 37줄이다. 8줄을 넘으면
    // 범위 묶음을 먼저 묻는다 — 규칙은 `hd_battle_text`, 세 view 가 같다.
    test('기술이 길면 묶음을 먼저 묻는다', () async {
      // 2 = 최상위의 ✨ 기술, 묶음의 두 번째(💥 전체 공격), 그 안의 두 번째.
      final ui = _ScriptedUi(answer: 2);
      await HDBattleRunner(ui).run(setupFor(['orc', 'orc']));
      final headers = ui.menus.map((m) => m.first).toList();
      expect(headers, contains(tx.skillGroupMenuHeader));
      expect(headers.any((h) => h.startsWith('💥 전체 공격')), isTrue);
      // 유리처럼 기술이 몇 개뿐인 사람은 접지 않고 바로 목록이다 — 그래서
      // `기술 ===>` 도 함께 나오는 것이 맞다. 접힌 쪽만 확인한다.
    });

    test('규칙은 이 파일에 한 줄도 없다 — 화면 port 몇 개만 쓴다', () async {
      // noSuchMethod 가 던지므로, 다른 것을 부르면 이 테스트가 깨진다.
      final ui = _ScriptedUi();
      await HDBattleRunner(ui).run(setupFor(['orc']));
    });

    // cm2 는 `Battle::ShowEnemy` 로 **싸울지 묻기 전에** 조우를 알린다.
    // 그때 model 이 개시하며 내는 같은 줄까지 찍으면 두 번 나온다.
    test('조우 알림을 이미 낸 쪽이 있으면 그 줄을 버린다', () async {
      final ui = _ScriptedUi();
      await HDBattleRunner(ui, suppressAppearance: true).run(setupFor(['orc']));
      expect(ui.logs.any((l) => l.contains('나타났다')), isFalse);
      expect(ui.logs, isNotEmpty, reason: '나머지 줄은 그대로 나온다');
    });

    test('문장이 hd_battle_text 에서 온다 — 콘솔과 같은 문구다', () async {
      final ui = _ScriptedUi();
      await HDBattleRunner(ui).run(setupFor(['orc']));
      expect(ui.logs.any((l) => l.contains('나타났다')), isTrue, reason: '조우 줄');
    });

    test('색 표기를 붙여 낸다 — 원작의 writeConsole 색 번호다', () async {
      final ui = _ScriptedUi();
      await HDBattleRunner(ui).run(setupFor(['orc']));
      expect(ui.logs.any((l) => l.contains('@')), isTrue);
    });

    test('읽을 시간을 준다 — 안 그러면 줄이 스쳐 지나간다', () async {
      // 5인 파티면 한 라운드에 열 줄이 넘는다. 옛 전투가 턴 끝마다
      // waitForAnyKey 를 부른 것과 같은 리듬이어야 한다.
      final ui = _ScriptedUi();
      await HDBattleRunner(ui).run(setupFor(['orc', 'orc']));
      expect(ui.reads, greaterThan(0));
    });

    test('라운드가 열리면 앞 라운드 줄을 치운다', () async {
      final ui = _ScriptedUi();
      await HDBattleRunner(ui).run(setupFor(['giant']));
      expect(ui.clears, greaterThan(0));
    });

    test('메뉴는 지도 위에 뜨는 팝업이다 — 옛 전투와 같다', () async {
      final ui = _ScriptedUi();
      await HDBattleRunner(ui).run(setupFor(['orc']));
      expect(ui.menus, isNotEmpty);
    });

    test('진행 콜백이 화면 갱신에 쓸 수 있게 불린다', () async {
      final ui = _ScriptedUi();
      var steps = 0;
      hb.Battle? started;
      await HDBattleRunner(
        ui,
        onBattleStarted: (b) => started = b,
        onStep: () => steps++,
      ).run(setupFor(['orc']));
      expect(started, isNotNull);
      expect(steps, greaterThan(0));
    });

    test('취소로만 답해도 멈추지 않는다', () async {
      // 전원이 취소하면 아무도 안 때리지만 적은 계속 때리므로 끝난다.
      final ui = _ScriptedUi(answer: 0);
      final outcome = await HDBattleRunner(ui).run(setupFor(['giant']));
      expect(outcome.resultCode, isNot(hb.BattleResultCode.none));
    });
  });

  group('전투가 파티를 직접 고치지 않는다', () {
    test('정산을 반영하기 전에는 파티가 그대로다', () async {
      final party = HDParty();
      final before = [for (final p in party.players) p.hp];
      final ui = _ScriptedUi();
      await HDBattleRunner(
        ui,
      ).run(assembleSetup(party: party, enemyKeys: const ['giant'], seed: 5));
      expect(
        [for (final p in party.players) p.hp],
        before,
        reason: '전투는 스냅샷만 보고, 되쓰기는 applyOutcome 이 한다',
      );
    });
  });
}
