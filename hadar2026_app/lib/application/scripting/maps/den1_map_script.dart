import 'dart:async';
import '../native_script_runner.dart';
import '../map_script.dart';

class Den1MapScript extends HDMapScript {
  @override
  String get mapName => 'DEN1';

  @override
  void onPrepare() {}

  @override
  void onLoad(String prevMap, int fromX, int fromY) {
    if (prevMap == 'ORIGIN' || prevMap == 'TOWN1') {
      talk("여기는 광산 메너스이다.");
      game.party.x = 25;
      game.party.y = 44;
      game.party.setFace(0, -1);
    } else if (prevMap == 'DEN2') {
      game.party.x = 42;
      game.party.y = 40;
      game.party.setFace(-1, 0);
    } else {
      game.party.x = 25;
      game.party.y = 44;
      game.party.setFace(0, -1);
    }
  }

  @override
  void onUnload() {}

  @override
  Future<bool> onEvent(int eventId) async {
    return true;
  }

  @override
  Future<void> onPostEvent(int eventId) async {}

  @override
  Future<bool> onEnter(int eventId) async {
    if (isOn(43, 40)) {
      await HDNativeScriptRunner().loadMapScript('DEN2');
      return true;
    }

    if (isArea(24, 44, 25, 45)) {
      final choice = await game.showMenu([
        "여기는 로어대륙으로 나가는 출구이다.",
        "일단 나가본다",
        "조금 더 있는다",
      ]);

      if (choice == 1) {
        await HDNativeScriptRunner().loadMapScript('GROUND1');
      } else if (choice == 2) {
        await talk("일행은 다시 황야로 나섰다");
      } else {
        await talk("당신은 그냥 그 자리에 서 있다");
      }
    }

    return false;
  }

  @override
  Future<void> onSign(int eventId) async {}

  @override
  Future<void> onTalk(int eventId) async {}
}
