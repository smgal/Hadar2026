import 'dart:async';
import '../native_script_runner.dart';
import '../map_script.dart';

class Town2MapScript extends HDMapScript {
  @override
  String get mapName => 'TOWN2';

  @override
  void onPrepare() {}

  @override
  void onLoad(String prevMap, int fromX, int fromY) {
    if (prevMap == 'ORIGIN' || prevMap == 'TOWN1') {
      talk("여기는 어디인가? 나는 누구인가?");
      game.party.x = 37;
      game.party.y = 6;
      game.party.setFace(0, 1);
    } else {
      game.party.x = 37;
      game.party.y = 68;
      game.party.setFace(0, -1);
    }
  }

  @override
  void onUnload() {}

  @override
  Future<bool> onEvent(int eventId) async {
    if (isArea(29, 7, 29, 10)) {
      // C# code checks if faced right (dx == 1)
      // Let's assume right is dx == 1. In Dart party it is (1, 0)
      if (game.party.faced == 2) {
        // 2 = Right
        game.party.x += 3;
      }
      return true;
    }

    if (isArea(31, 7, 31, 10)) {
      if (game.party.faced == 3) {
        // 3 = Left
        game.party.x -= 3;
      }
      return true;
    }

    return false;
  }

  @override
  Future<void> onPostEvent(int eventId) async {}

  @override
  Future<bool> onEnter(int eventId) async {
    if (isArea(36, 5, 39, 5)) {
      final choice = await game.showMenu([
        "다시 로어성으로 들어가겠습니까?",
        "안으로 들어간다.",
        "들어가지는 않는다",
      ]);

      if (choice == 1) {
        await HDNativeScriptRunner().loadMapScript('TOWN1');
      }
      return true;
    }

    if (isArea(36, 69, 39, 69)) {
      await HDNativeScriptRunner().loadMapScript('GROUND1');
      return true;
    }

    return false;
  }

  @override
  Future<bool> onSign(int eventId) async => false;

  @override
  Future<bool> onTalk(int eventId) async => false;
}
