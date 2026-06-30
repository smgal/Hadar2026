import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/window/game_window.dart';
import '../../domain/window/message_window_data.dart';
import '../../domain/window/magic_window_data.dart';
import '../../domain/window/selection_window_data.dart';
import '../window_manager.dart';

class HDWindowLayer extends StatelessWidget {
  const HDWindowLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HDWindowManager(),
      builder: (context, child) {
        final windows = HDWindowManager().windows;
        print("HDWindowLayer: Rebuild with ${windows.length} windows");
        return Stack(
          fit: StackFit.expand,
          children: windows.map((w) => HDWindowWidget(window: w)).toList(),
        );
      },
    );
  }
}

class HDWindowWidget extends StatelessWidget {
  final HDWindow window;

  const HDWindowWidget({super.key, required this.window});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: window,
      builder: (context, child) {
        if (!window.isVisible) {
          // print("Window ${window.hashCode} is not visible");
          return const SizedBox.shrink();
        }
        print(
          "HDWindowWidget: Building window ${window.hashCode} at ${window.x},${window.y} ${window.w}x${window.h}",
        );

        // Convert game coordinates to logical pixels?
        // Assuming 1:1 for now or 800x600 fixed container.
        return Positioned(
          left: window.x.toDouble(),
          top: window.y.toDouble(),
          width: window.w.toDouble(),
          height: window.h.toDouble(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(8),
            child: _buildContent(window),
          ),
        );
      },
    );
  }

  Widget _buildContent(HDWindow window) {
    if (window is HDMessageWindow) {
      // Fixed-size box: top-aligned so multi-line signs read naturally
      // and overlong text clips at the bottom rather than re-centering.
      // Footer reuses the console-side wording ("계속하려면 누르십시오 ...")
      // so the dismiss affordance reads the same across both paths.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                window.text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const _BlinkingDismissHint(),
        ],
      );
    }
    if (window is HDMagicSelectionWindow) {
      return _buildMagicSelection(window);
    }
    if (window is HDSelectionWindow) {
      return _buildSelection(window);
    }
    return const SizedBox.shrink();
  }

  /// Overlays ▲/▼ chevrons on the right edge of a scrolling list to signal
  /// that more items exist above or below the current viewport. Used by every
  /// selection-style popup so the affordance stays consistent.
  Widget _wrapWithScrollIndicators({
    required Widget child,
    required bool hasMoreAbove,
    required bool hasMoreBelow,
  }) {
    return Stack(
      children: [
        child,
        if (hasMoreAbove)
          const Positioned(
            top: 0,
            right: 4,
            child: Icon(
              Icons.keyboard_arrow_up,
              color: Colors.yellow,
              size: 18,
            ),
          ),
        if (hasMoreBelow)
          const Positioned(
            bottom: 0,
            right: 4,
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.yellow,
              size: 18,
            ),
          ),
      ],
    );
  }

  Widget _buildMagicSelection(HDMagicSelectionWindow window) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            border: Border.all(color: Colors.blue.shade400),
          ),
          width: double.infinity,
          child: Text(
            window.title,
            style: const TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _wrapWithScrollIndicators(
            hasMoreAbove: window.hasMoreAbove,
            hasMoreBelow: window.hasMoreBelow,
            child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: window.mode == HDSelectionMode.category
                ? 3 // Attack, Heal, Phenomenon (cancel via ESC)
                : math.min(window.currentOptions.length, window.maxVisibleItems),
            itemBuilder: (context, index) {
              String label = "";
              int actualIndex = index;
              if (window.mode == HDSelectionMode.magic) {
                actualIndex = window.displayStartIndex + index;
              }
              bool isSelected = (actualIndex == window.selectedIndex);

              if (window.mode == HDSelectionMode.category) {
                if (index == 0) label = "공격 마법";
                if (index == 1) label = "치료 마법";
                if (index == 2) label = "변화 마법";
              } else {
                if (actualIndex < window.currentOptions.length) {
                  label = window.currentOptions[actualIndex].name.text;
                }
              }

              return Container(
                color: isSelected ? Colors.white.withOpacity(0.2) : null,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.play_arrow : null,
                      color: Colors.yellow,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.yellow : Colors.white,
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelection(HDSelectionWindow window) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (window.choices.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade900,
              border: Border.all(color: Colors.blue.shade400),
            ),
            width: double.infinity,
            child: Text(
              window.choices[0],
              style: const TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _wrapWithScrollIndicators(
            hasMoreAbove: window.hasMoreAbove,
            hasMoreBelow: window.hasMoreBelow,
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(
                window.choices.length - 1,
                window.maxVisibleItems,
              ),
              itemBuilder: (context, index) {
                int actualIndex = window.displayStartIndex + index;
                if (actualIndex >= window.choices.length) {
                  return const SizedBox.shrink();
                }
                String label = window.choices[actualIndex];
                bool isSelected = (actualIndex == window.selectedIndex);

                return Container(
                  color: isSelected ? Colors.white.withOpacity(0.2) : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.play_arrow : null,
                        color: Colors.yellow,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.yellow : Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Footer hint shown at the bottom of [HDMessageWindow]: a yellow
/// "계속하려면 누르십시오 ..." that fades in and out to signal that the
/// popup waits for a keypress. Matches the wording used by the console
/// dialogue's key-wait state.
class _BlinkingDismissHint extends StatefulWidget {
  const _BlinkingDismissHint();

  @override
  State<_BlinkingDismissHint> createState() => _BlinkingDismissHintState();
}

class _BlinkingDismissHintState extends State<_BlinkingDismissHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
        child: Text(
          "계속하려면 누르십시오 ...",
          style: TextStyle(
            color: Colors.yellow.shade600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
