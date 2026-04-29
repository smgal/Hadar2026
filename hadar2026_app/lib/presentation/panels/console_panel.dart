import 'package:flutter/material.dart';
import '../../hd_game_main.dart';
import '../../hd_config.dart';
import '../../utils/hd_text_utils.dart';

const TextStyle _consoleStyle = TextStyle(
  color: Colors.white,
  fontSize: HDConfig.consoleFontSize,
  height: HDConfig.consoleLineHeight,
);

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
                final main = HDGameMain();
                final bool isEventMode = main.isEventMode;
                final activeMenu = main.activeMenu;

                // Both log lines and menu items are now plain strings with
                // `@X..@@` color tags — re-parse to TextSpan here.
                final List<String> rawItems;
                int menuStartIndex = -1;

                if (isEventMode) {
                  final eventLogs = main.eventLogs;
                  if (activeMenu != null) {
                    rawItems = [...eventLogs, ...activeMenu.items];
                    menuStartIndex = eventLogs.length;
                  } else {
                    rawItems = [...eventLogs];
                  }
                } else {
                  rawItems = [...main.progressLogs];
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: rawItems.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final raw = rawItems[index];

                    if (activeMenu != null &&
                        menuStartIndex >= 0 &&
                        index >= menuStartIndex) {
                      final menuIndex = index - menuStartIndex;
                      Color overrideColor;
                      if (menuIndex == 0) {
                        overrideColor = Colors.red;
                      } else if (menuIndex == activeMenu.selectedIndex) {
                        overrideColor = Colors.white;
                      } else if (menuIndex <= activeMenu.enabledCount) {
                        overrideColor = Colors.grey;
                      } else {
                        overrideColor = Colors.grey.shade900;
                      }
                      // Menu items use a single override color; ignore any
                      // embedded `@X` tags so the cursor highlight is uniform.
                      return Text.rich(
                        HDTextUtils.parseRichText(
                          raw,
                          baseStyle: _consoleStyle.copyWith(
                            color: overrideColor,
                          ),
                        ),
                      );
                    }

                    return Text.rich(
                      HDTextUtils.parseRichText(raw, baseStyle: _consoleStyle),
                    );
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
                    "계속하려면 누르십시오 ...",
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
