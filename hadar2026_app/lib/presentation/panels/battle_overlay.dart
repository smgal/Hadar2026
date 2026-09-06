import 'package:flutter/material.dart';
import '../../application/battle_bridge/cm2_battle_adapter.dart';

class HDBattleOverlay extends StatelessWidget {
  const HDBattleOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HDCm2BattleAdapter(),
      builder: (context, child) {
        // B3-01 이후 적의 상태는 새 전투 model 이 들고 있다. 열 정보까지
        // 함께 보여 주는 제대로 된 view 는 B4-01 이다.
        final battle = HDCm2BattleAdapter().active;
        if (battle == null) return const SizedBox.shrink();

        final enemies = battle.enemies;
        const selectedIx = -1;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.8), // Cover map partially or fully
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "적의 상태",
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: enemies.length,
                  itemBuilder: (context, index) {
                    final e = enemies[index];
                    final isSelected = (index == selectedIx);

                    String status = "의식 있음";
                    Color statusColor = Colors.green;

                    if (e.dead > 0) {
                      status = "사망";
                      statusColor = Colors.red;
                    } else if (e.unconscious > 0) {
                      status = "의식 불명";
                      statusColor = Colors.orange;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${e.name}  ${e.rank}열',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.cyanAccent
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            status,
                            style: TextStyle(color: statusColor, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
