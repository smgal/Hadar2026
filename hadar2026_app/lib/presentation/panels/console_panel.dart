import 'package:flutter/material.dart';
import '../../hd_game_main.dart';
import '../../hd_config.dart';
import '../../utils/hd_text_utils.dart';

const TextStyle _bodyStyle = TextStyle(
  color: Colors.grey,
  fontSize: HDConfig.consoleFontSize,
  height: HDConfig.consoleLineHeight,
);

/// Dialog area (top-right of the 800×480 layout).
///
/// Three logical sections, separated by [HDConfig.dialogSectionGap]:
///  - **Header** (top, 1 line): set via `setHeader(...)`. Hidden when
///    empty so the body floats up.
///  - **Body**: dialogue lines from `addLog(isDialogue: true)`. When a
///    script-driven menu is active, it renders at the bottom of the
///    body — fixed bottom y, growing upward.
///  - **Footer**: "계속하려면 누르십시오 ..." shown while waiting on a key.
///
/// Description text (`addLog(isDialogue: false)` / `Log(...)`) lives in
/// `HDDescriptionPanel` instead — this widget no longer renders the
/// progress base layer.
class HDDialogPanel extends StatelessWidget {
  const HDDialogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HDConfig.consoleWidth,
      height: HDConfig.consoleHeight,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey.shade900, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListenableBuilder(
        listenable: HDGameMain(),
        builder: (context, _) {
          final main = HDGameMain();
          final header = main.dialogHeader;
          final menu = main.activeMenu;
          final showMenu = menu != null && main.isScriptRunning;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                HDTextUtils.parseRichText(header, baseStyle: _bodyStyle),
              ),
              const SizedBox(height: HDConfig.dialogSectionGap),
              Expanded(
                child: _BodyArea(
                  eventLogs: main.eventLogs,
                  menu: showMenu ? menu : null,
                ),
              ),
              const SizedBox(height: HDConfig.dialogSectionGap),
              _Footer(waiting: main.isWaitingForKey),
            ],
          );
        },
      ),
    );
  }
}

/// Body section: dialogue text top-aligned, optional script-driven menu
/// bottom-anchored. Menu grows upward as items are added.
class _BodyArea extends StatelessWidget {
  final List<String> eventLogs;
  final HDMenu? menu;

  const _BodyArea({required this.eventLogs, required this.menu});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in eventLogs)
          Text.rich(HDTextUtils.parseRichText(line, baseStyle: _bodyStyle)),
        const Spacer(),
        if (menu != null) _MenuBlock(menu: menu!),
      ],
    );
  }
}

class _MenuBlock extends StatelessWidget {
  final HDMenu menu;
  const _MenuBlock({required this.menu});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < menu.items.length; i++)
          Text.rich(
            HDTextUtils.parseRichText(
              menu.items[i],
              baseStyle: _bodyStyle.copyWith(color: _colorFor(i)),
            ),
          ),
      ],
    );
  }

  Color _colorFor(int index) {
    if (index == 0) return Colors.red; // title row
    if (index == menu.selectedIndex) return Colors.white; // cursor
    if (index <= menu.enabledCount) return Colors.grey; // enabled
    return Colors.grey.shade900; // disabled
  }
}

class _Footer extends StatelessWidget {
  final bool waiting;
  const _Footer({required this.waiting});

  @override
  Widget build(BuildContext context) {
    if (!waiting) {
      // Reserve the same vertical slot so the body doesn't jump when the
      // footer toggles on. One line at body height.
      return const SizedBox(
        height: HDConfig.consoleFontSize * HDConfig.consoleLineHeight,
      );
    }
    return Text(
      "계속하려면 누르십시오 ...",
      style: TextStyle(
        color: Colors.yellow.shade600,
        fontSize: HDConfig.consoleFontSize,
        height: HDConfig.consoleLineHeight,
      ),
    );
  }
}
