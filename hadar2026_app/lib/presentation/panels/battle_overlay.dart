import 'package:flutter/material.dart';
import '../../application/battle.dart';

class HDBattleOverlay extends StatelessWidget {
  const HDBattleOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HDBattle(),
      builder: (context, child) {
        if (!HDBattle().isBattleActive) return const SizedBox.shrink();

        final enemies = HDBattle().enemies;
        final selectedIx = HDBattle().selectedEnemyIndex;

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
                  fontSize: 18,
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
                            e.name,
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
                            style: TextStyle(color: statusColor, fontSize: 14),
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
