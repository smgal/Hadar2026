import 'package:flutter/material.dart';
import '../../hd_config.dart';
import '../../hd_game_main.dart';
import '../../utils/hd_text_utils.dart';

const TextStyle _descStyle = TextStyle(
  color: Colors.grey,
  fontSize: HDConfig.consoleFontSize,
  height: HDConfig.consoleLineHeight,
);

const Color _descriptionBackgroundColor = Color(0xFF515151);

/// Bottom-right description panel.
///
/// Hosts "흘러가는 상황 설명" lines — the slow drip of ambient log text
/// from `addLog(isDialogue: false)` / cm2 `Log(...)` / terrain triggers
/// like swamp/lava entry. Always visible, scrollable, auto-follows the
/// bottom while the user is at the bottom; if they scrolled up to read
/// past lines, new arrivals don't yank them down.
///
/// Replaces the previous narrative-menu panel — script-driven menus now
/// render at the bottom of the dialog body in [HDDialogPanel].
class HDDescriptionPanel extends StatefulWidget {
  const HDDescriptionPanel({super.key});

  @override
  State<HDDescriptionPanel> createState() => _HDDescriptionPanelState();
}

class _HDDescriptionPanelState extends State<HDDescriptionPanel> {
  final ScrollController _controller = ScrollController();
  int _lastLineCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeFollowBottom() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final atBottom = (pos.maxScrollExtent - pos.pixels) < 4.0;
    if (atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.jumpTo(_controller.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HDConfig.inputPanelWidth,
      height: HDConfig.inputPanelHeight,
      decoration: BoxDecoration(
        color: _descriptionBackgroundColor,
        border: Border.all(color: Colors.grey.shade900, width: 1),
      ),
      child: ListenableBuilder(
        listenable: HDGameMain(),
        builder: (context, _) {
          final lines = HDGameMain().progressLogs;
          if (lines.length != _lastLineCount) {
            _lastLineCount = lines.length;
            _maybeFollowBottom();
          }
          return ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const ClampingScrollPhysics(),
            itemCount: lines.length,
            itemBuilder: (context, index) {
              return Text.rich(
                HDTextUtils.parseRichText(lines[index], baseStyle: _descStyle),
              );
            },
          );
        },
      ),
    );
  }
}
