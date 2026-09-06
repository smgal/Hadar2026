import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hadar2026_app/hd_config.dart';
import 'package:hadar2026_app/presentation/panels/battle/battle_controller.dart';
import 'package:hadar2026_app/presentation/panels/battle/battle_screen.dart';

/// B4-01 — 화면이 실제로 붙고, 눌러서 한 판을 굴릴 수 있는가.
///
/// 콘솔이 보여 주는 것을 화면도 보여야 한다("표현 격차 0"). 문장·색·메뉴
/// 문구는 `hd_battle_text` 가 만들므로, 여기서 볼 것은 **그것이 화면에
/// 실제로 그려지는가**다.

hb.BattleSetup _setup() => const hb.BattleSetup(
  party: [
    hb.CombatantSnapshot(
      slot: 0,
      name: '슴갈',
      hp: 150,
      maxHp: 150,
      strength: 18,
      powOfWeapon: 10,
      levelPhysical: 1,
      accuracyPhysical: 15,
      weaponKey: 'dagger',
      weaponName: '단도',
      rank: 1,
    ),
    hb.CombatantSnapshot(
      slot: 1,
      name: '유리',
      hp: 90,
      maxHp: 90,
      strength: 12,
      powOfWeapon: 8,
      levelPhysical: 1,
      accuracyPhysical: 15,
      weaponKey: 'dagger',
      weaponName: '단도',
      rank: 3,
    ),
  ],
  enemyKeys: ['orc', 'orc'],
  enemyRanks: [1, 3],
  seed: 3,
);

Future<HDBattleController> _mount(WidgetTester tester) async {
  final controller = HDBattleController(_setup())
    ..pace = Duration.zero
    ..start();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: HDConfig.gameScreenWidth,
          height: HDConfig.gameScreenHeight,
          child: HDBattleScreen(controller: controller),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

/// 화면 어딘가에 이 글이 있는가. `Text.rich` 라 `find.text` 로는 안 잡힌다.
bool _shows(WidgetTester tester, String needle) {
  for (final widget in tester.allWidgets.whereType<Text>()) {
    final span = widget.textSpan;
    if (span != null && span.toPlainText().contains(needle)) return true;
    if ((widget.data ?? '').contains(needle)) return true;
  }
  return false;
}

void main() {
  testWidgets('대열·간격이 화면에 있다 — 위치가 안 보이면 결정을 못 한다', (tester) async {
    final c = await _mount(tester);
    expect(_shows(tester, '간격 0'), isTrue);
    expect(_shows(tester, '[1] 슴갈'), isTrue);
    expect(_shows(tester, '[3] 유리'), isTrue);
    c.dispose();
  });

  testWidgets('적과 일행의 상태가 보인다', (tester) async {
    final c = await _mount(tester);
    expect(_shows(tester, 'Orc'), isTrue);
    expect(_shows(tester, 'HP 150/150'), isTrue);
    expect(_shows(tester, '닿음'), isTrue, reason: '무기가 어디까지 닿는지');
    c.dispose();
  });

  testWidgets('물음이 메뉴로 뜨고, 눌러서 답한다', (tester) async {
    final c = await _mount(tester);
    expect(_shows(tester, '슴갈의 전투 모드'), isTrue);
    expect(_shows(tester, '⚔ 공격 — 단도로'), isTrue);

    await tester.tap(find.textContaining('⚔ 공격 — 단도로'));
    await tester.pump();
    expect(_shows(tester, '공격할 적을 선택하십시오'), isTrue);
    expect(_shows(tester, '거리 0'), isTrue, reason: '무엇을 걸고 있는지');
    c.dispose();
  });

  testWidgets('기술이 길면 묶음 → 항목 두 번 누른다', (tester) async {
    final caster = hb.BattleSetup(
      party: const [
        hb.CombatantSnapshot(
          slot: 0,
          name: '술사',
          hp: 90,
          maxHp: 90,
          sp: 999,
          maxSp: 999,
          esp: 99,
          maxEsp: 99,
          levelMagic: 20,
          levelEsp: 5,
          accuracyMagic: 15,
          weaponKey: 'dagger',
          weaponName: '단도',
          rank: 3,
        ),
      ],
      // 둘 — 하나면 대상을 묻지 않아서(B6-07) 마지막 단언이 볼 것이 없다.
      enemyKeys: ['orc', 'orc'],
      seed: 3,
    );
    final c = HDBattleController(caster)
      ..pace = Duration.zero
      ..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: HDConfig.gameScreenWidth,
            height: HDConfig.gameScreenHeight,
            child: HDBattleScreen(controller: c),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('✨ 기술'));
    await tester.pump();
    expect(_shows(tester, '어떤 기술을'), isTrue, reason: '37줄은 접힌다');
    expect(_shows(tester, '🎯 한 명 공격'), isTrue);
    expect(_shows(tester, '마법 화살'), isFalse, reason: '항목은 아직 안 보인다');
    await tester.tap(find.textContaining('🎯 한 명 공격'));
    await tester.pump();
    expect(_shows(tester, '마법 화살'), isTrue);
    await tester.tap(find.textContaining('마법 화살'));
    await tester.pump();
    expect(c.decision, isA<hb.EnemyTargetDecision>());
    c.dispose();
  });

  testWidgets('한 판을 끝까지 눌러서 굴린다', (tester) async {
    final c = await _mount(tester);
    var guard = 0;
    while (!c.isFinished && guard++ < 500) {
      final decision = c.decision;
      if (decision == null) break;
      // 언제나 첫 항목을 누른다.
      final rows = find.textContaining(') ');
      if (rows.evaluate().isEmpty) break;
      await tester.tap(rows.first);
      await tester.pump();
    }
    expect(c.isFinished, isTrue);
    await tester.pump();
    expect(_shows(tester, '전투 종료'), isTrue);
    c.dispose();
  });
}
