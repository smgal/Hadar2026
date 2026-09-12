import 'package:hd_world/hd_world.dart';

import '../domain/party/member_display.dart';
import '../domain/magic/magic.dart';
import '../domain/window/magic_window_data.dart';
import 'ports/host_binding.dart';
import 'game_session.dart';
import 'window_manager.dart';

class HDMagicSystem {
  static Future<void> castSpell(Member player) async {
    final ui = HDHosts().ui;

    if (!player.isConscious) {
      await ui.addLog(
        "${player.noun}${player.noun.sub1} 마법을 사용할 수 있는 상태가 아닙니다.",
      );
      await ui.waitForAnyKey();
      ui.clearLogs();
      return;
    }

    if (player.levels.magic == 0) {
      await ui.addLog("당신에게는 아직 능력이 없습니다.");
      await ui.waitForAnyKey();
      ui.clearLogs();
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

    if (player.spellPoints < spCost) {
      await ui.addLog("마법 지수가 충분하지 않습니다.");
      await ui.waitForAnyKey();
      ui.clearLogs();
      return;
    }

    // Logic for Heal
    if (magicId >= 19 && magicId <= 32) {
      final pChoices = ["누구에게 사용할 것입니까?"];
      for (var p in HDGameSession().party.members) {
        if (p.isValid()) pChoices.add(p.displayName);
      }
      int tSel = await ui.showWindowMenu(pChoices);
      if (tSel == 0) return;

      player.spellPoints -= spCost;
      var target = HDGameSession().party.members[tSel - 1];
      await ui.addLog(
        "${player.noun}${player.noun.sub1} ${target.displayName}에게 ${magic.name}${magic.name.obj} 시전했다!",
      );

      if (magicId == 19) {
        int recovery = (player.levels.magic * 5);
        target.hitPoints += recovery;
        if (target.hitPoints > target.maxHitPoints)
          target.hitPoints = target.maxHitPoints;
        await ui.addLog("${target.displayName}의 건강이 회복되었다!");
      }
    } else if (magicId >= 33 && magicId <= 39) {
      player.spellPoints -= spCost;
      if (magicId == 33) {
        HDGameSession().party.magicTorch += 10;
        await ui.addLog("주위가 횃불의 기운으로 밝아졌다.");
      } else if (magicId == 34) {
        HDGameSession().party.levitation = 1;
        await ui.addLog("일행의 몸이 가벼워졌다.");
      }
    } else {
      player.spellPoints -= spCost;
      await ui.addLog(
        "${player.noun}${player.noun.sub1} ${magic.name}${magic.name.obj} 시전했다! (전투 외)",
      );
    }

    await ui.waitForAnyKey();
    ui.clearLogs();
  }

  static Future<void> useESP(Member player) async {
    final ui = HDHosts().ui;

    if (!player.isConscious) {
      await ui.addLog(
        "${player.noun}${player.noun.sub1} 초감각을 사용할 수 있는 상태가 아닙니다.",
      );
      await ui.waitForAnyKey();
      ui.clearLogs();
      return;
    }

    if (player.levels.esp == 0 && !HDGameSession().party.canUseEsp) {
      await ui.addLog("당신에게는 아직 능력이 없습니다.");
      await ui.waitForAnyKey();
      ui.clearLogs();
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
      await ui.addLog(
        "${m.name}${m.name.sub1} 전투 모드에서만 사용됩니다.",
      );
      await ui.waitForAnyKey();
      ui.clearLogs();
      return;
    }

    int spCost = 10;
    if (player.espPoints < spCost) {
      await ui.addLog("ESP 지수가 충분하지 않습니다.");
      await ui.waitForAnyKey();
      ui.clearLogs();
      return;
    }

    player.espPoints -= spCost;
    final magic = HDMagicMap.getMagic(magicId);

    if (magicId == 41) {
      // 41: 투시
      await ui.addLog(
        "${player.noun}${player.noun.sub1} ${magic.name}${magic.name.obj} 사용했다!",
      );

      // Logic would go here
    } else {
      await ui.addLog(
        "${player.noun}${player.noun.sub1} ${magic.name}${magic.name.obj} 사용했다!",
      );
    }

    await ui.waitForAnyKey();
    ui.clearLogs();
  }

}
