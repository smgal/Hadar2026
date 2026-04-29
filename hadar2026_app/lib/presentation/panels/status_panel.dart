import 'package:flutter/material.dart';
import '../../hd_game_main.dart';
import '../../hd_config.dart';

class HDStatusPanel extends StatelessWidget {
  const HDStatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HDConfig.statusPanelWidth,
      height: HDConfig.statusPanelHeight,
      color: Colors.black,
      child: ListenableBuilder(
        listenable: HDGameMain().party,
        builder: (context, child) {
          final party = HDGameMain().party;
          final players = party.players;

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    _buildHeaderLabel("name", 184),
                    _buildHeaderLabel("hp", 80),
                    _buildHeaderLabel("sp", 80),
                    _buildHeaderLabel("esp", 80),
                  ],
                ),
              ),
              // Character slots (up to 6)
              ...List.generate(6, (index) {
                if (index < players.length && players[index].isValid()) {
                  final p = players[index];
                  return _buildMemberRow(
                    p.name,
                    p.hp,
                    p.maxHp,
                    p.sp,
                    p.maxSp,
                    p.esp,
                  );
                } else {
                  return _buildMemberRow(
                    "Reserved",
                    0,
                    0,
                    0,
                    0,
                    0,
                    isRed: true,
                  );
                }
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderLabel(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildMemberRow(
    String name,
    int hp,
    int maxHp,
    int sp,
    int maxSp,
    int esp, {
    bool isRed = false,
  }) {
    final textColor = isRed ? Colors.red : Colors.white;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildCell(name, 184, color: textColor, hasBackground: !isRed),
          _buildCell(
            hp.toString(),
            80,
            align: TextAlign.right,
            hasBackground: !isRed,
          ),
          _buildCell(
            sp.toString(),
            80,
            align: TextAlign.right,
            hasBackground: !isRed,
          ),
          _buildCell(
            esp.toString(),
            80,
            align: TextAlign.right,
            hasBackground: !isRed,
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text,
    double width, {
    Color color = Colors.white,
    TextAlign align = TextAlign.left,
    bool hasBackground = false,
  }) {
    return Container(
      width: width,
      height: 20,
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: hasBackground
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade700,
                  Colors.blue.shade900,
                ],
              ),
              border: Border.all(color: Colors.blue.shade400, width: 0.5),
            )
          : null,
      alignment: align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: HDConfig.statusFontSize,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
