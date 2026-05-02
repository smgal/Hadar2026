import 'dart:async';
import '../../hd_game_main.dart';

abstract class HDMapScript {
  final HDGameMain game = HDGameMain();

  String get mapName;

  void onPrepare();
  void onLoad(String prevMap, int fromX, int fromY);
  void onUnload();

  /// Return `true` if this script handled the event at (tx, ty). When
  /// `false`, the dispatcher falls through to the next event source
  /// (cm2 → static JSON). This is the same contract for [onTalk],
  /// [onSign], [onEvent], and [onEnter].
  Future<bool> onEvent(int eventId);

  Future<void> onPostEvent(int eventId);
  Future<bool> onEnter(int eventId);
  Future<bool> onSign(int eventId);
  Future<bool> onTalk(int eventId);

  // Coordinate of the target tile (the tile being interacted with or stepped on)
  int tx = 0;
  int ty = 0;

  // Helper Methods for Scripts
  Future<void> talk(String text) async {
    await game.addLog(text, isDialogue: true);
  }

  bool isFlagSet(int index) {
    // Requires implementation in GameModel / State
    return false;
  }

  void setFlag(int index) {
    // Requires implementation in GameModel / State
  }

  bool isOn(int x, int y) {
    return tx == x && ty == y;
  }

  bool isArea(int x1, int y1, int x2, int y2) {
    return tx >= x1 && tx <= x2 && ty >= y1 && ty <= y2;
  }
}
