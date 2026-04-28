import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../application/magic_system.dart';
import '../domain/party/player.dart';
import '../game_components/hd_battle.dart';
import '../game_components/hd_game_main.dart';
import '../application/save_manager.dart';

/// Top-level menus driven by the main game shell: command menu, party
/// inspection, rest, save/load, difficulty, game-over. Each call drives the
/// host (`UiHost`) for prompts and reads/writes domain state through
/// [HDGameMain] (party, sessionId, etc.).
///
/// Notes:
/// - Lives in `application/` because it composes UI flow with domain
///   actions but holds no rendering of its own.
/// - The current `HDGameMain` dependency is a transitional shortcut. As the
///   god object shrinks, this class should be reachable purely via
///   `UiHost` + `HDParty` + a handful of domain services.
class HDMenuFlows {
  static final HDMenuFlows _instance = HDMenuFlows._internal();
  factory HDMenuFlows() => _instance;
  HDMenuFlows._internal();

  HDGameMain get _game => HDGameMain();

  Future<void> showMainMenu() async {
    final choices = [
      "당신의 명령을 고르시오 ===>",
      "일행의 상황을 본다",
      "개인의 상황을 본다",
      "일행의 건강 상태를 본다",
      "마법을 사용한다",
      "초능력을 사용한다",
      "여기서 쉰다",
      "게임 선택 상황",
      "전투 테스트 (시뮬레이션)",
    ];

    int selected = await _game.showMenu(choices);

    switch (selected) {
      case 0:
        break; // Cancel
      case 1:
        await showPartyStatus();
        break;
      case 2:
        await showCharacterStatus();
        break;
      case 3:
        await showHealthStatus();
        break;
      case 4:
        await _selectPlayerForMagic();
        break;
      case 5:
        await _selectPlayerForESP();
        break;
      case 6:
        await restHere();
        break;
      case 7:
        await selectGameOption();
        break;
      case 8:
        await showBattleMenu();
        break;
    }
  }

  Future<void> showBattleMenu() async {
    HDBattle().init();
    HDBattle().registerEnemy(5); // Skeleton
    HDBattle().registerEnemy(7); // Slime

    HDBattle().showEnemy();

    final preMenu = ["", "적과 교전한다", "도망간다"];
    int preSel = await _game.showMenu(preMenu, clearLogs: false);
    if (preSel == 2) {
      final party = _game.party;
      int avgLuck =
          party.players
              .where((p) => p.isValid())
              .fold(0, (sum, p) => sum + p.luck) ~/
          party.players.where((p) => p.isValid()).length;
      int avgAgility =
          HDBattle().enemies.fold(0, (sum, e) => sum + e.agility) ~/
          HDBattle().enemies.length;

      if (avgLuck + Random().nextInt(10) > avgAgility) {
        await _game.addLog("무사히 도망쳤다...", isDialogue: false);
        await _game.waitForAnyKey();
        _game.clearLogs();
        return;
      } else {
        await _game.addLog("도망에 실패했다 !", isDialogue: false);
        await _game.waitForAnyKey();
      }
    }

    await HDBattle().start(1);

    _game.clearLogs();
  }

  Future<void> _selectPlayerForMagic() async {
    final party = _game.party;
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = ["누가 마법을 사용하겠습니까 ?", ...validPlayers.map((p) => p.name)];
    int selected = await _game.showMenu(choices);
    if (selected == 0) return;

    final player = validPlayers[selected - 1];
    await HDMagicSystem.castSpell(player);
  }

  Future<void> _selectPlayerForESP() async {
    final party = _game.party;
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = ["누가 초능력을 사용하겠습니까 ?", ...validPlayers.map((p) => p.name)];
    int selected = await _game.showMenu(choices);
    if (selected == 0) return;

    final player = validPlayers[selected - 1];
    await HDMagicSystem.useESP(player);
  }

  Future<void> restHere() async {
    final party = _game.party;
    _game.clearLogs();

    for (var p in party.players) {
      if (!p.isValid()) continue;

      if (party.food <= 0) {
        await _game.addLog("일행은 식량이 바닥났다", isDialogue: false);
      } else if (p.dead > 0) {
        await _game.addLog("${p.name}${p.josaSub1} 죽었다", isDialogue: false);
      } else if (p.unconscious > 0 && p.poison == 0) {
        p.unconscious -= (p.level[0] + p.level[1] + p.level[2]);
        if (p.unconscious <= 0) {
          await _game.addLog(
            "${p.name}${p.josaSub1} 의식이 회복되었다",
            isDialogue: false,
          );
          p.unconscious = 0;
          if (p.hp <= 0) p.hp = 1;
          party.food--;
        } else {
          await _game.addLog(
            "${p.name}${p.josaSub1} 여전히 의식 불명이다",
            isDialogue: false,
          );
        }
      } else if (p.unconscious > 0 && p.poison > 0) {
        await _game.addLog(
          "독 때문에 ${p.name}의 의식은 회복되지 않았다",
          isDialogue: false,
        );
      } else if (p.poison > 0) {
        await _game.addLog(
          "독 때문에 ${p.name}의 건강은 회복되지 않았다",
          isDialogue: false,
        );
      } else {
        int recovery = (p.level[0] + p.level[1] + p.level[2]) * 2;
        int maxHp = p.endurance * p.level[0];

        bool fullHp = p.hp >= maxHp;

        p.hp += recovery;
        if (p.hp >= maxHp) {
          p.hp = maxHp;
          await _game.addLog(
            "${p.name}${p.josaSub1} 모든 건강이 회복되었다",
            isDialogue: false,
          );
        } else {
          await _game.addLog(
            "${p.name}${p.josaSub1} 치료되었다",
            isDialogue: false,
          );
        }

        if (!fullHp) {
          party.food--;
        }
      }

      p.sp = p.mentality * p.level[1];
      p.esp = p.concentration * p.level[2];

      if (p.sp > p.maxSp) p.sp = p.maxSp;
      if (p.esp > p.maxEsp) p.esp = p.maxEsp;
      if (p.hp > p.maxHp) p.hp = p.maxHp;
    }

    if (party.magicTorch > 0) party.magicTorch--;
    party.levitation = 0;
    party.walkOnWater = 0;
    party.walkOnSwamp = 0;
    party.mindControl = 0;

    party.notifyListeners();

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> showPartyStatus() async {
    final party = _game.party;
    _game.clearLogs();

    await _game.addLog("X 축 = ${party.x}", isDialogue: false);
    await _game.addLog("Y 축 = ${party.y}", isDialogue: false);
    await _game.addLog("남은 식량 = ${party.food}", isDialogue: false);
    await _game.addLog("남은 황금 = ${party.gold}", isDialogue: false);
    await _game.addLog("", isDialogue: false);

    await _game.addLog("마법의 횃불 : ${party.magicTorch}", isDialogue: false);
    await _game.addLog("공중 부상   : ${party.levitation}", isDialogue: false);
    await _game.addLog("물위를 걸음 : ${party.walkOnWater}", isDialogue: false);
    await _game.addLog("늪위를 걸음 : ${party.walkOnSwamp}", isDialogue: false);

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> showHealthStatus() async {
    _game.clearLogs();

    await _game.addLog("                이름    중독  의식불명    죽음", isDialogue: false);
    await _game.addLog("", isDialogue: false);

    for (var p in _game.party.players) {
      if (p.isValid()) {
        final nameStr = p.name.padLeft(20);
        final unStr = p.unconscious.toString().padLeft(9);
        final deadStr = p.dead.toString().padLeft(7);
        final poiStr = p.poison.toString().padLeft(5);

        await _game.addLog(
          "$nameStr   $poiStr $unStr $deadStr",
          isDialogue: false,
        );
      }
    }

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> showCharacterStatus() async {
    final party = _game.party;
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = [
      "능력을 보고싶은 인물을 선택하시오",
      ...validPlayers.map((p) => p.name),
    ];

    int selected = await _game.showMenu(choices);
    if (selected == 0) return; // ESC

    final player = validPlayers[selected - 1];

    _game.clearLogs();
    await _game.addLog("# 이름 : ${player.name}", isDialogue: false);
    await _game.addLog("# 성별 : ${player.getGenderName()}", isDialogue: false);
    await _game.addLog("# 계급 : ${player.getClassName()}", isDialogue: false);
    await _game.addLog("", isDialogue: false);
    await _game.addLog("체력   : ${player.strength}", isDialogue: false);
    await _game.addLog("정신력 : ${player.mentality}", isDialogue: false);
    await _game.addLog("집중력 : ${player.concentration}", isDialogue: false);
    await _game.addLog("인내력 : ${player.endurance}", isDialogue: false);
    await _game.addLog("저항력 : ${player.resistance}", isDialogue: false);
    await _game.addLog("민첩성 : ${player.agility}", isDialogue: false);
    await _game.addLog("행운   : ${player.luck}", isDialogue: false);

    await _game.waitForAnyKey();

    _game.clearLogs();
    await _game.addLog("# 이름 : ${player.name}", isDialogue: false);
    await _game.addLog("# 성별 : ${player.getGenderName()}", isDialogue: false);
    await _game.addLog("# 계급 : ${player.getClassName()}", isDialogue: false);
    await _game.addLog("", isDialogue: false);

    await _game.addLog(
      "무기의 정확성   : ${player.accuracy[0].toString().padLeft(2)}    전투 레벨   : ${player.level[0].toString().padLeft(2)}",
      isDialogue: false,
    );
    await _game.addLog(
      "정신력의 정확성 : ${player.accuracy[1].toString().padLeft(2)}    마법 레벨   : ${player.level[1].toString().padLeft(2)}",
      isDialogue: false,
    );
    await _game.addLog(
      "초감각의 정확성 : ${player.accuracy[2].toString().padLeft(2)}    초감각 레벨 : ${player.level[2].toString().padLeft(2)}",
      isDialogue: false,
    );
    await _game.addLog("## 경험치   : ${player.experience}", isDialogue: false);
    await _game.addLog("", isDialogue: false);
    await _game.addLog("사용 무기 - ${player.getWeaponName()}", isDialogue: false);
    await _game.addLog(
      "방패 - ${player.getShieldName().padRight(12)} 갑옷 - ${player.getArmorName()}",
      isDialogue: false,
    );

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> selectGameOption() async {
    final choices = [
      "게임 선택 상황", // 0: Title
      "난이도 조절", // 1
      "정식 일행의 순서 정렬", // 2
      "일행에서 제외 시킴", // 3
      "이전의 게임을 재개", // 4
      "현재의 게임을 저장", // 5
      "게임을 마침", // 6
    ];

    int selected = await _game.showMenu(choices);
    if (selected == 0) return; // ESC pressed

    switch (selected) {
      case 1:
        await selectDifficulty();
        break;
      case 2:
        await _sortParty();
        break;
      case 3:
        await _dismissPartyMember();
        break;
      case 4:
        await selectLoadMenu();
        break;
      case 5:
        await selectSaveMenu();
        break;
      case 6:
        await processGameOver(0); // EXITCODE_BY_USER
        break;
    }
  }

  Future<void> _sortParty() async {
    final party = _game.party;
    List<HDPlayer> validPlayers = party.players
        .where((p) => p.isValid())
        .toList();
    if (validPlayers.length <= 1) {
      await _game.addLog("순서를 바꿀 수 있을만한 인원수가 아닙니다.");
      await _game.waitForAnyKey();
      _game.clearLogs();
      return;
    }

    final choices = [
      "누구의 순서를 바꾸겠습니까? (기준점)",
      ...validPlayers.map((p) => p.name),
    ];
    int srcIdx = await _game.showMenu(choices);
    if (srcIdx == 0) {
      _game.clearLogs();
      return;
    }

    final targetChoices = [
      "누구와 자리를 교환하겠습니까?",
      ...validPlayers.map((p) => p.name),
    ];
    int destIdx = await _game.showMenu(targetChoices);
    if (destIdx == 0) {
      _game.clearLogs();
      return;
    }

    var srcPlayer = validPlayers[srcIdx - 1];
    var destPlayer = validPlayers[destIdx - 1];

    int actualSrcIdx = party.players.indexOf(srcPlayer);
    int actualDestIdx = party.players.indexOf(destPlayer);

    var temp = party.players[actualSrcIdx];
    party.players[actualSrcIdx] = party.players[actualDestIdx];
    party.players[actualDestIdx] = temp;

    for (int i = 0; i < party.players.length; i++) {
      party.players[i].order = i;
    }

    await _game.addLog("일행의 순서가 변경되었습니다.", isDialogue: false);
    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> _dismissPartyMember() async {
    final party = _game.party;
    List<HDPlayer> validPlayers = party.players
        .where((p) => p.isValid())
        .toList();
    if (validPlayers.length <= 1) {
      await _game.addLog("더 이상 일행을 제외시킬 수 없습니다.");
      await _game.waitForAnyKey();
      _game.clearLogs();
      return;
    }

    final choices = [
      "누구를 일행에서 제외시키겠습니까?",
      ...validPlayers.map((p) => p.name),
    ];
    int selected = await _game.showMenu(choices);
    if (selected == 0 || selected == 1) {
      if (selected == 1) {
        await _game.addLog("당신은 파티를 떠날 수 없습니다.");
        await _game.waitForAnyKey();
      }
      _game.clearLogs();
      return;
    }

    final player = validPlayers[selected - 1];
    int actualIdx = party.players.indexOf(player);
    party.players[actualIdx].name = ""; // make it invalid

    for (int i = 0; i < party.players.length - 1; i++) {
      for (int j = 0; j < party.players.length - 1; j++) {
        if (!party.players[j].isValid() && party.players[j + 1].isValid()) {
          var temp = party.players[j];
          party.players[j] = party.players[j + 1];
          party.players[j + 1] = temp;
        }
      }
    }

    for (int i = 0; i < party.players.length; i++) {
      party.players[i].order = i;
    }

    await _game.addLog("${player.name}가 일행에서 제외되었습니다.", isDialogue: false);
    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> selectDifficulty() async {
    final party = _game.party;
    final enemyChoices = [
      "한번에 출현하는 적들의 최대치를 기입하십시오",
      "3명의 적들",
      "4명의 적들",
      "5명의 적들",
      "6명의 적들",
      "7명의 적들",
    ];
    int sel1 = await _game.showMenu(
      enemyChoices,
      initialChoice: party.maxEnemy - 2,
    );
    if (sel1 == 0) return; // ESC pressed
    party.maxEnemy = sel1 + 2;

    final encounterChoices = [
      "일행들의 지금 성격은 어떻습니까 ?",
      "일부러 전투를 피하고 싶다",
      "너무 잦은 전투는 원하지 않는다",
      "마주친 적과는 전투를 하겠다",
      "보이는 적들과는 모두 전투하겠다",
      "그들은 피에 굶주려 있다",
    ];
    int sel2 = await _game.showMenu(
      encounterChoices,
      initialChoice: 6 - party.encounter,
    );
    if (sel2 == 0) return;
    party.encounter = 6 - sel2;
  }

  Future<bool> selectLoadMenu() async {
    final choices = [
      "불러 내고 싶은 게임을 선택하십시오.",
      "없습니다",
      "본 게임 데이타",
      "게임 데이타 1 (부)",
      "게임 데이타 2 (부)",
      "게임 데이타 3 (부)",
    ];

    int selected = await _game.showMenu(choices);
    if (selected <= 1) return false;

    int slot = selected - 2;

    await _game.addLog("저장했던 게임을 지상으로 불러들이는 중입니다...");

    bool loadSuccess = await HDSaveManager.loadGame(slot);
    if (loadSuccess) {
      _game.sessionId++;
      await _game.addLog("게임을 무사히 불러왔습니다", isDialogue: false);
      await _game.waitForAnyKey();
      _game.clearLogs();
      return true;
    } else {
      await _game.addLog("게임 불러오기에 실패했습니다.", isDialogue: false);
      await _game.waitForAnyKey();
      _game.clearLogs();
      return false;
    }
  }

  Future<bool> selectSaveMenu() async {
    final choices = [
      "게임의 저장 장소를 선택하십시오.",
      "없습니다",
      "본 게임 데이타",
      "게임 데이타 1 (부)",
      "게임 데이타 2 (부)",
      "게임 데이타 3 (부)",
    ];

    int selected = await _game.showMenu(choices);
    if (selected <= 1) return false;

    int slot = selected - 2;

    await _game.addLog("현재의 게임을 저장하는 중입니다...");

    bool saveSuccess = await HDSaveManager.saveGame(slot);
    if (saveSuccess) {
      await _game.addLog("게임을 무사히 저장했습니다", isDialogue: false);
      await _game.waitForAnyKey();
      _game.clearLogs();
      return true;
    } else {
      await _game.addLog("게임 저장에 실패했습니다.", isDialogue: false);
      await _game.waitForAnyKey();
      _game.clearLogs();
      return false;
    }
  }

  Future<void> processGameOver(int exitCode) async {
    if (exitCode == 0) {
      // EXITCODE_BY_USER
      final menu = ["정말로 끝내겠습니까 ?", "       << 아니오 >>", "       <<   예   >>"];
      int res = await _game.showMenu(menu);
      if (res == 2) {
        if (!kIsWeb) {
          exit(0);
        } else {
          await _game.addLog(
            "게임을 종료합니다. 브라우저 창을 닫아주세요.",
            isDialogue: false,
          );
          await _game.waitForAnyKey();
        }
      }
      return;
    }

    if (exitCode == 1) {
      // EXITCODE_BY_ACCIDENT (Field Death)
      _game.clearLogs();
      await _game.addLog("일행은 모험중에 모두 목숨을 잃었다.", isDialogue: false);
      await _game.waitForAnyKey();
      if (await selectLoadMenu()) {
        throw GameReloadException();
      }
      if (!kIsWeb) {
        exit(0);
      }
    }

    if (exitCode == 2) {
      // EXITCODE_BY_ENEMY (Battle Death)
      _game.clearLogs();
      await _game.addLog("일행은 모두 전투에서 패했다 !!", isDialogue: false);
      await _game.waitForAnyKey();

      final menu = ["    어떻게 하시겠습니까 ?", "   이전의 게임을 재개한다", "       게임을 끝낸다"];
      int res = await _game.showMenu(menu);
      if (res == 1) {
        if (await selectLoadMenu()) {
          throw GameReloadException();
        }
      }
      if (!kIsWeb) {
        exit(0);
      }
    }
  }
}
