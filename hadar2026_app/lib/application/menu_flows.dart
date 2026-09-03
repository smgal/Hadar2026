import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../application/battle.dart';
import '../application/magic_system.dart';
import '../application/save_manager.dart';
import '../domain/item/item_type.dart';
import '../domain/party/party_actions.dart';
import '../domain/party/player.dart';
import 'equipment_flow.dart';
import 'game_reload_exception.dart';
import 'game_session.dart';
import 'ports/host_binding.dart';
import 'ports/ui_host.dart';

/// Top-level menus driven by the main game shell: command menu, party
/// inspection, rest, save/load, difficulty, game-over. Each call drives
/// the `UiHost` port for prompts and reads/writes session state through
/// [HDGameSession] (party, sessionId, …).
///
/// Lives in `application/` because it composes UI flow with domain
/// actions but holds no rendering of its own — it names no presentation
/// class, so a headless host can drive every flow here.
class HDMenuFlows {
  static final HDMenuFlows _instance = HDMenuFlows._internal();
  factory HDMenuFlows() => _instance;
  HDMenuFlows._internal();

  UiHost get _game => HDHosts().ui;
  HDGameSession get _session => HDGameSession();

  Future<void> showMainMenu() async {
    final choices = [
      "당신의 명령을 고르시오 ===>",
      "일행의 상황을 본다",
      "개인의 상황을 본다",
      "일행의 건강 상태를 본다",
      "마법을 사용한다",
      "초능력을 사용한다",
      "여기서 쉰다",
      "소지품을 본다",
      "게임 선택 상황",
    ];

    // Outer narrative cycle: keeps the overlay open across the whole
    // menu→action→message sequence so the base progress layer stays
    // hidden until everything is completely done.
    _game.beginNarrative();
    try {
      // Map-side main menu keeps the legacy centred x; all other popups
      // (battle, magic, save/load, sub-menus…) default to console-aligned.
      int selected = await _game.showWindowMenu(choices, x: 200);

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
          await showInventory();
          break;
        case 8:
          await selectGameOption();
          break;
      }
    } finally {
      await _game.endNarrative();
    }
  }

  Future<void> showBattleMenu() async {
    HDBattle().init();
    HDBattle().registerEnemy(5); // Skeleton
    HDBattle().registerEnemy(7); // Slime

    HDBattle().showEnemy();

    final preMenu = ["", "적과 교전한다", "도망간다"];
    int preSel = await _game.showWindowMenu(preMenu);
    if (preSel == 2) {
      final party = _session.party;
      int avgLuck =
          party.players
              .where((p) => p.isValid())
              .fold(0, (sum, p) => sum + p.luck) ~/
          party.players.where((p) => p.isValid()).length;
      int avgAgility =
          HDBattle().enemies.fold(0, (sum, e) => sum + e.agility) ~/
          HDBattle().enemies.length;

      if (avgLuck + Random().nextInt(10) > avgAgility) {
        await _game.addLog("무사히 도망쳤다...");
        await _game.waitForAnyKey();
        _game.clearLogs();
        return;
      } else {
        await _game.addLog("도망에 실패했다 !");
        await _game.waitForAnyKey();
      }
    }

    await HDBattle().start(1);

    _game.clearLogs();
  }

  Future<void> _selectPlayerForMagic() async {
    final party = _session.party;
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = ["누가 마법을 사용하겠습니까 ?", ...validPlayers.map((p) => p.name.text)];
    int selected = await _game.showWindowMenu(choices);
    if (selected == 0) return;

    final player = validPlayers[selected - 1];
    await HDMagicSystem.castSpell(player);
  }

  Future<void> _selectPlayerForESP() async {
    final party = _session.party;
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = ["누가 초능력을 사용하겠습니까 ?", ...validPlayers.map((p) => p.name.text)];
    int selected = await _game.showWindowMenu(choices);
    if (selected == 0) return;

    final player = validPlayers[selected - 1];
    await HDMagicSystem.useESP(player);
  }

  Future<void> restHere() async {
    final party = _session.party;
    _game.clearLogs();

    for (final p in party.players) {
      if (!p.isValid()) continue;
      final result = HDPartyActions.restPlayer(p, party);
      await _game.addLog(_restMessageFor(result));
    }

    HDPartyActions.applyRestHousekeeping(party);
    party.notifyListeners();

    await _game.waitForAnyKey();
    _game.clearLogs();
    // Leave a trace on the base progress layer so the player can see what
    // happened after the overlay disappears.
    await _game.addLog("일행이 잠시 쉬었다.", isDialogue: false);
  }

  String _restMessageFor(RestEntryResult r) {
    final p = r.player;
    switch (r.outcome) {
      case RestOutcome.noFood:
        return "일행은 식량이 바닥났다";
      case RestOutcome.alreadyDead:
        return "${p.name}${p.name.sub1} 죽었다";
      case RestOutcome.unconsciousRecovered:
        return "${p.name}${p.name.sub1} 의식이 회복되었다";
      case RestOutcome.unconsciousStillOut:
        return "${p.name}${p.name.sub1} 여전히 의식 불명이다";
      case RestOutcome.unconsciousPoisoned:
        return "독 때문에 ${p.name}의 의식은 회복되지 않았다";
      case RestOutcome.poisoned:
        return "독 때문에 ${p.name}의 건강은 회복되지 않았다";
      case RestOutcome.fullyHealed:
        return "${p.name}${p.name.sub1} 모든 건강이 회복되었다";
      case RestOutcome.partiallyHealed:
        return "${p.name}${p.name.sub1} 치료되었다";
    }
  }

  Future<void> showPartyStatus() async {
    final party = _session.party;
    _game.clearLogs();

    await _game.addLog("X 축 = ${party.x}");
    await _game.addLog("Y 축 = ${party.y}");
    await _game.addLog("남은 식량 = ${party.food}");
    await _game.addLog("남은 황금 = ${party.gold}");
    await _game.addLog("");

    await _game.addLog("마법의 횃불 : ${party.magicTorch}");
    await _game.addLog("공중 부상   : ${party.levitation}");
    await _game.addLog("물위를 걸음 : ${party.walkOnWater}");
    await _game.addLog("늪위를 걸음 : ${party.walkOnSwamp}");

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> showHealthStatus() async {
    _game.clearLogs();

    await _game.addLog("                이름    중독  의식불명    죽음");
    await _game.addLog("");

    for (var p in _session.party.players) {
      if (p.isValid()) {
        final nameStr = p.name.text.padLeft(20);
        final unStr = p.unconscious.toString().padLeft(9);
        final deadStr = p.dead.toString().padLeft(7);
        final poiStr = p.poison.toString().padLeft(5);

        await _game.addLog("$nameStr   $poiStr $unStr $deadStr");
      }
    }

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> showCharacterStatus() async {
    final party = _session.party;
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final choices = [
      "능력을 보고싶은 인물을 선택하시오",
      ...validPlayers.map((p) => p.name.text),
    ];

    int selected = await _game.showWindowMenu(choices);
    if (selected == 0) return; // ESC

    final player = validPlayers[selected - 1];

    _game.clearLogs();
    await _game.addLog("# 이름 : ${player.name}");
    await _game.addLog("# 성별 : ${player.getGenderName()}");
    await _game.addLog("# 계급 : ${player.getClassName()}");
    await _game.addLog("");
    await _game.addLog("체력   : ${player.strength}");
    await _game.addLog("정신력 : ${player.mentality}");
    await _game.addLog("집중력 : ${player.concentration}");
    await _game.addLog("인내력 : ${player.endurance}");
    await _game.addLog("저항력 : ${player.resistance}");
    await _game.addLog("민첩성 : ${player.agility}");
    await _game.addLog("행운   : ${player.luck}");

    await _game.waitForAnyKey();

    _game.clearLogs();
    await _game.addLog("# 이름 : ${player.name}");
    await _game.addLog("# 성별 : ${player.getGenderName()}");
    await _game.addLog("# 계급 : ${player.getClassName()}");
    await _game.addLog("");

    await _game.addLog(
      "무기의 정확성   : ${player.accuracy.physical.toString().padLeft(2)}    전투 레벨   : ${player.level.physical.toString().padLeft(2)}",
    );
    await _game.addLog(
      "정신력의 정확성 : ${player.accuracy.magic.toString().padLeft(2)}    마법 레벨   : ${player.level.magic.toString().padLeft(2)}",
    );
    await _game.addLog(
      "초감각의 정확성 : ${player.accuracy.esp.toString().padLeft(2)}    초감각 레벨 : ${player.level.esp.toString().padLeft(2)}",
    );
    await _game.addLog("## 경험치   : ${player.experience}");
    await _game.addLog("");
    // 한 줄에 하나씩. 실데이터 이름은 '불확실한 방패'(7자)까지 길어지고
    // 콘솔 폰트는 한글이 2배폭이라 문자 수 기준 padRight 로는 정렬이
    // 맞지 않는다. 부위가 6칸으로 늘면(G1-04) 어차피 한 줄에 못 담는다.
    await _game.addLog("사용 무기 - ${player.getWeaponName()}");
    await _game.addLog("방패 - ${player.getShieldName()}");
    await _game.addLog("갑옷 - ${player.getArmorName()}");

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  /// 가방 20칸을 콘솔에 6칸씩 보여 주고, 끝나면 장비 화면으로 넘어갈지
  /// 묻는다.
  ///
  /// 행 예산: 머리글 1 + 빈 줄 1 + 항목 6 + 빈 줄 1 + 꼬리말 1 = **10행**.
  /// `HDConfig.maxLinesPerPage` 는 13이다.
  static const int _inventoryRowsPerPage = 6;

  Future<void> showInventory() async {
    final party = _session.party;

    final filled = <int>[];
    for (var i = 0; i < party.itemCapacity; i++) {
      if (party.itemAt(i) != null) filled.add(i);
    }

    if (filled.isEmpty) {
      _game.clearLogs();
      await _game.addLog("## 소지품                    0 / ${party.itemCapacity}");
      await _game.addLog("");
      await _game.addLog("가진 것이 없다.");
      await _game.waitForAnyKey();
      _game.clearLogs();
    } else {
      final pages = (filled.length + _inventoryRowsPerPage - 1) ~/
          _inventoryRowsPerPage;
      for (var page = 0; page < pages; page++) {
        _game.clearLogs();
        await _game.addLog(
          "## 소지품                    "
          "${filled.length} / ${party.itemCapacity}",
        );
        await _game.addLog("");
        final start = page * _inventoryRowsPerPage;
        final end =
            (start + _inventoryRowsPerPage).clamp(0, filled.length);
        for (var row = start; row < end; row++) {
          final slot = filled[row];
          await _game.addLog(
            "${(row + 1).toString().padLeft(2)}. "
            "${HDEquipmentFlow.describe(party.itemAt(slot)!)}",
          );
        }
        await _game.addLog("");
        if (pages > 1) {
          await _game.addLog("(${page + 1}/$pages)");
        }
        await _game.waitForAnyKey();
      }
      _game.clearLogs();
    }

    final next = await _game.showWindowMenu([
      "소지품",
      "장비를 바꾼다",
    ]);
    if (next == 1) await showEquipment();
  }

  /// 인물 → 부위 → 후보 3단계. 각 단계가 `showWindowMenu` 한 번이고
  /// 새 위젯이나 새 포트 메서드를 쓰지 않는다.
  Future<void> showEquipment() async {
    final party = _session.party;
    final validPlayers = party.players.where((p) => p.isValid()).toList();
    if (validPlayers.isEmpty) return;

    final who = await _game.showWindowMenu([
      "누구의 장비인가",
      ...validPlayers.map((p) => p.name.text),
    ]);
    if (who == 0) return;
    final player = validPlayers[who - 1];

    // 부위를 고르고 바꾸는 것을 Esc 까지 반복한다 — 한 인물의 여섯 칸을
    // 채우려고 메뉴를 여섯 번 여는 것은 원작에도 없다.
    while (true) {
      final slots = HDEquipSlot.values;
      final part = await _game.showWindowMenu([
        "어느 부위를 바꾸는가",
        ...slots.map((s) => HDEquipmentFlow.describeSlot(player, s)),
      ]);
      if (part == 0) return;
      final slot = slots[part - 1];

      final candidates = HDEquipmentFlow.candidatesFor(party, slot);
      final canClear = HDEquipmentFlow.canUnequip(party, player, slot);

      if (candidates.isEmpty && !canClear) {
        await _game.showMessageWindow(
          "${HDEquipmentFlow.slotLabel(slot)}에 채울 것이 없다.",
        );
        continue;
      }

      final choices = <String>[
        "무엇을 채우는가",
        if (canClear) "(비운다)",
        ...candidates.map((i) => HDEquipmentFlow.describe(party.itemAt(i)!)),
      ];
      final picked = await _game.showWindowMenu(choices);
      if (picked == 0) continue;

      if (canClear && picked == 1) {
        HDEquipmentFlow.unequipToBackpack(party, player, slot);
      } else {
        final offset = canClear ? 2 : 1;
        HDEquipmentFlow.equipFromBackpack(
          party,
          player,
          slot,
          candidates[picked - offset],
        );
      }
      _game.refresh();
    }
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

    int selected = await _game.showWindowMenu(choices);
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
    final party = _session.party;
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
      ...validPlayers.map((p) => p.name.text),
    ];
    int srcIdx = await _game.showWindowMenu(choices);
    if (srcIdx == 0) {
      _game.clearLogs();
      return;
    }

    final targetChoices = [
      "누구와 자리를 교환하겠습니까?",
      ...validPlayers.map((p) => p.name.text),
    ];
    int destIdx = await _game.showWindowMenu(targetChoices);
    if (destIdx == 0) {
      _game.clearLogs();
      return;
    }

    final srcPlayer = validPlayers[srcIdx - 1];
    final destPlayer = validPlayers[destIdx - 1];
    HDPartyActions.swapMembers(
      party,
      party.players.indexOf(srcPlayer),
      party.players.indexOf(destPlayer),
    );

    await _game.addLog("일행의 순서가 변경되었습니다.");
    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> _dismissPartyMember() async {
    final party = _session.party;
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
      ...validPlayers.map((p) => p.name.text),
    ];
    int selected = await _game.showWindowMenu(choices);
    if (selected == 0 || selected == 1) {
      if (selected == 1) {
        await _game.addLog("당신은 파티를 떠날 수 없습니다.");
        await _game.waitForAnyKey();
      }
      _game.clearLogs();
      return;
    }

    final player = validPlayers[selected - 1];
    // Capture the name *before* dismissal — `dismissMember` clears it.
    final dismissedName = player.name;
    HDPartyActions.dismissMember(party, party.players.indexOf(player));

    await _game.addLog("$dismissedName가 일행에서 제외되었습니다.");
    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> selectDifficulty() async {
    final party = _session.party;
    final enemyChoices = [
      "한번에 출현하는 적들의 최대치를 기입하십시오",
      "3명의 적들",
      "4명의 적들",
      "5명의 적들",
      "6명의 적들",
      "7명의 적들",
    ];
    int sel1 = await _game.showWindowMenu(
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
    int sel2 = await _game.showWindowMenu(
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

    int selected = await _game.showWindowMenu(choices);
    if (selected <= 1) return false;

    int slot = selected - 2;

    await _game.addLog("저장했던 게임을 지상으로 불러들이는 중입니다...");

    bool loadSuccess = await HDSaveManager.loadGame(slot);
    if (loadSuccess) {
      _session.sessionId++;
      await _game.addLog("게임을 무사히 불러왔습니다");
      await _game.waitForAnyKey();
      _game.clearLogs();
      return true;
    } else {
      await _game.addLog("게임 불러오기에 실패했습니다.");
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

    int selected = await _game.showWindowMenu(choices);
    if (selected <= 1) return false;

    int slot = selected - 2;

    await _game.addLog("현재의 게임을 저장하는 중입니다...");

    bool saveSuccess = await HDSaveManager.saveGame(slot);
    if (saveSuccess) {
      await _game.addLog("게임을 무사히 저장했습니다");
      await _game.waitForAnyKey();
      _game.clearLogs();
      return true;
    } else {
      await _game.addLog("게임 저장에 실패했습니다.");
      await _game.waitForAnyKey();
      _game.clearLogs();
      return false;
    }
  }

  Future<void> processGameOver(int exitCode) async {
    if (exitCode == 0) {
      // EXITCODE_BY_USER
      final menu = ["정말로 끝내겠습니까 ?", "       << 아니오 >>", "       <<   예   >>"];
      int res = await _game.showWindowMenu(menu);
      if (res == 2) {
        if (!kIsWeb) {
          exit(0);
        } else {
          await _game.addLog("게임을 종료합니다. 브라우저 창을 닫아주세요.");
          await _game.waitForAnyKey();
        }
      }
      return;
    }

    if (exitCode == 1) {
      // EXITCODE_BY_ACCIDENT (Field Death)
      _game.clearLogs();
      await _game.addLog("일행은 모험중에 모두 목숨을 잃었다.");
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
      await _game.addLog("일행은 모두 전투에서 패했다 !!");
      await _game.waitForAnyKey();

      final menu = ["    어떻게 하시겠습니까 ?", "   이전의 게임을 재개한다", "       게임을 끝낸다"];
      int res = await _game.showWindowMenu(menu);
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
