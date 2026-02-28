import 'package:flutter/material.dart';
import '../models/hd_window.dart';
import '../models/hd_message_window.dart';
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
    return const SizedBox.shrink();
  }
}
