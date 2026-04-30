import 'package:flutter/material.dart';
import '../../domain/party/player.dart';
import '../../hd_game_main.dart';
import '../../hd_config.dart';

/// Retro DOS-RPG palette for the status strip.
///
/// Six rows:
///   index 0–4 → ordinary party slots (up to 5 members).
///   index 5   → summon slot — temporary entity, not a real party member,
///               so it gets a distinct purple/violet tint to set it apart.
///
/// Empty party slots are drawn as nearly-invisible frames so the grid
/// shape is preserved without competing for attention. The summon slot
/// keeps its tint even when empty, so the player can tell at a glance
/// "이 자리는 일반 파티원이 들어가는 자리가 아니다."
class _StatusPalette {
  // Filled party member.
  static const Color partyBg = Color(0xFF101A2E); // dark navy fill
  static const Color partyBorder = Color(0xFF253456); // muted edge

  // Empty party slot — barely-visible scaffold.
  static const Color emptyBorder = Color(0xFF1A2030);

  // Summon slot (index 5) — distinct violet tint, present whether
  // filled or empty so the role of the row is always readable.
  static const Color summonBg = Color(0xFF1E1438); // deep violet
  static const Color summonBgEmpty = Color(0xFF150F26); // dimmer when empty
  static const Color summonBorder = Color(0xFF3A2A5A);

  static const Color headerText = Color(0xFFFFC857); // warm amber
  static const Color rowText = Color(0xFFE8E8E8); // off-white
}

class HDStatusPanel extends StatelessWidget {
  const HDStatusPanel({super.key});

  /// Index of the row reserved for a temporary summon. Anything before
  /// this is a regular party slot; this one is special.
  static const int _summonSlotIndex = 5;
  static const int _totalSlots = 6;

  // Column widths sized to fit the 288 panel:
  // name (108) + 3 stats (52 each) + horizontal padding (12*2) = 288.
  static const double _nameW = 108;
  static const double _statW = 52;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HDConfig.statusPanelWidth,
      height: HDConfig.statusPanelHeight,
      color: Colors.black,
      child: ListenableBuilder(
        listenable: HDGameMain().party,
        builder: (context, child) {
          final players = HDGameMain().party.players;

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    _buildHeaderLabel("name", _nameW),
                    _buildHeaderLabel("hp", _statW),
                    _buildHeaderLabel("sp", _statW),
                    _buildHeaderLabel("esp", _statW),
                  ],
                ),
              ),
              ...List.generate(_totalSlots, (index) {
                final isSummon = index == _summonSlotIndex;
                final hasPlayer =
                    index < players.length && players[index].isValid();
                return _buildSlotRow(
                  player: hasPlayer ? players[index] : null,
                  isSummon: isSummon,
                );
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
      // Match the data cell's internal horizontal padding so headers
      // line up with the values below them.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: _StatusPalette.headerText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSlotRow({HDPlayer? player, required bool isSummon}) {
    final filled = player != null;

    final Color? bg;
    final Color? border;
    if (isSummon) {
      bg = filled
          ? _StatusPalette.summonBg
          : _StatusPalette.summonBgEmpty;
      border = _StatusPalette.summonBorder;
    } else if (filled) {
      bg = _StatusPalette.partyBg;
      border = _StatusPalette.partyBorder;
    } else {
      // Empty party slot — no fill, only the faintest frame so the row
      // stays as a placeholder without drawing attention.
      bg = null;
      border = _StatusPalette.emptyBorder;
    }

    String cellText(String filledValue) => filled ? filledValue : '';

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _buildCell(
            cellText(player?.name ?? ''),
            _nameW,
            bg: bg,
            border: border,
          ),
          _buildCell(
            cellText(player?.hp.toString() ?? ''),
            _statW,
            align: TextAlign.right,
            bg: bg,
            border: border,
          ),
          _buildCell(
            cellText(player?.sp.toString() ?? ''),
            _statW,
            align: TextAlign.right,
            bg: bg,
            border: border,
          ),
          _buildCell(
            cellText(player?.esp.toString() ?? ''),
            _statW,
            align: TextAlign.right,
            bg: bg,
            border: border,
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text,
    double width, {
    TextAlign align = TextAlign.left,
    Color? bg,
    Color? border,
  }) {
    return Container(
      width: width,
      height: 20,
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        border: border == null
            ? null
            : Border.all(color: border, width: 0.5),
      ),
      alignment: align == TextAlign.left
          ? Alignment.centerLeft
          : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: _StatusPalette.rowText,
          fontSize: HDConfig.statusFontSize,
        ),
      ),
    );
  }
}
