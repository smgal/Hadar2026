import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bonfire/bonfire.dart' hide Timer;
import '../game_components/hd_game_main.dart';

class HDBottomControlPanel extends StatefulWidget {
  const HDBottomControlPanel({super.key});

  @override
  State<HDBottomControlPanel> createState() => _HDBottomControlPanelState();
}

class _HDBottomControlPanelState extends State<HDBottomControlPanel> {
  Timer? _longPressTimer;
  JoystickMoveDirectional _currentDir = JoystickMoveDirectional.IDLE;

  void _startDirection(JoystickMoveDirectional dir) {
    setState(() {
      _currentDir = dir;
    });
    HDGameMain().virtualDirection = dir;
    _sendKeyForDialogueAndMenu(dir);
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      _sendKeyForDialogueAndMenu(dir);
    });
  }

  void _stopDirection() {
    setState(() {
      _currentDir = JoystickMoveDirectional.IDLE;
    });
    HDGameMain().virtualDirection = JoystickMoveDirectional.IDLE;
    _longPressTimer?.cancel();
  }

  void _sendKeyForDialogueAndMenu(JoystickMoveDirectional dir) {
    // We only simulate keys for Menus and Dialogues since Map uses virtualDirection
    if (HDGameMain().currentInputMode != HDInputMode.map) {
      LogicalKeyboardKey key;
      switch(dir) {
        case JoystickMoveDirectional.MOVE_UP: key = LogicalKeyboardKey.arrowUp; break;
        case JoystickMoveDirectional.MOVE_DOWN: key = LogicalKeyboardKey.arrowDown; break;
        case JoystickMoveDirectional.MOVE_LEFT: key = LogicalKeyboardKey.arrowLeft; break;
        case JoystickMoveDirectional.MOVE_RIGHT: key = LogicalKeyboardKey.arrowRight; break;
        default: return;
      }
      HDGameMain().processKey(key);
    }
  }

  void _pressButton(LogicalKeyboardKey key) {
    HDGameMain().processKey(key);
  }

  void _pressAction(bool isDown) {
    HDGameMain().virtualActionPressed = isDown;
    if (isDown) {
      HDGameMain().processKey(LogicalKeyboardKey.enter);
    }
  }

  Widget _buildDirBtn(IconData icon, JoystickMoveDirectional dir) {
    bool isActive = _currentDir == dir;
    return GestureDetector(
      onPanDown: (_) => _startDirection(dir),
      onPanCancel: () => _stopDirection(),
      onPanEnd: (_) => _stopDirection(),
      child: Container(
        width: 78, // 60 * 1.3
        height: 78,
        decoration: BoxDecoration(
          color: isActive ? Colors.white30 : Colors.white12,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.white, size: 47), // 36 * 1.3
      ),
    );
  }

  Widget _buildActionBtn(String label, LogicalKeyboardKey key, {bool isPrimary = false}) {
    return GestureDetector(
      onPanDown: (_) {
         if (isPrimary) _pressAction(true);
         else _pressButton(key);
      },
      onPanCancel: () {
         if (isPrimary) _pressAction(false);
      },
      onPanEnd: (_) {
         if (isPrimary) _pressAction(false);
      },
      child: Container(
        width: isPrimary ? 104 : 83, // 80 -> 104, 64 -> 83
        height: isPrimary ? 104 : 83,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? Colors.blue.withOpacity(0.6) : Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isPrimary ? 26 : 21, // 20 -> 26, 16 -> 21
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      width: double.infinity, // Fill parent width
      color: const Color(0xFF1E1E1E), // Background spans fully across
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16 + media.padding.bottom),
            child: SizedBox(
              height: 234, // Fixed height for inner content (180 * 1.3)
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double innerWidth = constraints.maxWidth;
                  if (innerWidth < 494) innerWidth = 494; // Minimum width before scaling down (380 * 1.3)
                  
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: innerWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      // D-Pad
                      SizedBox(
                        width: 234, // 180 * 1.3
                        height: 192, // 148 * 1.3
                        child: Stack(
                          children: [
                            Positioned(top: 0, left: 78, child: _buildDirBtn(Icons.arrow_drop_up, JoystickMoveDirectional.MOVE_UP)),
                            Positioned(bottom: 0, left: 78, child: _buildDirBtn(Icons.arrow_drop_down, JoystickMoveDirectional.MOVE_DOWN)),
                            Positioned(top: 57, left: 0, child: _buildDirBtn(Icons.arrow_left, JoystickMoveDirectional.MOVE_LEFT)),
                            Positioned(top: 57, right: 0, child: _buildDirBtn(Icons.arrow_right, JoystickMoveDirectional.MOVE_RIGHT)),
                          ],
                        ),
                      ),
                      
                      // Action Buttons
                      SizedBox(
                        width: 221, // 170 * 1.3
                        height: 195, // 150 * 1.3
                        child: Stack(
                          children: [
                             // MENU / CANCEL
                             Positioned(
                               bottom: 78, // 60 * 1.3
                               left: 0,
                               child: _buildActionBtn('ESC', LogicalKeyboardKey.escape),
                             ),
                             // OK / ACTION
                             Positioned(
                               bottom: 13, // 10 * 1.3
                               right: 0,
                               child: _buildActionBtn('OK', LogicalKeyboardKey.enter, isPrimary: true),
                             ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
    ),
    );
  }
}
