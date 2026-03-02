import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../models/map_model.dart';
import '../models/hd_party.dart';
import '../models/hd_game_option.dart';
import 'hd_map_loader.dart';
import 'hd_save_manager.dart';
import 'hd_battle.dart';
// import '../views/hd_window_view.dart'; // No longer needed for HDMessageWindow type
import '../scripting/hd_script_engine.dart';
import 'hd_tile_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'hd_window_manager.dart';
import 'package:flame/flame.dart'; // For image caching
import 'package:bonfire/bonfire.dart';
import '../models/hd_player.dart';
import '../hd_config.dart';
import 'hd_magic_system.dart';
import '../utils/hd_text_utils.dart';

class GameReloadException implements Exception {
  final String message;
  GameReloadException([this.message = "Game reloaded"]);
}

class HDMenu {
  final List<String> items; // Index 0 is title, items 1+ are choices
  int selectedIndex;
  int enabledCount;
  final bool clearLogs;
  final Completer<int> completer = Completer<int>();

  HDMenu(
    this.items, {
    int initialChoice = 1,
    int enabledCount = -1,
    this.clearLogs = true,
  }) : selectedIndex = initialChoice,
       enabledCount = (enabledCount == -1) ? items.length - 1 : enabledCount;
}

enum HDInputMode { map, dialogue, menu, window }

class HDGameMain with ChangeNotifier {
  static final HDGameMain _instance = HDGameMain._internal();
  factory HDGameMain() => _instance;

  HDMenu? activeMenu;
  int sessionId = 0;

  HDInputMode get currentInputMode {
    if (HDWindowManager().windows.isNotEmpty) return HDInputMode.window;
    if (activeMenu != null) return HDInputMode.menu;
    if (isWaitingForKey) return HDInputMode.dialogue;
    return HDInputMode.map;
  }

  void refresh() {
    notifyListeners();
  }

  HDGameMain._internal() {
    // Register global key handler to ensure "Any Key" and Menu work regardless of focus
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event is! KeyDownEvent) return false;

      final key = event.logicalKey;
      final mode = currentInputMode;

      // 1. Window Handling (Top Priority)
      if (mode == HDInputMode.window) {
        if (HDWindowManager().handleInput(event)) {
          return true;
        }

        // Fallback for windows that don't implement handleInput manually
        // This handles cases where a window might not explicitly consume a key,
        // but we still want to close it on Escape/Q.
        // This should be the *last* check in window handling.
        final topWindow = HDWindowManager().windows.last;
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.keyQ) {
          topWindow.isVisible = false;
          HDWindowManager().notifyListeners();
          return true;
        }
        return true; // Consume all keys when windows are open
      }

      // 2. Menu Handling
      if (mode == HDInputMode.menu) {
        final menu = activeMenu!;
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.keyW) {
          menu.selectedIndex--;
          if (menu.selectedIndex < 1) menu.selectedIndex = menu.enabledCount;
          notifyListeners();
          return true;
        } else if (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.keyS) {
          menu.selectedIndex++;
          if (menu.selectedIndex > menu.enabledCount) menu.selectedIndex = 1;
          notifyListeners();
          return true;
        } else if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.keyE) {
          final result = menu.selectedIndex;
          activeMenu = null;
          menu.completer.complete(result);
          notifyListeners();
          return true;
        } else if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.keyQ) {
          activeMenu = null;
          menu.completer.complete(0); // 0 = Cancel
          notifyListeners();
          return true;
        }
        return true; // Consume all keys while menu is active
      }

      // 3. "Any Key" Handling for Dialogue
      if (mode == HDInputMode.dialogue) {
        // Exclude Arrows/WASD and Modifiers
        bool isDirectional =
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.keyW ||
            key == LogicalKeyboardKey.keyA ||
            key == LogicalKeyboardKey.keyS ||
            key == LogicalKeyboardKey.keyD;

        bool isModifier =
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight ||
            key == LogicalKeyboardKey.controlLeft ||
            key == LogicalKeyboardKey.controlRight ||
            key == LogicalKeyboardKey.altLeft ||
            key == LogicalKeyboardKey.altRight ||
            key == LogicalKeyboardKey.metaLeft ||
            key == LogicalKeyboardKey.metaRight;

        if (!isDirectional && !isModifier) {
          dismissKeyWait();
          return true; // Consume event
        }
      }

      // 4. Map Mode - Menu Trigger
      if (mode == HDInputMode.map) {
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.keyQ ||
            key == LogicalKeyboardKey.space) {
          // Open main menu
          showMainMenu();
          return true;
        }
        // Action (Enter/E) is handled by HDPlayer for now to know facing/position
      }

      return false;
    });
  }

  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) {
        super.notifyListeners();
      }
    });
  }

  MapModel? map;
  String? errorMessage;
  int mapVersion = 0;
  BonfireGameInterface? mapViewGameRef;
  final List<TextSpan> logs = [];
  final HDParty party = HDParty();
  final HDGameOption gameOption = HDGameOption();
  final HDMapLoader _mapLoader = HDMapLoader();
  bool _isScriptRunning = false;
  bool get isScriptRunning => _isScriptRunning;

  static const int maxLinesPerPage = HDConfig.maxLinesPerPage;
  static const double consoleWidth =
      HDConfig.consoleWidth - 32.0; // Subtract padding
  static const TextStyle consoleStyle = TextStyle(
    fontSize: HDConfig.consoleFontSize,
    height: HDConfig.consoleLineHeight,
  );

  Future<void> addLog(String message, {bool isDialogue = true}) async {
    final newLines = HDTextUtils.splitToLines(
      message,
      consoleWidth,
      consoleStyle.copyWith(color: Colors.white),
    );

    for (var line in newLines) {
      if (logs.length >= maxLinesPerPage) {
        if (isDialogue) {
          // Dialogue: Wait for key and clear all
          await waitForAnyKey();
          clearLogs();
          // Wait for one frame to let UI clear
          await Future.delayed(Duration.zero);
        } else {
          // Log: Auto-scroll by removing the first line
          logs.removeAt(0);
        }
      }

      logs.add(line);
      notifyListeners();
      // Allow UI to render the added line
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  void setNewMap(MapModel newMap) {
    map = newMap;
    mapVersion++;
    notifyListeners();
  }

  Completer<void>? _keyWaitCompleter;
  bool get isWaitingForKey => _keyWaitCompleter != null;

  Future<void> waitForAnyKey() {
    if (_keyWaitCompleter != null) return _keyWaitCompleter!.future;
    _keyWaitCompleter = Completer<void>();
    notifyListeners();
    return _keyWaitCompleter!.future;
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  void dismissKeyWait() {
    if (_keyWaitCompleter != null && !_keyWaitCompleter!.isCompleted) {
      _keyWaitCompleter!.complete();
      _keyWaitCompleter = null;
      notifyListeners();
    }
  }

  // Core methods from original C++
  Future<void> init() async {
    // Pre-cache images to avoid flicker during load
    try {
      await Flame.images.loadAll([
        HDConfig.mainSpriteSheet,
        HDConfig.mainTileSheet,
      ]);
    } catch (e) {
      print("Pre-cache error: $e");
    }

    // Initialization logic
    party.setPosition(15, 15); // Default start pos for town1

    // Load Script
    await HDScriptEngine().loadScript(HDConfig.startupScript);

    // Init Map (ScriptMode = 0 / flag_map)
    HDScriptEngine().setScriptMode(0);
    await HDScriptEngine().run();
  }

  void update(double dt) {
    // Main loop update
  }

  Future<int> showMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    bool clearLogs = true,
  }) async {
    if (clearLogs) this.clearLogs();
    final menu = HDMenu(
      items,
      initialChoice: initialChoice,
      enabledCount: enabledCount,
      clearLogs: clearLogs,
    );
    activeMenu = menu;
    notifyListeners();
    return await menu.completer.future;
  }

  Future<void> showBattleMenu() async {
    // Test a real simulated battle with HDBattle
    HDBattle().init();
    HDBattle().registerEnemy(5); // Skeleton
    HDBattle().registerEnemy(7); // Slime

    HDBattle().showEnemy();

    // Fight / Run Menu
    final preMenu = ["", "적과 교전한다", "도망간다"];
    int preSel = await showMenu(preMenu, clearLogs: false);
    if (preSel == 2) {
      // Pre-battle escape attempt
      int avgLuck =
          party.players
              .where((p) => p.isValid())
              .fold(0, (sum, p) => sum + p.luck) ~/
          party.players.where((p) => p.isValid()).length;
      int avgAgility =
          HDBattle().enemies.fold(0, (sum, e) => sum + e.agility) ~/
          HDBattle().enemies.length;

      if (avgLuck + Random().nextInt(10) > avgAgility) {
        await addLog("무사히 도망쳤다...", isDialogue: false);
        await waitForAnyKey();
        clearLogs();
        return;
      } else {
        await addLog("도망에 실패했다 !", isDialogue: false);
        await waitForAnyKey();
      }
    }

    await HDBattle().start(1);

    clearLogs();
  }

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

    int selected = await showMenu(choices);

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

  Future<void> _selectPlayerForMagic() async {
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = ["누가 마법을 사용하겠습니까 ?", ...validPlayers.map((p) => p.name)];
    int selected = await showMenu(choices);
    if (selected == 0) return;

    final player = validPlayers[selected - 1];
    await HDMagicSystem.castSpell(player);
  }

  Future<void> _selectPlayerForESP() async {
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = ["누가 초능력을 사용하겠습니까 ?", ...validPlayers.map((p) => p.name)];
    int selected = await showMenu(choices);
    if (selected == 0) return;

    final player = validPlayers[selected - 1];
    await HDMagicSystem.useESP(player);
  }

  Future<void> restHere() async {
    clearLogs();

    for (var p in party.players) {
      if (!p.isValid()) continue;

      if (party.food <= 0) {
        await addLog("일행은 식량이 바닥났다", isDialogue: false);
      } else if (p.dead > 0) {
        await addLog("${p.name}${p.josaSub1} 죽었다", isDialogue: false);
      } else if (p.unconscious > 0 && p.poison == 0) {
        p.unconscious -= (p.level[0] + p.level[1] + p.level[2]);
        if (p.unconscious <= 0) {
          await addLog("${p.name}${p.josaSub1} 의식이 회복되었다", isDialogue: false);
          p.unconscious = 0;
          if (p.hp <= 0) p.hp = 1;
          party.food--;
        } else {
          await addLog("${p.name}${p.josaSub1} 여전히 의식 불명이다", isDialogue: false);
        }
      } else if (p.unconscious > 0 && p.poison > 0) {
        await addLog("독 때문에 ${p.name}의 의식은 회복되지 않았다", isDialogue: false);
      } else if (p.poison > 0) {
        await addLog("독 때문에 ${p.name}의 건강은 회복되지 않았다", isDialogue: false);
      } else {
        int recovery = (p.level[0] + p.level[1] + p.level[2]) * 2;
        int maxHp = p.endurance * p.level[0];

        bool fullHp = p.hp >= maxHp;

        p.hp += recovery;
        if (p.hp >= maxHp) {
          p.hp = maxHp;
          await addLog(
            "${p.name}${p.josaSub1} 모든 건강이 회복되었다",
            isDialogue: false,
          );
        } else {
          await addLog("${p.name}${p.josaSub1} 치료되었다", isDialogue: false);
        }

        if (!fullHp) {
          party.food--;
        }
      }

      p.sp = p.mentality * p.level[1];
      p.esp = p.concentration * p.level[2];

      // Keep max limits for dart UI
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

    await waitForAnyKey();
    clearLogs();
  }

  Future<void> showPartyStatus() async {
    clearLogs();

    await addLog("X 축 = ${party.x}", isDialogue: false);
    await addLog("Y 축 = ${party.y}", isDialogue: false);
    await addLog("남은 식량 = ${party.food}", isDialogue: false);
    await addLog("남은 황금 = ${party.gold}", isDialogue: false);
    await addLog("", isDialogue: false);

    await addLog("마법의 횃불 : ${party.magicTorch}", isDialogue: false);
    await addLog("공중 부상   : ${party.levitation}", isDialogue: false);
    await addLog("물위를 걸음 : ${party.walkOnWater}", isDialogue: false);
    await addLog("늪위를 걸음 : ${party.walkOnSwamp}", isDialogue: false);

    await waitForAnyKey();
    clearLogs();
  }

  Future<void> showHealthStatus() async {
    clearLogs();

    await addLog("                이름    중독  의식불명    죽음", isDialogue: false);
    await addLog("", isDialogue: false);

    for (var p in party.players) {
      if (p.isValid()) {
        final nameStr = p.name.padLeft(20);
        final unStr = p.unconscious.toString().padLeft(9);
        final deadStr = p.dead.toString().padLeft(7);
        final poiStr = p.poison.toString().padLeft(5);

        await addLog("$nameStr   $poiStr $unStr $deadStr", isDialogue: false);
      }
    }

    await waitForAnyKey();
    clearLogs();
  }

  Future<void> showCharacterStatus() async {
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = ["능력을 보고싶은 인물을 선택하시오", ...validPlayers.map((p) => p.name)];

    int selected = await showMenu(choices);
    if (selected == 0) return; // ESC

    final player = validPlayers[selected - 1];

    clearLogs();
    await addLog("# 이름 : ${player.name}", isDialogue: false);
    await addLog("# 성별 : ${player.getGenderName()}", isDialogue: false);
    await addLog("# 계급 : ${player.getClassName()}", isDialogue: false);
    await addLog("", isDialogue: false);
    await addLog("체력   : ${player.strength}", isDialogue: false);
    await addLog("정신력 : ${player.mentality}", isDialogue: false);
    await addLog("집중력 : ${player.concentration}", isDialogue: false);
    await addLog("인내력 : ${player.endurance}", isDialogue: false);
    await addLog("저항력 : ${player.resistance}", isDialogue: false);
    await addLog("민첩성 : ${player.agility}", isDialogue: false);
    await addLog("행운   : ${player.luck}", isDialogue: false);

    await waitForAnyKey();

    clearLogs();
    await addLog("# 이름 : ${player.name}", isDialogue: false);
    await addLog("# 성별 : ${player.getGenderName()}", isDialogue: false);
    await addLog("# 계급 : ${player.getClassName()}", isDialogue: false);
    await addLog("", isDialogue: false);

    // Using string interpolation for alignment to roughly match C++ layout
    await addLog(
      "무기의 정확성   : ${player.accuracy[0].toString().padLeft(2)}    전투 레벨   : ${player.level[0].toString().padLeft(2)}",
      isDialogue: false,
    );
    await addLog(
      "정신력의 정확성 : ${player.accuracy[1].toString().padLeft(2)}    마법 레벨   : ${player.level[1].toString().padLeft(2)}",
      isDialogue: false,
    );
    await addLog(
      "초감각의 정확성 : ${player.accuracy[2].toString().padLeft(2)}    초감각 레벨 : ${player.level[2].toString().padLeft(2)}",
      isDialogue: false,
    );
    await addLog("## 경험치   : ${player.experience}", isDialogue: false);
    await addLog("", isDialogue: false);
    await addLog("사용 무기 - ${player.getWeaponName()}", isDialogue: false);
    await addLog(
      "방패 - ${player.getShieldName().padRight(12)} 갑옷 - ${player.getArmorName()}",
      isDialogue: false,
    );

    await waitForAnyKey();
    clearLogs();
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

    int selected = await showMenu(choices);
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
    List<HDPlayer> validPlayers = party.players
        .where((p) => p.isValid())
        .toList();
    if (validPlayers.length <= 1) {
      await addLog("순서를 바꿀 수 있을만한 인원수가 아닙니다.");
      await waitForAnyKey();
      clearLogs();
      return;
    }

    final choices = [
      "누구의 순서를 바꾸겠습니까? (기준점)",
      ...validPlayers.map((p) => p.name),
    ];
    int srcIdx = await showMenu(choices);
    if (srcIdx == 0) {
      clearLogs();
      return;
    }

    final targetChoices = [
      "누구와 자리를 교환하겠습니까?",
      ...validPlayers.map((p) => p.name),
    ];
    int destIdx = await showMenu(targetChoices);
    if (destIdx == 0) {
      clearLogs();
      return;
    }

    // Swap valid players
    var srcPlayer = validPlayers[srcIdx - 1];
    var destPlayer = validPlayers[destIdx - 1];

    // actual index in party array
    int actualSrcIdx = party.players.indexOf(srcPlayer);
    int actualDestIdx = party.players.indexOf(destPlayer);

    var temp = party.players[actualSrcIdx];
    party.players[actualSrcIdx] = party.players[actualDestIdx];
    party.players[actualDestIdx] = temp;

    for (int i = 0; i < party.players.length; i++) {
      party.players[i].order = i;
    }

    await addLog("일행의 순서가 변경되었습니다.", isDialogue: false);
    await waitForAnyKey();
    clearLogs();
  }

  Future<void> _dismissPartyMember() async {
    List<HDPlayer> validPlayers = party.players
        .where((p) => p.isValid())
        .toList();
    if (validPlayers.length <= 1) {
      await addLog("더 이상 일행을 제외시킬 수 없습니다.");
      await waitForAnyKey();
      clearLogs();
      return;
    }

    final choices = ["누구를 일행에서 제외시키겠습니까?", ...validPlayers.map((p) => p.name)];
    int selected = await showMenu(choices);
    if (selected == 0 || selected == 1) {
      // 1 is usually the main character, can't be dismissed
      if (selected == 1) {
        await addLog("당신은 파티를 떠날 수 없습니다.");
        await waitForAnyKey();
      }
      clearLogs();
      return;
    }

    final player = validPlayers[selected - 1];
    int actualIdx = party.players.indexOf(player);
    party.players[actualIdx].name = ""; // make it invalid

    // Push invalid ones to the back
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

    await addLog("${player.name}가 일행에서 제외되었습니다.", isDialogue: false);
    await waitForAnyKey();
    clearLogs();
  }

  Future<void> selectDifficulty() async {
    // 1. Enemy Max Count
    final enemyChoices = [
      "한번에 출현하는 적들의 최대치를 기입하십시오",
      "3명의 적들",
      "4명의 적들",
      "5명의 적들",
      "6명의 적들",
      "7명의 적들",
    ];
    int sel1 = await showMenu(enemyChoices, initialChoice: party.maxEnemy - 2);
    if (sel1 == 0) return; // ESC pressed
    party.maxEnemy = sel1 + 2;

    // 2. Encounter Rate
    final encounterChoices = [
      "일행들의 지금 성격은 어떻습니까 ?",
      "일부러 전투를 피하고 싶다",
      "너무 잦은 전투는 원하지 않는다",
      "마주친 적과는 전투를 하겠다",
      "보이는 적들과는 모두 전투하겠다",
      "그들은 피에 굶주려 있다",
    ];
    int sel2 = await showMenu(
      encounterChoices,
      initialChoice: 6 - party.encounter,
    );
    if (sel2 == 0) return; // ESC pressed
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

    int selected = await showMenu(choices);
    if (selected <= 1) return false;

    int slot = selected - 2; // 0 for 본 게임 데이타, 1 for 게임 데이타 1 구

    await addLog("저장했던 게임을 지상으로 불러들이는 중입니다...");

    bool loadSuccess = await HDSaveManager.loadGame(slot);
    if (loadSuccess) {
      sessionId++;
      await addLog("게임을 무사히 불러왔습니다", isDialogue: false);
      await waitForAnyKey();
      clearLogs();
      return true;
    } else {
      await addLog("게임 불러오기에 실패했습니다.", isDialogue: false);
      await waitForAnyKey();
      clearLogs();
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

    int selected = await showMenu(choices);
    if (selected <= 1) return false;

    int slot = selected - 2;

    await addLog("현재의 게임을 저장하는 중입니다...");

    bool saveSuccess = await HDSaveManager.saveGame(slot);
    if (saveSuccess) {
      await addLog("게임을 무사히 저장했습니다", isDialogue: false);
      await waitForAnyKey();
      clearLogs();
      return true;
    } else {
      await addLog("게임 저장에 실패했습니다.", isDialogue: false);
      await waitForAnyKey();
      clearLogs();
      return false;
    }
  }

  Future<void> processGameOver(int exitCode) async {
    if (exitCode == 0) {
      // EXITCODE_BY_USER
      final menu = ["정말로 끝내겠습니까 ?", "       << 아니오 >>", "       <<   예   >>"];
      int res = await showMenu(menu);
      if (res == 2) {
        if (!kIsWeb) {
          exit(0);
        } else {
          // Fallback for Web: maybe just reload or show a closing screen
          await addLog("게임을 종료합니다. 브라우저 창을 닫아주세요.", isDialogue: false);
          await waitForAnyKey();
        }
      }
      return;
    }

    if (exitCode == 1) {
      // EXITCODE_BY_ACCIDENT (Field Death)
      clearLogs();
      await addLog("일행은 모험중에 모두 목숨을 잃었다.", isDialogue: false);
      await waitForAnyKey();
      if (await selectLoadMenu()) {
        throw GameReloadException();
      }
      if (!kIsWeb) {
        exit(0);
      }
    }

    if (exitCode == 2) {
      // EXITCODE_BY_ENEMY (Battle Death)
      clearLogs();
      await addLog("일행은 모두 전투에서 패했다 !!", isDialogue: false);
      await waitForAnyKey();

      final menu = ["    어떻게 하시겠습니까 ?", "   이전의 게임을 재개한다", "       게임을 끝낸다"];
      int res = await showMenu(menu);
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

  Future<void> checkTileEvent(
    int x,
    int y, {
    bool isInteraction = false,
  }) async {
    if (map == null) return;
    if (_isScriptRunning) return;

    _isScriptRunning = true;
    try {
      int tileId = map!.getTile(x, y);
      int action = HDTileProperties.getAction(tileId, gameOption.mapType);

      if (isInteraction) {
        // ONLY clear and run if the tile has a scriptable interaction action
        if (action == HDTileProperties.ACTION_TALK ||
            action == HDTileProperties.ACTION_SIGN ||
            action == HDTileProperties.ACTION_ENTER) {
          clearLogs();
          await Future.delayed(Duration.zero);

          HDScriptEngine().setTargetPos(x, y);
          HDScriptEngine().setScriptMode(action); // Match mode to tile action
          await HDScriptEngine().run();
        }
      } else {
        // Step-On (Automatic)
        // 1. Script Events
        if (action == HDTileProperties.ACTION_EVENT ||
            action == HDTileProperties.ACTION_ENTER) {
          clearLogs();
          await Future.delayed(Duration.zero);

          HDScriptEngine().setTargetPos(x, y);
          HDScriptEngine().setScriptMode(
            action,
          ); // Match mode to tile action (EVENT=3, ENTER=4)
          await HDScriptEngine().run();
        }

        // 2. Internal Engine Events (Swamp, Lava)
        if (action == HDTileProperties.ACTION_SWAMP) {
          await addLog("일행은 독이 있는 늪에 들어갔다 !!!", isDialogue: false);
        } else if (action == HDTileProperties.ACTION_LAVA) {
          await addLog("일행은 용암지대로 들어섰다 !!!", isDialogue: false);
        }
      }
    } finally {
      _isScriptRunning = false;
    }
  }

  void render() {
    // Main loop render (if needed, Bonfire handles most)
  }

  Future<bool> loadMapFromFile(String fileName) async {
    try {
      errorMessage = null;
      final newMap = await _mapLoader.loadMap(fileName);
      setNewMap(newMap);
      return true;
    } catch (e) {
      print("Failed to load map: $e");
      errorMessage = "Failed to load map: $e";
      return false;
    }
  }
}
