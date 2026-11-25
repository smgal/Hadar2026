import 'package:flutter_test/flutter_test.dart';
import 'package:lore_battle/lore_battle.dart' as lb;
import 'package:lore_world/lore_world.dart';
import 'package:lore2026_app/application/battle_bridge/cm2_battle_adapter.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';

import '../flow/fake_hosts.dart';

/// `BATTLE_REPEAT` — 도망에 성공해도 남은 적(입힌 피해 그대로)과 다시 싸운다.
/// `BATTLE_RENEW` — 이기면 처음 편성이 새로 덤벼 온다. 도망에 성공하거나 지면 끝난다.
/// `Battle::EnemyDown` · `Battle::Downed` — 도망쳤어도 쓰러진 적을 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int escapesLeft;
  late ScriptedUi ui;

  /// 이 문장이 [fleeAfter] 번 나오기 전에는 도망치지 않는다 (null 이면 보지 않는다).
  String? waitLine;
  var fleeAfter = 0;
  int seen(String line) => ui.plainLines.where((l) => l.contains(line)).length;

  int answer(List<String> items) {
    final options = items.skip(1).toList();
    final flee = options.indexWhere((o) => o.contains('도망'));
    final attack = options.indexWhere((o) => o.contains('공격'));
    final ready = waitLine == null || seen(waitLine!) >= fleeAfter;
    if (flee >= 0 && escapesLeft > 0 && ready) {
      escapesLeft--;
      return flee + 1;
    }
    if (attack >= 0) return attack + 1;
    return 1;
  }

  setUp(() async {
    ui = ScriptedUi(answer);
    HDHosts().bind(
      ui: ui,
      movement: InstantMovement(HDGameSession().party.move),
      assets: DiskAssets(),
    );
    // 오크 셋쯤은 이기는 주인공 — 승패가 아니라 전투의 이어짐을 본다
    final hero = rosterEp1['hercules']!.build()..level = 15;
    hero.hp = 9999;
    final world = LoreWorld.newGame(Episode.ep1, hero);
    world.give('weapon.long_sword');
    world.equip(0, 'weapon.long_sword');
    HDGameSession().party.world = world;
    HDCm2BattleAdapter().init();
  });

  tearDown(() {
    waitLine = null;
    fleeAfter = 0;
    HDCm2BattleAdapter().seedOverride = null;
    HDHosts().reset();
  });

  test('이기면 쓰러뜨린 적이 등록 순서대로 기록된다', () async {
    escapesLeft = 0;
    final a = HDCm2BattleAdapter()..seedOverride = 7;
    a.registerEnemy(1);
    a.registerEnemy(1);
    await a.start(HDBattleFlag.noPrelude | HDBattleFlag.loseOk);
    expect(a.result(), 1); // BATTLERESULT_WIN
    expect(a.enemyDown(1), isTrue);
    expect(a.enemyDown(2), isTrue);
    expect(a.enemiesDown(), 2);
  });

  for (final seed in [3, 11, 19, 27, 35]) {
    test('반복: 도망에 성공해도 끝나지 않고 이길 때까지 이어진다 (난수 $seed)', () async {
      escapesLeft = 6;
      final a = HDCm2BattleAdapter()
        ..seedOverride = seed
        ..repeatText = '그러나 도망칠 수 없었다.';
      a.registerEnemy(1);
      a.registerEnemy(1);
      a.registerEnemy(1);
      await a.start(
        HDBattleFlag.noPrelude | HDBattleFlag.repeat | HDBattleFlag.loseOk,
      );
      // 반복 전투는 도망으로 끝나지 않는다 — 이 난수들에서는 도망이 한 번 이상 성공해 다시 붙고, 끝내 이긴다
      final repeats = ui.plainLines
          .where((l) => l.contains('그러나 도망칠 수 없었다.'))
          .length;
      expect(repeats, greaterThan(0));
      expect(a.result(), 1); // BATTLERESULT_WIN
      expect(a.enemiesDown(), 3);
    });
  }

  test('새 편성: 이기면 처음 편성이 다시 덤벼 오고, 도망에 성공해야 끝난다', () async {
    const renewLine = '새 코볼트킹이 앞을 가로막았다.';
    escapesLeft = 50;
    waitLine = renewLine;
    fleeAfter = 2; // 두 번 이긴 뒤부터 도망친다
    final a = HDCm2BattleAdapter()
      ..seedOverride = 5
      ..renewText = renewLine;
    a.registerEnemy(1);
    a.registerEnemy(1);
    await a.start(HDBattleFlag.noPrelude | HDBattleFlag.renew);
    expect(seen(renewLine), 2);
    expect(a.result(), 0); // BATTLERESULT_EVADE
    // 마지막 판(도망친 판)의 적은 새로 편성된 두 마리다 — 앞 판에서 쓰러진 기록이 남지 않는다
    expect(a.enemiesDown(), lessThan(2));
  });

  test('반복: 머리말에서 도망쳐도 끝나지 않는다 (코볼트킹의 결계)', () async {
    escapesLeft = 1; // 머리말의 「도망간다」 한 번만
    HDGameSession().party.world.protagonist!.abilities[7] = 99; // 행운 — 머리말 도망이 반드시 성공
    final a = HDCm2BattleAdapter()
      ..seedOverride = 9
      ..repeatText = '결계를 벗어날 수가 없었다.';
    a.registerEnemy(1);
    await a.start(HDBattleFlag.repeat);
    expect(seen('일행은 무사히 도망쳤다.'), 1);
    expect(seen('결계를 벗어날 수가 없었다.'), 1);
    expect(a.result(), 1); // BATTLERESULT_WIN
  });

  test('새 편성 없이 머리말에서 도망치면 그대로 끝난다', () async {
    escapesLeft = 1;
    HDGameSession().party.world.protagonist!.abilities[7] = 99;
    final a = HDCm2BattleAdapter()..seedOverride = 9;
    a.registerEnemy(1);
    await a.start(HDBattleFlag.renew);
    expect(seen('일행은 무사히 도망쳤다.'), 1);
    expect(a.result(), 0); // BATTLERESULT_EVADE
  });

  test('ability_clone — 그 적이 원래 가진 능력은 두고 분신을 붙이고 뗀다', () async {
    final hero = rosterEp1['hercules']!.build();
    HDGameSession().party.world = LoreWorld.newGame(Episode.ep3, hero);
    final a = HDCm2BattleAdapter()..init();
    a.registerEnemy(58); // 아키드라코니안 — 17대 드라콘제왕의 바탕
    final base = lb.enemyByLegacyId(3, 58)!.abilities;
    expect(base, isNot(contains(lb.EnemyAbility.clone)));

    expect(a.overrideEnemy(1, 'ability_clone', 1), isTrue);
    expect(a.overrideAt(1)!.abilities, {...base, lb.EnemyAbility.clone});

    expect(a.overrideEnemy(1, 'ability_clone', 0), isTrue);
    expect(a.overrideAt(1)!.abilities, base);

    // 모르는 능력 이름은 거절한다
    expect(a.overrideEnemy(1, 'ability_fly', 1), isFalse);
  });
}
