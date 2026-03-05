import 'dart:async';
import '../hd_native_script_runner.dart';
import '../hd_map_script.dart';

class Ground1MapScript extends HDMapScript {
  @override
  String get mapName => 'GROUND1';

  @override
  void onPrepare() {
    // GameRes.ChangeTileSet(TILE_SET.GROUND);
    // CONFIG.BGM = "LoreGround1";
  }

  @override
  void onLoad(String prevMap, int fromX, int fromY) {
    if (prevMap == 'ORIGIN' || prevMap == 'TOWN1') {
      game.party.x = 19;
      game.party.y = 11;
      game.party.faced = 0; // Down
      game.party.setFace(0, 1);

      talk(
        "대지는 황량하고 적막마저 감돈다.\n\n하지만 여행자들이 다니던 길이 나 있어, 최소한 황야에서 길을 잃지는 않을 것 같다.",
      );
    } else if (prevMap == 'TOWN2') {
      game.party.x = 75;
      game.party.y = 57;
      game.party.faced = 0;
      game.party.setFace(0, 1);
    } else if (prevMap == 'DEN1') {
      game.party.x = 17;
      game.party.y = 88;
      game.party.faced = 2; // Right
      game.party.setFace(1, 0);
    } else {
      game.party.x = 19;
      game.party.y = 11;
      game.party.faced = 0; // Down
      game.party.setFace(0, 1);
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
    if (isOn(19, 10)) {
      final choice = await game.showMenu([
        "당신은 로어성의 입구에 서 있다.",
        "로어성으로 들어 간다",
        "들어가지 않겠다",
      ]);

      if (choice == 1) {
        await HDNativeScriptRunner().loadMapScript('TOWN1');
      } else if (choice == 2) {
        await talk("로어성의 외관은 이전과 그다지 바뀌지는 않아 보였다.");
      } else {
        await talk("당신은 별다른 선택을 하지는 않은 채로 그 자리에 서 있었다.");
      }
    }

    if (isOn(75, 56)) {
      final choice = await game.showMenu([
        "여기는 라스트디치성이다.",
        "들어 가 본다",
        "들어가지 않겠다",
      ]);

      if (choice == 1) {
        await HDNativeScriptRunner().loadMapScript('TOWN2');
      } else if (choice == 2) {
        await talk("다시 로어성으로 돌아갈까?");
      } else {
        await talk(".....");
      }
    }

    if (isOn(16, 88)) {
      final choice = await game.showMenu([
        "여기가 메너스 광산이다",
        "들어 가 본다",
        "들어가지 않겠다",
      ]);

      if (choice == 1) {
        await HDNativeScriptRunner().loadMapScript('DEN1');
      } else if (choice == 2) {
        await talk("다시 로어성으로 돌아갈까?");
      } else {
        await talk(".....");
      }
    }

    return false;
  }

  @override
  Future<void> onSign(int eventId) async {}

  @override
  Future<void> onTalk(int eventId) async {}
}
