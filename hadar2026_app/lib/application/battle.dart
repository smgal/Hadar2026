import 'dart:math';
import 'package:flutter/foundation.dart';

import '../domain/battle/battle_result.dart';
import '../domain/battle/enemy.dart';
import '../domain/battle/enemy_data.dart';
import '../domain/magic/magic.dart';
import '../domain/party/party.dart';
import '../domain/party/player.dart';
import '../domain/text/noun.dart';
import 'game_reload_exception.dart';
import 'game_session.dart';
import 'ports/host_binding.dart';
import 'ports/ui_host.dart';
import 'magic_system.dart';
import 'menu_flows.dart';

class HDBattle with ChangeNotifier {
  static final HDBattle _instance = HDBattle._internal();
  factory HDBattle() => _instance;
  HDBattle._internal();

  // --- domain/host accessors (ports + session, no facade) ---
  UiHost get _host => HDHosts().ui;
  HDParty get _party => HDGameSession().party;

  bool isBattleActive = false;
  List<HDEnemy> enemies = [];
  HDBattleResult _battleResult = HDBattleResult.none;
  int selectedEnemyIndex = -1;

  List<List<int>> playerCommands = [];

  /// cm2 `Battle::Result()`. Returns [HDBattleResult.none]'s wire (-1)
  /// until a battle has actually finished — see the enum.
  int result() => _battleResult.wire;

  void init() {
    enemies.clear();
    playerCommands.clear();
    isBattleActive = false;
    _battleResult = HDBattleResult.none;
    selectedEnemyIndex = -1;
    notifyListeners();
  }

  /// Adds one enemy from [enemyTable]. Valid ids are **0..74** — the
  /// whole table.
  ///
  /// The guard used to read `<= 0`, which made id 0 (`Orc`) impossible to
  /// summon from cm2 even though the row exists. Nothing used 0 as a
  /// sentinel: across every shipped script `Battle::RegisterEnemy` is
  /// called with 1, 3, 5, 7, 26, 69, 71 (and a commented-out 75), never
  /// 0. An out-of-range id is now reported rather than dropped —
  /// `town1.cm2:50` has a commented `RegisterEnemy(75)` that the silent
  /// guard would have swallowed.
  void registerEnemy(int enemyTableId) {
    if (enemyTableId < 0 || enemyTableId >= enemyTable.length) {
      debugPrint(
        'HDBattle: [WARN] registerEnemy($enemyTableId) is outside '
        '[0, ${enemyTable.length}) — ignored',
      );
      return;
    }
    enemies.add(HDEnemy(enemyTable[enemyTableId]));
  }

  void showEnemy() {
    if (enemies.isEmpty) return;
    // Map same-name enemies to "Name xN" or just print names
    Map<String, int> counts = {};
    for (var e in enemies) {
      counts[e.name.text] = (counts[e.name.text] ?? 0) + 1;
    }

    List<String> displayNames = [];
    counts.forEach((name, count) {
      if (count > 1) {
        displayNames.add("$name x $count");
      } else {
        displayNames.add(name);
      }
    });

    String enemyNames = displayNames.join(", ");
    _host.addLog(
      "$enemyNames ${enemies.first.name.sub2} 나타났다 !",
    );
  }

  Future<int> _selectEnemyUI() async {
    List<String> options = ["공격할 적을 선택하십시오 ===>"];
    List<int> aliveIndices = [];

    for (int i = 0; i < enemies.length; i++) {
      if (enemies[i].isConscious()) {
        options.add(enemies[i].name.text);
        aliveIndices.add(i);
      }
    }

    if (options.length == 1) return -1; // no enemies left?

    int selected = await _host.showWindowMenu(options);
    selectedEnemyIndex = -1;
    notifyListeners();

    if (selected == 0) return -1; // canceled
    return aliveIndices[selected - 1];
  }

  Future<void> start(int mode) async {
    try {
      isBattleActive = true;
      // The battle has started but has no outcome yet; the settlement
      // below decides it.
      _battleResult = HDBattleResult.none;
      notifyListeners();

      playerCommands = List.generate(4, (_) => [0, 0, 0]);

      while (isBattleActive && _enemiesAlive() && _playersAlive()) {
        bool assaultPushed = await _modeAssault();
        if (!assaultPushed) {
          _host.clearLogs();
          break;
        }

        _host.clearLogs();
        for (var p in _party.players) {
          if (!p.isConscious()) continue;
          int order = p.order;

          int cmd = playerCommands[order][0];
          int target = playerCommands[order][2];

          if (cmd == 1 || cmd == 8) {
            await _executeAttack(p, target);
          } else if (cmd == 7) {
            if (_tryToRunAway(p)) {
              _battleResult = HDBattleResult.evade;
              await gotoEndBattle();
              return;
            }
          } else if (cmd >= 2 && cmd <= 6) {
            final magic = HDMagicMap.getMagic(playerCommands[order][1]);
            int targetId = playerCommands[order][2];

            if (cmd == 5) {
              // Heal
              await _host.addLog(
                "${p.name}${p.name.sub1} ${magic.name}${magic.name.obj} 시전했다!",
              );
              // Simulate heal resolution
              await _host.addLog("아군의 상처가 치료되었다.");
            } else {
              // Attack / ESP
              await _host.addLog(
                "${p.name}${p.name.sub1} ${magic.name}${magic.name.obj} 시전했다!",
              );
              if (targetId == -1) {
                // all enemies
                for (var t in enemies) {
                  if (!t.isConscious()) continue;
                  int dmg =
                      (p.level.magic + p.level.esp) * 5 + Random().nextInt(10);
                  t.hp -= dmg;
                  await _host.addLog(
                    "${t.name}에게 $dmg의 데미지!",
                  );
                  if (t.hp <= 0) {
                    t.dead = 1;
                    await _host.addLog(
                      "${t.name}${t.name.sub2} 죽었다.",
                    );
                  }
                }
              } else {
                if (!enemies[targetId].isConscious()) {
                  targetId = enemies.indexWhere((e) => e.isConscious());
                }
                if (targetId != -1) {
                  var t = enemies[targetId];
                  int dmg =
                      (p.level.magic + p.level.esp) * 8 + Random().nextInt(15);
                  t.hp -= dmg;
                  await _host.addLog(
                    "${t.name}에게 $dmg의 데미지!",
                  );
                  if (t.hp <= 0) {
                    t.dead = 1;
                    await _host.addLog(
                      "${t.name}${t.name.sub2} 죽었다.",
                    );
                  }
                }
              }
            }
            await _host.waitForAnyKey();
          }

          if (!_enemiesAlive()) break;
        }

        if (!_enemiesAlive() || _battleResult == HDBattleResult.evade) break;

        _host.addLog(""); // spacer

        // Enemy Turn
        for (var e in enemies) {
          if (e.poison > 0) {
            if (e.unconscious > 0) {
              e.dead = 1;
            } else {
              e.hp -= e.poison;
              if (e.hp <= 0) e.unconscious = 1;
            }
          }

          if (e.unconscious == 0 && e.dead == 0) {
            await _enemyAttack(e);
          }

          if (!_playersAlive()) {
            _battleResult = HDBattleResult.lose;
            break;
          }
        }

        await _host.waitForAnyKey();
      }

      if (!_playersAlive()) {
        _battleResult = HDBattleResult.lose;
      } else if (!_enemiesAlive() &&
          _battleResult != HDBattleResult.evade) {
        _battleResult = HDBattleResult.win;
      }

      await gotoEndBattle();
    } on GameReloadException {
      isBattleActive = false;
      notifyListeners();
      rethrow; // Propagate to script engine so it stops executing further statements
    }
  }

  Future<void> gotoEndBattle() async {
    isBattleActive = false;
    notifyListeners();

    switch (_battleResult) {
      case HDBattleResult.win:
        await _settleWin();
      case HDBattleResult.lose:
        await _host.addLog("파티가 전멸했습니다.");
        await HDMenuFlows().processGameOver(2);
      case HDBattleResult.evade:
        await _host.addLog("무사히 도망쳤다...");
      case HDBattleResult.none:
        // The loop exited without settling — a real bug if it happens,
        // so say so instead of silently reporting a win the way the old
        // default did.
        debugPrint(
          'HDBattle: [WARN] gotoEndBattle() with no result — the battle '
          'loop exited without settling',
        );
    }

    await _host.waitForAnyKey();
    _host.clearLogs();
  }

  Future<void> _settleWin() async {
    _host.clearLogs();
    int totExp = enemies.fold(0, (xp, e) {
      int plus = e.data.id + 1;
      plus = (plus * plus * plus) ~/ 8;
      return xp + max(1, plus);
    });
    await _host.addLog(
      "전투에서 승리하여 경험치 $totExp을 얻었다.",
    );
    for (var p in _party.players) {
      if (p.isConscious()) {
        p.experience += totExp;
        if (p.checkLevelUp()) {
          await _host.addLog(
            "${p.name}${p.name.sub1} 전투 레벨이 ${p.level.physical}로 올랐다!",
          );
        }
      }
    }
    _party.gold += enemies.fold(
      0,
      (g, e) => g + e.level * 5,
    ); // Add dummy gold
  }

  Future<bool> _modeAssault() async {
    bool autoBattle = false;
    for (var p in _party.players) {
      if (!p.isConscious()) continue;
      int order = p.order;

      if (!autoBattle) {
        String str1 = "${p.name}의 전투 모드 ===>";
        final wName = HDNoun(p.getWeaponName());
        String str2 = "한 명의 적을 $wName${wName.withJosa} 공격";

        List<String> menuStr = [
          str1,
          str2,
          "한 명의 적에게 마법 공격",
          "모든 적에게 마법 공격",
          "적에게 특수 마법 공격",
          "일행을 치료",
          "적에게 초능력 사용",
        ];

        if (order == 0) {
          menuStr.add("일행에게 무조건 공격 할 것을 지시");
        } else {
          menuStr.add("도망을 시도함");
        }

        int selected = await _host.showWindowMenu(menuStr);
        if (selected != 1) {
          _host.clearLogs();
        }

        if (selected == 7 && order == 0) {
          selected = 8;
          autoBattle = true;
        }

        playerCommands[order][0] = selected;
      } else {
        playerCommands[order][0] = 8;
      }

      // Action based branch
      switch (playerCommands[order][0]) {
        case 1:
          int selectedTarget = await _selectEnemyUI();
          _host.clearLogs();
          if (selectedTarget == -1) {
            playerCommands[order][0] = 0;
          } else {
            playerCommands[order][1] = p.weapon;
            playerCommands[order][2] = selectedTarget;
          }
          break;
        case 2:
        case 3:
        case 4:
        case 5:
        case 6:
          _host.clearLogs();
          bool spellResult = await HDMagicSystem.castBattleSpellUI(
            p,
            playerCommands[order][0],
            playerCommands[order],
          );
          if (!spellResult) {
            playerCommands[order][0] = 0; // Cancelled or failed
          } else if (playerCommands[order][2] == 0 &&
              playerCommands[order][0] != 3 &&
              playerCommands[order][0] != 5) {
            // Needs single enemy target
            int selectedTarget = await _selectEnemyUI();
            _host.clearLogs();
            if (selectedTarget == -1) {
              playerCommands[order][0] = 0; // Cancel
            } else {
              playerCommands[order][2] = selectedTarget;
            }
          }
          break;
        case 8:
          // Auto attack processing: class/level rules.
          // For now, simple attack on first alive enemy.
          playerCommands[order][0] = 1;
          playerCommands[order][1] = p.weapon;
          playerCommands[order][2] = enemies.indexWhere((e) => e.isConscious());
          break;
      }
    }
    return true;
  }

  bool _enemiesAlive() => enemies.any((e) => e.isConscious());
  bool _playersAlive() =>
      _party.players.any((p) => p.isConscious());

  bool _tryToRunAway(HDPlayer p) {
    _host.addLog(
      "${p.name}${p.name.sub1} 도망을 시도했다...",
    );

    int avgEnemyAgility = 0;
    int consciousEnemies = 0;
    for (var e in enemies) {
      if (e.isConscious()) {
        avgEnemyAgility += e.agility;
        consciousEnemies++;
      }
    }
    if (consciousEnemies > 0) avgEnemyAgility ~/= consciousEnemies;

    // Run Score based on agility and luck
    int playerRunScore = (p.agility + p.luck) ~/ 2 + Random().nextInt(20);
    int enemyBlockScore = avgEnemyAgility + 10;

    if (playerRunScore > enemyBlockScore) {
      notifyListeners();
      return true;
    } else {
      _host.addLog("그러나 실패했다.");
      notifyListeners();
      return false;
    }
  }

  Future<void> _executeAttack(HDPlayer p, int targetIx) async {
    if (targetIx < 0 ||
        targetIx >= enemies.length ||
        !enemies[targetIx].isConscious()) {
      targetIx = enemies.indexWhere((e) => e.isConscious());
      if (targetIx == -1) return;
    }

    selectedEnemyIndex = targetIx;
    notifyListeners();

    var t = enemies[targetIx];

    // Instakill check for unconscious enemies
    if (t.unconscious > 0 && t.dead == 0) {
      t.hp = 0;
      t.dead = 1;
      await _host.addLog(
        "${p.name}${p.name.sub1} 의식불명 상태인 ${t.name}${t.name.obj} 가볍게 처치했다!",
      );
      // P plus XP
      p.experience += t.level * 10;
      return;
    }

    if (Random().nextInt(20) > p.accuracy.physical) {
      await _host.addLog("${p.name}의 공격은 빗나갔다....");
      return;
    }

    if (Random().nextInt(100) < t.resistance) {
      await _host.addLog(
        "${t.name}${t.name.sub1} ${p.name}의 공격을 저지했다",
      );
      return;
    }

    int damage = (p.strength * p.powOfWeapon * p.level.physical) ~/ 20;
    damage -= (damage * Random().nextInt(50)) ~/ 100;
    // `t` here is the *enemy* — note `t.level` is a plain int, whereas a
    // player's is a SkillStats. Enemies wear no equipment, so this
    // defence term is not the one equipment feeds; that is the player's
    // side below (`_enemyAttack`). GROUND_TRUTH H-1's first edition read
    // these two lines as one, which is where "장비를 쓰려면 전투식 변경이
    // 선행" came from.
    damage -= (t.ac * t.level * (Random().nextInt(10) + 1)) ~/ 10;

    if (damage <= 0) {
      await _host.addLog(
        "그러나 ${t.name}${t.name.sub1} ${p.name}의 공격을 막았다",
      );
      return;
    }

    t.hp -= damage;
    notifyListeners();
    final wName = HDNoun(p.getWeaponName());
    await _host.addLog(
      "${p.name}${p.name.sub1} $wName${wName.withJosa} ${t.name}${t.name.obj} 공격하여 $damage 데미지!",
    );

    if (t.hp <= 0) {
      t.hp = 0;
      t.unconscious =
          0; // if it was conscious, goes unconscious first in hadar sometimes but let's just do death for simplicity
      t.dead = 1;
      await _host.addLog(
        "${t.name}${t.name.sub1} ${p.name}의 공격으로 치명상을 입었다",
      );
      p.experience += t.level * 10;
    }
  }

  Future<void> _enemyAttack(HDEnemy e) async {
    var targets = _party.players
        .where((p) => p.isConscious())
        .toList();
    if (targets.isEmpty) return;

    HDPlayer t = targets[Random().nextInt(targets.length)];

    // Enemy Magic/Special chance
    if ((e.special > 0 || e.castLevel > 0) &&
        (Random().nextInt(e.accuracy[0] * 1000 + 1) >
            Random().nextInt(e.accuracy[1] * 1000 + 1)) &&
        e.strength > 0) {
      // Physical preferred by roll
    } else {
      if (e.castLevel > 0 || e.special > 0) {
        // Simulated magic/special attack
        await _host.addLog(
          "${e.name}${e.name.sub2} 마법/특수 능력을 사용했다!",
        );
        int magDmg = (e.level * 5) + Random().nextInt(10);
        t.hp -= magDmg;
        await _host.addLog(
          "${t.name}에게 $magDmg 데미지!",
        );
        if (t.hp <= 0) {
          t.dead = 1;
          await _host.addLog(
            "${t.name}${t.name.sub1} 의식을 잃고 쓰러졌다.",
          );
        }
        return;
      }
    }

    if (Random().nextInt(50) < t.resistance) {
      await _host.addLog(
        "${e.name}${e.name.sub1} ${t.name}${t.name.obj} 공격했다.",
      );
      await _host.addLog(
        "그러나, ${t.name}${t.name.sub1} 적의 공격을 저지했다.",
      );
      return;
    }

    int damage = (e.strength * e.level * (Random().nextInt(10) + 1)) ~/ 10;
    // The player's defence. `t.ac` is HDPlayer.ac = baseAc + every worn
    // slot's param.ac (G1-05), so equipment reaches the formula here
    // without this line changing. powOfShield/powOfArmor are read
    // nowhere — defence runs on `ac` alone (GROUND_TRUTH H-1 corrected).
    damage -= (t.ac * t.level.physical * (Random().nextInt(10) + 1)) ~/ 10;

    if (damage <= 0) {
      await _host.addLog(
        "${e.name}${e.name.sub1} ${t.name}${t.name.obj} 공격했다.",
      );
      await _host.addLog(
        "그러나, ${t.name}${t.name.sub1} 적의 공격을 방어했다.",
      );
      return;
    }

    t.hp -= damage;
    await _host.addLog(
      "${e.name}${e.name.sub1} ${t.name}${t.name.obj} 공격하여 $damage 데미지!",
    );

    if (t.hp <= 0) {
      t.dead = 1;
      await _host.addLog(
        "${t.name}${t.name.sub1} 의식을 잃고 쓰러졌다.",
      );
    }
  }
}
