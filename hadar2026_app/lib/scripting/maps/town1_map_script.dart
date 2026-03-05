import 'dart:async';
import '../hd_map_script.dart';

class Town1MapScript extends HDMapScript {
  @override
  String get mapName => 'TOWN1';

  @override
  void onPrepare() {
    // GameRes.ChangeTileSet(TILE_SET.TOWN);
    // CONFIG.BGM = "LoreTown1";
  }

  @override
  void onLoad(String prevMap, int fromX, int fromY) {
    if (prevMap == 'GROUND1') {
      game.party.x = 50;
      game.party.y = 91;
      game.party.faced =
          1; // Down (0, -1 in Unity means UP, but we mapped it properly in hd_party likely)
    } else {
      game.party.x = 50;
      game.party.y = 31;
      game.party.faced = 1;
    }

    // Example logic port
    // if (isFlagSet(33)) {
    //   game.map?.setTile(44, 14, 0);
    // }
  }

  @override
  void onUnload() {}

  @override
  Future<bool> onEvent(int eventId) async {
    // Porting just a bit of logic for demonstration

    // Example: Trigger at (49~51, 29)
    if (!isFlagSet(41) && isArea(49, 29, 51, 29)) {
      await talk("로드안 - 로어성의 성주\n당신과 이야기 하고 싶어한다.");
      setFlag(41);
    }

    return true; // You can move there by default
  }

  @override
  Future<void> onPostEvent(int eventId) async {}

  @override
  Future<bool> onEnter(int eventId) async {
    if (isArea(48, 92, 52, 92)) {
      // Leave castle
      // Select_Init() -> LoadMapEx("GROUND1")
      await talk("밖은 황야가 펼쳐져 있다. 구현 예정...");
    }
    return false;
  }

  @override
  Future<void> onSign(int eventId) async {
    if (isOn(50, 83)) {
      await talk("여기는 'CASTLE LORE'성\n여러분을 환영합니다\n\n\nLord Ahn");
    }

    if (isOn(23, 30)) {
      await talk("\n여기는 LORE 주점\n여러분 모두를 환영합니다 !!");
    }
  }

  @override
  Future<void> onTalk(int eventId) async {
    if (isOn(45, 8)) {
      if (!isFlagSet(33)) {
        await talk("게임의 진행을 위해 이 안 쪽 감옥의 문을 열어 주겠소.");
        setFlag(33);
        game.map?.setTile(44, 14, 0);
      } else {
        if (!isFlagSet(34)) {
          await talk("내가 열어준 감옥에는 Joe라고 하는 사람이 수감되어 있소.");
        } else {
          await talk("Joe와 동료가 되었군요.\n\n재미있군요. 왜 그러셨나요?");
        }
      }
    }

    if (isOn(50, 27)) {
      await talk("나는 로드안 이오.\n\n이제부터 당신은 이 게임에서 새로운 인물로서 생을 시작하게 될 것이오.");
      await talk("이전 인터페이스를 그대로 재현한 것이 현 상태라오. 조금은 불편하겠지만 당장은 좀 참아 주시구려.");
    }
  }
}
