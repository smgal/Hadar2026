@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/battle_bridge/cm2_battle_adapter.dart';
import 'package:hadar2026_app/application/game_session.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/application/scripting/script_engine_adapter.dart';

/// 실제로 출하되는 `assets/Map002.cm2` 를 그대로 굴린다.
///
/// 가짜 스크립트로는 안 되는 것을 잡으려는 테스트다 — **이긴 싸움이 다시
/// 시작되지 않는가.** 앱에서 이겨도 같은 타일이 계속 "적과 교전한다 /
/// 도망간다" 를 다시 물어보던 것이 이 자리였다.

/// 디스크의 진짜 asset 을 그대로 읽는다.
class _RealAssets implements AssetSource {
  @override
  Future<String> loadString(String path) async {
    final file = File(path.startsWith('assets/') ? path : 'assets/$path');
    if (!file.existsSync()) throw Exception('asset not found: ${file.path}');
    return file.readAsStringSync();
  }
}

/// 메뉴에는 늘 1번(= 적과 교전한다)을 답하고, 무엇을 물었는지 세어 둔다.
class _AlwaysFights implements UiHost, PartyMovementHost {
  int menus = 0;
  final List<String> logs = [];

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async {
    logs.add(message);
  }

  @override
  Future<int> showMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    bool clearLogs = true,
  }) async {
    menus++;
    return 1;
  }

  @override
  Future<int> showWindowMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    int? x,
    int? y,
  }) async {
    // 전멸하면 `processGameOver(2)` 가 이 메뉴를 띄우고, 그 끝은
    // `exit(0)` 이다 — 테스트 프로세스가 통째로 죽어서 무엇이 틀렸는지
    // 남지 않는다. 시드를 고정해 이기게 해 두었으므로, 여기에 오면
    // 그 전제가 깨진 것이다.
    if (items.first.contains('어떻게 하시겠습니까')) {
      throw StateError('파티가 졌다 — 고정 시드의 전제가 깨졌다');
    }
    menus++;
    return 1;
  }

  @override
  Future<void> waitForAnyKey() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _AlwaysFights host;

  setUp(() async {
    host = _AlwaysFights();
    HDHosts().bind(ui: host, movement: host, assets: _RealAssets());
    final flags = HDGameSession().gameOption.flags;
    flags.fillRange(0, flags.length, false);
    // 싱글턴이라 앞 테스트의 상처가 남는다. 시드까지 고정해야 이겼는지
    // 졌는지가 실행마다 달라지지 않는다.
    for (final p in HDGameSession().party.players) {
      p.hp = p.maxHp;
      p.sp = p.maxSp;
      p.esp = p.maxEsp;
      p.unconscious = 0;
      p.dead = 0;
    }
    HDCm2BattleAdapter().seedOverride = 3;
    await HDScriptEngine().loadScript('assets/Map002.cm2');
    HDScriptEngine().setTargetPos(23, 21);
    HDScriptEngine().setScriptMode(1); // FLAG_TALK
  });

  tearDown(() {
    HDCm2BattleAdapter().seedOverride = null;
    HDHosts().reset();
  });

  test('이긴 싸움은 다시 시작되지 않는다', () async {
    await HDScriptEngine().run();
    expect(host.menus, greaterThan(1), reason: '첫 번째는 실제로 싸운다');
    expect(
      host.logs.any((l) => l.contains('모두 쓰러졌다')),
      isTrue,
      reason: '이겼다는 것을 스크립트가 받아야 한다',
    );

    host.menus = 0;
    host.logs.clear();
    await HDScriptEngine().run();
    expect(host.menus, 0, reason: '두 번째는 아무것도 묻지 않는다');
    expect(host.logs.any((l) => l.contains('널브러져')), isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));

  // 전투가 끝났는데 「적의 상태」 오버레이가 지도 위에 남아 있었다 — 맵을
  // 바꿔 `init()` 이 불릴 때까지. adapter 가 `active` 를 비우고는 아무에게도
  // 알리지 않아서다. 오버레이는 adapter 를 듣는다; 마지막 알림에서 `active`
  // 가 null 이어야 사라진다.
  test('전투가 끝나면 오버레이가 들을 알림이 한 번 더 온다', () async {
    final adapter = HDCm2BattleAdapter();
    final seen = <bool>[]; // 알림 때마다 active 가 있었는가
    void listen() => seen.add(adapter.active != null);
    adapter.addListener(listen);
    try {
      await HDScriptEngine().run();
    } finally {
      adapter.removeListener(listen);
    }
    expect(seen, contains(true), reason: '전투 중에는 active 가 있다');
    expect(seen.last, isFalse, reason: '끝난 뒤 마지막 알림은 active 없음');
    expect(adapter.active, isNull);
  });

  test('싸우기 전에 누가 나왔는지 먼저 알린다', () async {
    await HDScriptEngine().run();
    final appeared = host.logs.indexWhere((l) => l.contains('나타났다'));
    expect(appeared, isNot(-1), reason: '조우 줄이 있어야 한다');
    expect(
      host.logs.where((l) => l.contains('나타났다')),
      hasLength(1),
      reason: '두 번 찍히면 안 된다',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
