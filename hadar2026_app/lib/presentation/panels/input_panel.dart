import 'package:flutter/material.dart';
import '../../hd_config.dart';
import '../../hd_game_main.dart';
import '../../utils/hd_text_utils.dart';

const TextStyle _menuStyle = TextStyle(
  color: Colors.white,
  fontSize: HDConfig.consoleFontSize,
  height: HDConfig.consoleLineHeight,
);

/// Bottom-right slot. Hosts narrative-driven selection menus only — the
/// `Select::*` choices and any menu opened by a tile script during a
/// dialogue cycle. Main menu / battle / save-load menus continue to
/// render in the console area; this panel is empty whenever a menu
/// isn't being driven by a running script (`isScriptRunning == false`).
class HDInputPanel extends StatelessWidget {
  const HDInputPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HDConfig.inputPanelWidth,
      height: HDConfig.inputPanelHeight,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey.shade900, width: 1),
      ),
      child: ListenableBuilder(
        listenable: HDGameMain(),
        builder: (context, _) {
          final main = HDGameMain();
          final menu = main.activeMenu;
          if (menu == null || !main.isScriptRunning) {
            return const SizedBox.shrink();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: menu.items.length,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              Color overrideColor;
              if (index == 0) {
                overrideColor = Colors.red; // title row
              } else if (index == menu.selectedIndex) {
                overrideColor = Colors.white; // cursor
              } else if (index <= menu.enabledCount) {
                overrideColor = Colors.grey; // enabled but unselected
              } else {
                overrideColor = Colors.grey.shade900; // disabled
              }
              // Menu items use a single override color; ignore any
              // embedded `@X` tags so the cursor highlight is uniform.
              return Text.rich(
                HDTextUtils.parseRichText(
                  menu.items[index],
                  baseStyle: _menuStyle.copyWith(color: overrideColor),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
