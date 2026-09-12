import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/presentation/panels/battle/battle_screen.dart';
import 'package:hd_battle/hd_battle.dart' as hb;

/// B4-02 — 게임 안의 전투 화면이 실험실과 **같은 위젯**을 쓴다.
///
/// 여기서 확인하는 것은 그 위젯들이 컨트롤러 없이, 살아 있는 판 하나만으로
/// 그려지는가다. 그것이 성립해야 게임 쪽 오버레이가 실험실 코드를 베끼지
/// 않고 쓸 수 있다.
hb.Battle _battle() {
  final b = hb.Battle(
    const hb.BattleSetup(
      party: [
        hb.CombatantSnapshot(
          slot: 0,
          name: '아트리아',
          hp: 200,
          maxHp: 200,
          strength: 16,
          powOfWeapon: 35,
          levelPhysical: 3,
          accuracyPhysical: 14,
          weaponKey: 'sword_shield',
        ),
        hb.CombatantSnapshot(
          slot: 4,
          name: '유리',
          hp: 160,
          maxHp: 160,
          strength: 12,
          powOfWeapon: 45,
          levelPhysical: 3,
          accuracyPhysical: 16,
          weaponKey: 'bow',
        ),
      ],
      enemyKeys: ['orc', 'wolf'],
      seed: 3,
    ),
  );
  // 첫 물음까지 굴린다 — 그려질 상태가 있어야 한다.
  while (b.pendingDecision == null && !b.isFinished) {
    b.advance();
  }
  return b;
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 480, child: child)),
);

void main() {
  testWidgets('대열 줄이 두 진영과 간격을 보인다', (tester) async {
    final battle = _battle();
    await tester.pumpWidget(_wrap(HDFormationStrip(battle: battle)));
    expect(find.textContaining('간격'), findsOneWidget);
    expect(find.textContaining('아트리아'), findsOneWidget);
    expect(find.textContaining('Orc'), findsOneWidget);
  });

  testWidgets('적 목록이 열과 상태를 보인다', (tester) async {
    final battle = _battle();
    await tester.pumpWidget(_wrap(HDEnemyPane(battle: battle)));
    expect(find.textContaining('Orc'), findsOneWidget);
    expect(find.textContaining('열'), findsWidgets);
    expect(find.textContaining('HP'), findsWidgets);
  });

  testWidgets('일행 목록이 사거리를 계산해 준다 — 셈은 플레이어의 일이 아니다', (
    tester,
  ) async {
    final battle = _battle();
    await tester.pumpWidget(_wrap(HDPartyPane(battle: battle)));
    expect(find.textContaining('아트리아'), findsOneWidget);
    expect(find.textContaining('유리'), findsOneWidget);
    // 활은 3열에서도 닿고, 검과 방패는 앞열에서만 닿는다.
    expect(find.textContaining('닿'), findsWidgets);
  });

  testWidgets('조작 줄이 없으면 그리지 않는다 — 게임 안에서는 창 메뉴가 묻는다', (
    tester,
  ) async {
    final battle = _battle();
    await tester.pumpWidget(_wrap(HDPartyPane(battle: battle)));
    expect(find.text('한 수 물리기'), findsNothing);
    expect(find.text('처음부터'), findsNothing);
  });
}
