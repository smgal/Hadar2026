import 'package:flutter/material.dart';
import '../game_components/hd_game_main.dart';
import '../hd_config.dart';
import '../utils/hd_text_utils.dart';

class HDConsolePanel extends StatelessWidget {
  const HDConsolePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HDConfig.consoleWidth,
      height: HDConfig.consoleHeight,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey.shade900, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: HDGameMain(),
              builder: (context, child) {
                final activeMenu = HDGameMain().activeMenu;
                final logs = HDGameMain().logs;

                final List<InlineSpan> combinedItems;
                int menuStartIndex = -1;

                if (activeMenu != null) {
                  // Parse menu items since they can also have @ tags
                  final parsedMenuItems = activeMenu.items
                      .map(
                        (item) => HDTextUtils.parseRichText(
                          item,
                          baseStyle: HDGameMain.consoleStyle,
                        ),
                      )
                      .toList();

                  if (activeMenu.clearLogs) {
                    combinedItems = parsedMenuItems;
                    menuStartIndex = 0;
                  } else {
                    combinedItems = [...logs, ...parsedMenuItems];
                    menuStartIndex = logs.length;
                  }
                } else {
                  combinedItems = logs;
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: combinedItems.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final span = combinedItems[index];

                    if (activeMenu != null &&
                        menuStartIndex >= 0 &&
                        index >= menuStartIndex) {
                      final menuIndex = index - menuStartIndex;
                      Color? overrideColor;

                      if (menuIndex == 0) {
                        overrideColor = Colors.red;
                      } else if (menuIndex == activeMenu.selectedIndex) {
                        overrideColor = Colors.white;
                      } else if (menuIndex <= activeMenu.enabledCount) {
                        overrideColor = Colors.grey;
                      } else {
                        overrideColor = Colors.grey.shade900;
                      }

                      return Text.rich(
                        TextSpan(
                          children: [span],
                          style: HDGameMain.consoleStyle.copyWith(
                            color: overrideColor,
                          ),
                        ),
                      );
                    }

                    return Text.rich(span, style: HDGameMain.consoleStyle);
                  },
                );
              },
            ),
          ),
          // Prompt area
          ListenableBuilder(
            listenable: HDGameMain(),
            builder: (context, child) {
              if (HDGameMain().isWaitingForKey) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "아무키나 누르십시오 ...",
                    style: TextStyle(
                      color: Colors.yellow.shade600,
                      fontSize: HDConfig.consoleFontSize,
                    ),
                  ),
                );
              }
              return const SizedBox(height: 48);
            },
          ),
        ],
      ),
    );
  }
}
