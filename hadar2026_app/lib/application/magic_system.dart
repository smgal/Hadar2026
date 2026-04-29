import '../domain/party/player.dart';
import '../domain/magic/magic.dart';
import '../domain/window/magic_window_data.dart';
import '../hd_game_main.dart';
import '../presentation/window_manager.dart';

class HDMagicSystem {
  static Future<void> castSpell(HDPlayer player) async {
    final gameMain = HDGameMain();

    if (!player.isConscious()) {
      await gameMain.addLog(
        "${player.name}${player.josaSub1} 마법을 사용할 수 있는 상태가 아닙니다.",
        isDialogue: false,
      );
      await gameMain.waitForAnyKey();
      gameMain.clearLogs();
      return;
    }

    if (player.level[1] == 0) {
      await gameMain.addLog("당신에게는 아직 능력이 없습니다.", isDialogue: false);
      await gameMain.waitForAnyKey();
      gameMain.clearLogs();
      return;
    }

    final window = HDMagicSelectionWindow(
      player: player,
      title: "사용할 마법의 종류 ===>",
      magics: [],
    );
    HDWindowManager().addWindow(window);

    int? magicId;
    try {
      while (true) {
        int result = await window.result;
        if (result == -1) break; // Cancel or ESC

        if (window.mode == HDSelectionMode.magic) {
          magicId = result;
          break;
        } else {
          // If surprisingly it completed in categories, just reset result and continue
          window.resetCompleter();
        }
      }
    } finally {
      HDWindowManager().removeWindow(window);
    }

    if (magicId == null) return;

    final magic = HDMagicMap.getMagic(magicId);
    int spCost = (magicId >= 33) ? 10 : 5;

    if (player.sp < spCost) {
      await gameMain.addLog("마법 지수가 충분하지 않습니다.", isDialogue: false);
      await gameMain.waitForAnyKey();
      gameMain.clearLogs();
      return;
    }

    // Logic for Heal
    if (magicId >= 19 && magicId <= 32) {
      final pChoices = ["누구에게 사용할 것입니까?"];
      for (var p in gameMain.party.players) {
        if (p.isValid()) pChoices.add(p.name);
      }
      int tSel = await gameMain.showMenu(pChoices);
      if (tSel == 0) return;

      player.sp -= spCost;
      var target = gameMain.party.players[tSel - 1];
      await gameMain.addLog(
        "${player.name}${player.josaSub1} ${target.name}에게 ${magic.name}${magic.josaObj} 시전했다!",
        isDialogue: false,
      );

      if (magicId == 19) {
        int recovery = (player.level[1] * 5);
        target.hp += recovery;
        if (target.hp > target.maxHp) target.hp = target.maxHp;
        await gameMain.addLog("${target.name}의 건강이 회복되었다!", isDialogue: false);
      }
    } else if (magicId >= 33 && magicId <= 39) {
      player.sp -= spCost;
      if (magicId == 33) {
        gameMain.party.magicTorch += 10;
        await gameMain.addLog("주위가 횃불의 기운으로 밝아졌다.", isDialogue: false);
      } else if (magicId == 34) {
        gameMain.party.levitation = 1;
        await gameMain.addLog("일행의 몸이 가벼워졌다.", isDialogue: false);
      }
    } else {
      player.sp -= spCost;
      await gameMain.addLog(
        "${player.name}${player.josaSub1} ${magic.name}${magic.josaObj} 시전했다! (전투 외)",
        isDialogue: false,
      );
    }

    await gameMain.waitForAnyKey();
    gameMain.clearLogs();
  }

  static Future<void> useESP(HDPlayer player) async {
    final gameMain = HDGameMain();

    if (!player.isConscious()) {
      await gameMain.addLog(
        "${player.name}${player.josaSub1} 초감각을 사용할 수 있는 상태가 아닙니다.",
        isDialogue: false,
      );
      await gameMain.waitForAnyKey();
      gameMain.clearLogs();
      return;
    }

    if (player.level[2] == 0 && !gameMain.party.canUseEsp) {
      await gameMain.addLog("당신에게는 아직 능력이 없습니다.", isDialogue: false);
      await gameMain.waitForAnyKey();
      gameMain.clearLogs();
      return;
    }

    final window = HDMagicSelectionWindow(
      player: player,
      title: "사용할 초감각의 종류 ======>",
      magics: [],
    );
    // ESP starts from 41 to 45 (or 40-45)
    window.selectCategory(40, 45, window.getAvailableSpells(player, 40, 45));
    HDWindowManager().addWindow(window);

    int? magicId;
    try {
      int result = await window.result;
      if (result != -1) magicId = result;
    } finally {
      HDWindowManager().removeWindow(window);
    }

    if (magicId == null) return;

    // 5 = 염력 (전투용)
    if (magicId == 45) {
      final m = HDMagicMap.getMagic(45);
      await gameMain.addLog(
        "${m.name}${m.josaSub1} 전투 모드에서만 사용됩니다.",
        isDialogue: false,
      );
      await gameMain.waitForAnyKey();
      gameMain.clearLogs();
      return;
    }

    int spCost = 10;
    if (player.esp < spCost) {
      await gameMain.addLog("ESP 지수가 충분하지 않습니다.", isDialogue: false);
      await gameMain.waitForAnyKey();
      gameMain.clearLogs();
      return;
    }

    player.esp -= spCost;
    final magic = HDMagicMap.getMagic(magicId);

    if (magicId == 41) {
      // 41: 투시
      await gameMain.addLog(
        "${player.name}${player.josaSub1} ${magic.name}${magic.josaObj} 사용했다!",
        isDialogue: false,
      );

      // Logic would go here
    } else {
      await gameMain.addLog(
        "${player.name}${player.josaSub1} ${magic.name}${magic.josaObj} 사용했다!",
        isDialogue: false,
      );
    }

    await gameMain.waitForAnyKey();
    gameMain.clearLogs();
  }

  static Future<bool> castBattleSpellUI(
    HDPlayer player,
    int cmd,
    List<int> commandArgs,
  ) async {
    final gameMain = HDGameMain();

    // cmd:
    // 2: 한 명의 적에게 마법 공격 (1~3)
    // 3: 모든 적에게 마법 공격 (4~10)
    // 4: 적에게 특수 마법 공격 (11~18)
    // 5: 일행을 치료 (19~32)
    // 6: 적에게 초능력 사용 (41~45)

    int minId = 1, maxId = 18;
    int spCost = 5;
    String catName = "";

    if (cmd == 2) {
      minId = 1;
      maxId = 3;
      catName = "공격 마법";
    } else if (cmd == 3) {
      minId = 4;
      maxId = 10;
      catName = "전체 공격 마법";
    } else if (cmd == 4) {
      minId = 11;
      maxId = 18;
      catName = "특수 공격 마법";
    } else if (cmd == 5) {
      minId = 19;
      maxId = 32;
      catName = "치료 마법";
      spCost = 10;
    } else if (cmd == 6) {
      minId = 41;
      maxId = 45;
      catName = "초감각 능력";
      spCost = 10;
    }

    int availableSpells = (cmd == 6) ? player.level[2] : player.level[1];
    if (availableSpells > (maxId - minId + 1))
      availableSpells = (maxId - minId + 1);

    if (availableSpells <= 0) {
      await gameMain.addLog("사용 가능한 기술이 없습니다.");
      return false;
    }

    final choices = ["사용할 $catName ===>"];
    for (int i = 0; i < availableSpells; i++) {
      choices.add(HDMagicMap.getMagic(minId + i).name);
    }

    int selected = await gameMain.showMenu(choices);
    if (selected == 0) return false;

    // Check SP/ESP
    if (cmd == 6) {
      if (player.esp < spCost) {
        await gameMain.addLog("ESP 지수가 충분하지 않습니다.");
        await gameMain.waitForAnyKey();
        return false;
      }
    } else {
      if (player.sp < spCost) {
        await gameMain.addLog("마법 지수가 충분하지 않습니다.");
        await gameMain.waitForAnyKey();
        return false;
      }
    }

    int magicId = minId + selected - 1;
    commandArgs[1] = magicId; // Store selected magic id

    // Target Selection
    if (cmd == 2 || cmd == 4 || cmd == 6) {
      commandArgs[2] =
          0; // Temporarily placeholder since actual enemy target is chosen inside Battle UI via `_selectEnemyUI` in Battle class
      // We return true because magic index is saved to commandArgs[1], Battle class will ask target next.
    } else if (cmd == 5) {
      // Heal single target vs all targets
      if (magicId >= 19 && magicId <= 25) {
        // Single target heal
        return true;
      } else {
        // All target heal
        commandArgs[2] = -1; // All
      }
    } else if (cmd == 3) {
      commandArgs[2] = -1; // All enemies
    }

    return true;
  }
}
