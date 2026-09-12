import 'package:flutter/material.dart';

import '../../application/battle_bridge/cm2_battle_adapter.dart';
import '../../hd_config.dart';
import 'battle/battle_screen.dart';

/// 게임 안의 전투 화면 (B4-02).
///
/// ## 실험실과 같은 위젯을 쓴다
///
/// 대열 줄 · 적 목록 · 일행 목록은 `battle_lab_main.dart` 가 띄우는 것과
/// **같은 위젯**이다(`HDFormationStrip` · `HDEnemyPane` · `HDPartyPane`).
/// 실험실에서 눌러 본 것이 게임에서 다르게 보이면 실험실의 뜻이 없다.
///
/// ## 묻는 것은 이 화면이 아니다
///
/// 실험실은 화면에 단추를 놓고 마우스로 답하지만, 게임은 `HDBattleRunner` 가
/// `UiHost.showWindowMenu` 로 묻는다 — 키보드와 가상 D-pad 가 이미 그 창을
/// 몰고 있어서 전투 전용 입력 경로를 새로 만들지 않는다.
///
/// 그래서 여기 있는 것은 **읽는 것뿐**이다. 결정층도 조작 단추도 없다.
/// 로그도 없다 — 게임에는 콘솔이 따로 있고 전투 문장이 그리로 간다.
class HDBattleOverlay extends StatelessWidget {
  const HDBattleOverlay({super.key});

  static const double _stripHeight = 40;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HDCm2BattleAdapter(),
      builder: (context, child) {
        final battle = HDCm2BattleAdapter().active;
        if (battle == null) return const SizedBox.shrink();

        // 지도 뷰포트 안에 들어간다. 콘솔은 가리지 않는다 — 전투 문장이
        // 거기서 흐르고 창 메뉴도 그 위에 뜬다.
        return SizedBox(
          width: HDConfig.mapViewportWidth,
          height: HDConfig.mapViewportHeight,
          child: ColoredBox(
            color: const Color(0xFF0A0A0A),
            child: Column(
              children: [
                SizedBox(
                  height: _stripHeight,
                  child: HDFormationStrip(battle: battle),
                ),
                Expanded(child: HDEnemyPane(battle: battle)),
                SizedBox(
                  height: 96,
                  child: HDPartyPane(battle: battle),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
