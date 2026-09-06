import 'package:flutter_test/flutter_test.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hadar2026_app/application/battle_bridge/cm2_battle_adapter.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';

/// 찍힌 줄만 모으는 최소 host. 나머지 포트를 건드리면 바로 드러난다.
class _Lines implements UiHost, PartyMovementHost {
  final List<String> logs = [];

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async {
    logs.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoAssets implements AssetSource {
  @override
  Future<String> loadString(String path) async =>
      throw UnimplementedError(path);
}

/// B3-01 — cm2 동사 다섯 개. **콘텐츠 53곳을 한 줄도 안 고친다.**
void main() {
  final adapter = HDCm2BattleAdapter();

  setUp(adapter.init);

  group('Battle::Result 의 와이어 값은 const.cm2 가 정본이다', () {
    test('전투 전에는 미결(-1) — 승리가 기본값이면 안 된다', () {
      // P0-13: 예전 구현은 전투 없이도 이긴 것으로 나왔다.
      expect(adapter.result(), -1);
    });

    test('네 값의 의미가 규격과 같다', () {
      expect(hb.BattleResultCode.evade.wire, 0);
      expect(hb.BattleResultCode.win.wire, 1);
      expect(hb.BattleResultCode.lose.wire, 2);
      expect(hb.BattleResultCode.none.wire, -1);
    });
  });

  group('Battle::RegisterEnemy', () {
    test('id 0 도 등록된다 — 예전 가드가 Orc 을 막았다 (P0-15)', () {
      adapter.registerEnemy(0);
      expect(adapter.enemyKeys, ['orc']);
    });

    test('표 전체 0~74 가 유효하다', () {
      for (var id = 0; id < 75; id++) {
        adapter.init();
        adapter.registerEnemy(id);
        expect(adapter.enemyKeys, hasLength(1), reason: 'id $id');
      }
    });

    test('범위 밖은 경고를 남기고 무시한다 — 조용히 삼키지 않는다', () {
      adapter.registerEnemy(75);
      adapter.registerEnemy(-1);
      expect(adapter.enemyKeys, isEmpty);
    });

    test('같은 적을 여러 번 등록하는 것이 정상이다', () {
      // L1_ep1d0.cm2:367-403 이 legacyId 26 을 일곱 번 부른다.
      for (var i = 0; i < 7; i++) {
        adapter.registerEnemy(26);
      }
      expect(adapter.enemyKeys, hasLength(7));
      expect(adapter.enemyKeys.toSet(), hasLength(1));
    });

    test('원작 스크립트가 실제로 쓰는 id 가 전부 산다', () {
      // 출하된 cm2 전체에서 쓰이는 값: 1 · 3 · 5 · 7 · 26 · 69 · 71.
      for (final id in [1, 3, 5, 7, 26, 69, 71]) {
        adapter.init();
        adapter.registerEnemy(id);
        expect(adapter.enemyKeys, hasLength(1), reason: 'id $id');
      }
    });
  });

  group('Battle::Init', () {
    test('판과 결과를 함께 비운다', () {
      adapter.registerEnemy(0);
      adapter.init();
      expect(adapter.enemyKeys, isEmpty);
      expect(adapter.result(), -1);
      expect(adapter.lastOutcome, isNull);
    });
  });

  group('Battle::ShowEnemy', () {
    late _Lines host;

    setUp(() {
      host = _Lines();
      HDHosts().bind(ui: host, movement: host, assets: _NoAssets());
    });
    tearDown(HDHosts().reset);

    // 이 동사가 따로 있는 이유가 이것이다 — `Map002.cm2` 는 `ShowEnemy` 와
    // `Battle::Start` 사이에서 "적과 교전한다 / 도망간다" 를 묻는다. 누가
    // 나왔는지 모른 채 싸울지 말지를 고르면 그 물음이 의미를 잃는다.
    test('싸울지 묻기 전에 누가 나왔는지 알린다', () async {
      adapter.registerEnemy(5);
      adapter.registerEnemy(7);
      await adapter.showEnemy();
      expect(host.logs, hasLength(1));
      expect(host.logs.single, contains('나타났다'));
    });

    test('같은 이름은 묶인다 — 문장은 콘솔과 같은 것을 쓴다', () async {
      for (var i = 0; i < 3; i++) {
        adapter.registerEnemy(26);
      }
      await adapter.showEnemy();
      expect(host.logs.single, contains('x 3'));
    });

    test('등록된 적이 없으면 아무 줄도 안 낸다', () async {
      await adapter.showEnemy();
      expect(host.logs, isEmpty);
    });
  });
}
