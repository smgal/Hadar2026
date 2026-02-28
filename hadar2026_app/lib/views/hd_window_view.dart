import 'package:flutter/material.dart';
import '../models/hd_window.dart';
import '../models/hd_message_window.dart';
import '../models/hd_magic_window.dart';
import '../game_components/hd_window_manager.dart';

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
      return Center(
        child: Text(
          window.text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
    if (window is HDMagicSelectionWindow) {
      return _buildMagicSelection(window);
    }
    return const SizedBox.shrink();
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
          child: ListView.builder(
            itemCount: window.mode == HDSelectionMode.category
                ? 4 // Attack, Heal, Phenomenon, Cancel
                : window.currentOptions.length + 1,
            itemBuilder: (context, index) {
              String label = "";
              bool isSelected = (index == window.selectedIndex);

              if (window.mode == HDSelectionMode.category) {
                if (index == 0) label = "공격 마법";
                if (index == 1) label = "치료 마법";
                if (index == 2) label = "변화 마법";
                if (index == 3) label = "취소";
              } else {
                if (index < window.currentOptions.length) {
                  label = window.currentOptions[index].name;
                } else {
                  label = "취소";
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
      ],
    );
  }
}
