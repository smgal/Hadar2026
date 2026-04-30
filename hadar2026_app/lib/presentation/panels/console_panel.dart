import 'package:flutter/material.dart';
import '../../hd_game_main.dart';
import '../../hd_config.dart';
import '../../utils/hd_text_utils.dart';

const TextStyle _consoleStyle = TextStyle(
  color: Colors.white,
  fontSize: HDConfig.consoleFontSize,
  height: HDConfig.consoleLineHeight,
);

/// Console area (top-right of the 800×480 layout).
///
/// Stack-overlay model:
///  - **Base layer**: progress log. Always mounted, scrollable, auto-follows
///    the bottom when new lines arrive while the user is at the bottom.
///  - **Overlay layer**: shown while a narrative cycle is active (dialogue,
///    menu, or system-result message). Fully covers the base; the base is
///    inert (`IgnorePointer`) underneath.
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
      child: ListenableBuilder(
        listenable: HDGameMain(),
        builder: (context, _) {
          final main = HDGameMain();
          final overlayActive = main.viewMode == HDConsoleViewMode.overlay;
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: overlayActive,
                child: const _ProgressBaseLayer(),
              ),
              if (overlayActive) const _NarrativeOverlay(),
            ],
          );
        },
      ),
    );
  }
}

/// Base layer: always-mounted, scrollable progress log.
class _ProgressBaseLayer extends StatefulWidget {
  const _ProgressBaseLayer();

  @override
  State<_ProgressBaseLayer> createState() => _ProgressBaseLayerState();
}

class _ProgressBaseLayerState extends State<_ProgressBaseLayer> {
  final ScrollController _controller = ScrollController();
  int _lastLineCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Follow-bottom heuristic: jump to the new bottom only when the user is
  /// already at (or near) the bottom. If they've scrolled up to read past
  /// messages, leave the offset alone.
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
    return ListenableBuilder(
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
              HDTextUtils.parseRichText(lines[index], baseStyle: _consoleStyle),
            );
          },
        );
      },
    );
  }
}

/// Overlay layer: events + active menu + PressAnyKey prompt. Opaque
/// background so the base progress is fully hidden underneath.
class _NarrativeOverlay extends StatelessWidget {
  const _NarrativeOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: HDGameMain(),
              builder: (context, _) {
                final main = HDGameMain();
                final activeMenu = main.activeMenu;
                final eventLogs = main.eventLogs;

                // Narrative-driven menus (Select::Run, dialogue
                // choices) render in the bottom-right input panel
                // instead — they're only displayed here when no
                // script is running (main menu, battle menu, etc.).
                final showMenuHere =
                    activeMenu != null && !main.isScriptRunning;
                final List<String> rawItems = showMenuHere
                    ? [...eventLogs, ...activeMenu.items]
                    : [...eventLogs];
                final menuStartIndex =
                    showMenuHere ? eventLogs.length : -1;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: rawItems.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final raw = rawItems[index];

                    if (showMenuHere &&
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
          ListenableBuilder(
            listenable: HDGameMain(),
            builder: (context, _) {
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
