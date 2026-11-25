import 'package:flutter/material.dart';

import '../../application/battle_bridge/cm2_battle_adapter.dart';
import '../../hd_config.dart';
import 'battle/battle_screen.dart';

/// 전투 중에 맵 화면을 덮는다 — 원작처럼 맵을 지우고 적 목록을 그 자리에.
///
/// 전투가 없으면 아무것도 그리지 않는다. 물음과 문장은 평소의 창과 대화
/// 창이 맡는다(`HDBattleRunner` 가 `UiHost` 로 낸다).
class HDBattleOverlay extends StatelessWidget {
  const HDBattleOverlay({super.key});

  static const double _stripHeight = 30;
  static const double _partyHeight = 116;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HDCm2BattleAdapter(),
      builder: (context, child) {
        final battle = HDCm2BattleAdapter().active;
        if (battle == null) return const SizedBox.shrink();
        return SizedBox(
          width: HDConfig.mapViewportWidth,
          height: HDConfig.mapViewportHeight,
          child: ColoredBox(
            color: const Color(0xFF000000),
            child: Column(
              children: [
                SizedBox(
                  height: _stripHeight,
                  child: HDFormationStrip(battle: battle),
                ),
                Expanded(child: HDEnemyPane(battle: battle)),
                SizedBox(
                  height: _partyHeight,
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
