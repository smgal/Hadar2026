import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:hd_battle/hd_battle.dart' as hb;

import 'battle_bridge/cm2_battle_adapter.dart';
import '../application/magic_system.dart';
import '../application/save_manager.dart';
import 'package:hd_world/hd_world.dart';
import 'package:hd_world_text/hd_world_text.dart' as wtx;

import '../domain/party/member_display.dart';
import '../domain/party/party.dart';
import '../domain/party/party_actions.dart';
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

  /// 메뉴에서 여는 시험 전투. B3-01 이후 새 model 을 쓴다.
  ///
  /// 주석의 "Skeleton"·"Slime" 은 **틀렸다** — 표에서 legacyId 5·7 은
  /// Giant·Wolf 다. 이름을 고치지 않고 남겨 두는 것은 이 두 줄이
  /// `fixtures/original/town1_pair.json` 과 같은 조우이기 때문이다.
  Future<void> showBattleMenu() async {
    final battle = HDCm2BattleAdapter();
    battle.init();
    battle.registerEnemy(5); // 표 기준 Giant
    battle.registerEnemy(7); // 표 기준 Wolf
    // 싸울지 묻기 **전에** 누가 나왔는지 알린다 — cm2 의 `Battle::ShowEnemy`
    // 와 같은 자리, 같은 이유다.
    await battle.showEnemy();

    final preMenu = ["", "적과 교전한다", "도망간다"];
    int preSel = await _game.showWindowMenu(preMenu);
    if (preSel == 2) {
      final party = _session.party;
      final valid = party.present.toList();
      final avgLuck = valid.isEmpty
          ? 0
          : valid.fold<int>(0, (sum, p) => sum + p.stats.luck) ~/
                valid.length;
      // 등록된 적의 민첩 평균. 전투를 시작하기 전이라 표에서 읽는다.
      final agilities = [
        for (final key in battle.enemyKeys) hb.enemyByKey[key]!.agility,
      ];
      final avgAgility = agilities.isEmpty
          ? 0
          : agilities.reduce((a, b) => a + b) ~/ agilities.length;

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

    await battle.start(1);

    _game.clearLogs();
  }

  Future<void> _selectPlayerForMagic() async {
    final party = _session.party;
    final validPlayers = party.present.toList();
    if (validPlayers.isEmpty) return;

    final choices = [
      "누가 마법을 사용하겠습니까 ?",
      ...validPlayers.map((p) => p.displayName),
    ];
    int selected = await _game.showWindowMenu(choices);
    if (selected == 0) return;

    final player = validPlayers[selected - 1];
    await HDMagicSystem.castSpell(player);
  }

  Future<void> _selectPlayerForESP() async {
    final party = _session.party;
    final validPlayers = party.present.toList();
    if (validPlayers.isEmpty) return;

    final choices = [
      "누가 초능력을 사용하겠습니까 ?",
      ...validPlayers.map((p) => p.displayName),
    ];
    int selected = await _game.showWindowMenu(choices);
    if (selected == 0) return;

    final player = validPlayers[selected - 1];
    await HDMagicSystem.useESP(player);
  }

  Future<void> restHere() async {
    final party = _session.party;
    _game.clearLogs();

    for (final m in party.present) {
      final result = HDPartyActions.restMember(m, party);
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
    final p = r.member.noun;
    switch (r.outcome) {
      case RestOutcome.noFood:
        return "일행은 식량이 바닥났다";
      case RestOutcome.alreadyDead:
        return "$p${p.sub1} 죽었다";
      case RestOutcome.unconsciousRecovered:
        return "$p${p.sub1} 의식이 회복되었다";
      case RestOutcome.unconsciousStillOut:
        return "$p${p.sub1} 여전히 의식 불명이다";
      case RestOutcome.unconsciousPoisoned:
        return "독 때문에 $p의 의식은 회복되지 않았다";
      case RestOutcome.poisoned:
        return "독 때문에 $p의 건강은 회복되지 않았다";
      case RestOutcome.fullyHealed:
        return "$p${p.sub1} 모든 건강이 회복되었다";
      case RestOutcome.partiallyHealed:
        return "$p${p.sub1} 치료되었다";
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

    // 이제 출처가 둘이다 — 부적(상시)과 마법(칸 수). 숫자만 찍으면
    // **왜 되는지**를 말하지 못한다(BP-47 §7.4).
    final light = party.light;
    await _game.addLog(
      "어둠 속 시야 : ${light.radius}"
      "${light.moonlight ? '   (달빛 있음)' : ''}",
    );
    await _game.addLog(
      "불          : ${_lightSource(party)}",
    );
    await _game.addLog("공중 부상   : ${_capabilitySource(party, Capability.levitate, party.levitation)}");
    await _game.addLog("물위를 걸음 : ${_capabilitySource(party, Capability.walkOnWater, party.walkOnWater)}");
    await _game.addLog("늪위를 걸음 : ${_capabilitySource(party, Capability.walkOnSwamp, party.walkOnSwamp)}");

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  /// 불이 **어디서 오는지**. 숫자만 찍으면 왜 되는지를 말하지 못한다.
  String _lightSource(HDParty party) {
    final bearers = party.abilities.lightBearers;
    final spell = party.magicTorch;
    if (bearers == 0 && spell == 0) return "없음";
    return [
      if (bearers > 0) "횃불 $bearers",
      if (spell > 0) "마법 $spell칸",
    ].join(" · ");
  }

  /// 통행 능력이 부적에서 오는지 마법에서 오는지 (BP-47 §1).
  String _capabilitySource(HDParty party, Capability c, int spellLeft) {
    final worn = party.abilities.can(c);
    if (worn) return "부적 (상시)";
    if (spellLeft > 0) return "마법 $spellLeft칸";
    return "없음";
  }

  Future<void> showHealthStatus() async {
    _game.clearLogs();

    await _game.addLog("                이름    중독  의식불명    죽음");
    await _game.addLog("");

    for (final m in _session.party.present) {
      final nameStr = m.displayName.padLeft(20);
      final unStr = m.unconscious.toString().padLeft(9);
      final deadStr = m.dead.toString().padLeft(7);
      final poiStr = m.poison.toString().padLeft(5);

      await _game.addLog("$nameStr   $poiStr $unStr $deadStr");
    }

    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> showCharacterStatus() async {
    final party = _session.party;
    final validPlayers = party.present.toList();
    if (validPlayers.isEmpty) return;

    final choices = [
      "능력을 보고싶은 인물을 선택하시오",
      ...validPlayers.map((p) => p.displayName),
    ];

    int selected = await _game.showWindowMenu(choices);
    if (selected == 0) return; // ESC

    final player = validPlayers[selected - 1];

    _game.clearLogs();
    // 최종 수치를 보인다 — 장비가 얹힌 뒤의 값이다. 기본값을 보이면
    // 부적을 끼고도 숫자가 안 바뀌어 보인다.
    final stats = player.resolved;
    await _game.addLog("# 이름 : ${player.displayName}");
    await _game.addLog("# 성별 : ${player.getGenderName()}");
    await _game.addLog("# 계급 : ${player.getClassName()}");
    await _game.addLog("");
    await _game.addLog("체력   : ${stats[StatKey.strength]}");
    await _game.addLog("정신력 : ${stats[StatKey.mentality]}");
    await _game.addLog("집중력 : ${stats[StatKey.concentration]}");
    await _game.addLog("인내력 : ${stats[StatKey.endurance]}");
    await _game.addLog("저항력 : ${stats[StatKey.resistance]}");
    await _game.addLog("민첩성 : ${stats[StatKey.agility]}");
    await _game.addLog("행운   : ${stats[StatKey.luck]}");
    await _game.addLog("방어   : ${stats[StatKey.defence]}");

    await _game.waitForAnyKey();

    _game.clearLogs();
    await _game.addLog("# 이름 : ${player.displayName}");
    await _game.addLog("# 성별 : ${player.getGenderName()}");
    await _game.addLog("# 계급 : ${player.getClassName()}");
    await _game.addLog("");

    String pad(int v) => v.toString().padLeft(2);
    await _game.addLog(
      "무기의 정확성   : ${pad(stats[StatKey.accuracyPhysical])}"
      "    전투 레벨   : ${pad(player.levels.physical)}",
    );
    await _game.addLog(
      "정신력의 정확성 : ${pad(stats[StatKey.accuracyMagic])}"
      "    마법 레벨   : ${pad(player.levels.magic)}",
    );
    await _game.addLog(
      "초감각의 정확성 : ${pad(stats[StatKey.accuracyEsp])}"
      "    초감각 레벨 : ${pad(player.levels.esp)}",
    );
    await _game.addLog("## 경험치   : ${player.experience}");
    await _game.addLog("");
    // 손 구성이 무기 종류를 정한다(BP-45). 그것을 먼저 말하고 나서
    // 여덟 칸을 한 줄씩 보인다 — 콘솔 폰트가 고정폭이 아니라 정렬이
    // 문자 수로 맞지 않는다.
    await _game.addLog("싸우는 법 : ${player.weaponKindName}");
    for (final slot in EquipSlot.displayOrder) {
      await _game.addLog(
        "${wtx.slotName(slot).padRight(6)} - ${player.slotName(slot)}",
      );
    }

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
    final rows = _packRows(party);

    if (rows.isEmpty) {
      _game.clearLogs();
      await _game.addLog("## 소지품                    0 / ${party.itemCapacity}");
      await _game.addLog("");
      await _game.addLog("가진 것이 없다.");
      await _game.waitForAnyKey();
      _game.clearLogs();
    } else {
      final pages =
          (rows.length + _inventoryRowsPerPage - 1) ~/ _inventoryRowsPerPage;
      for (var page = 0; page < pages; page++) {
        _game.clearLogs();
        await _game.addLog(
          "## 소지품                    "
          "${rows.length} / ${party.itemCapacity}",
        );
        await _game.addLog("");
        final start = page * _inventoryRowsPerPage;
        final end = (start + _inventoryRowsPerPage).clamp(0, rows.length);
        for (var row = start; row < end; row++) {
          await _game.addLog(
            "${(row + 1).toString().padLeft(2)}. ${_describeRow(rows[row])}",
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

    final next = await _game.showWindowMenu(["소지품", "장비를 바꾼다"]);
    if (next == 1) await showEquipment();
  }

  /// 가방을 이름 순으로. 같은 것이 여럿이면 개수로 묶는다.
  ///
  /// 이전 모델은 20칸 배열이라 같은 물건이 여러 줄로 나왔다. 이제 가방이
  /// `{물건: 개수}` 라 한 줄이고, 칸 수는 **종류 수**를 센다.
  List<({ItemRef ref, int count})> _packRows(HDParty party) {
    final rows = [
      for (final e in party.pack.counts.entries)
        (ref: e.key, count: e.value),
    ];
    rows.sort((a, b) => _itemLabel(a.ref).compareTo(_itemLabel(b.ref)));
    return rows;
  }

  String _itemLabel(ItemRef ref) {
    final def = party0.catalog[ref];
    // 카탈로그에 없는 참조는 조용히 사라지지 않는다 — 세이브가 이 빌드에
    // 없는 물건을 들고 올라온 것이고 그것이 보여야 한다.
    return def == null ? '불확실한 물건 (${ref.value})' : wtx.itemName(def.nameKey);
  }

  HDParty get party0 => _session.party;

  String _describeRow(({ItemRef ref, int count}) row) {
    final label = _itemLabel(row.ref);
    return row.count > 1 ? '$label x${row.count}' : label;
  }

  /// 인물 → 부위 → 후보 3단계. 각 단계가 `showWindowMenu` 한 번이고
  /// 새 위젯이나 새 포트 메서드를 쓰지 않는다.
  ///
  /// **부위가 여덟이다**(BP-47 §2). 양손 무기를 들면 왼손이 잠기고, 잠긴
  /// 칸은 목록에 이유를 함께 적는다 — 회색으로 두는 것은 콘솔에서 할 수
  /// 없으므로 글자로 말한다.
  Future<void> showEquipment() async {
    final party = _session.party;
    final validPlayers = party.present.toList();
    if (validPlayers.isEmpty) return;

    final who = await _game.showWindowMenu([
      "누구의 장비인가",
      ...validPlayers.map((p) => p.displayName),
    ]);
    if (who == 0) return;
    final member = validPlayers[who - 1];

    // 부위를 고르고 바꾸는 것을 Esc 까지 반복한다 — 한 인물의 여덟 칸을
    // 채우려고 메뉴를 여덟 번 여는 것은 원작에도 없다.
    while (true) {
      final slots = EquipSlot.displayOrder;
      final locked = isOffHandLocked(member, party.catalog);
      final part = await _game.showWindowMenu([
        "어느 부위를 바꾸는가  (${member.weaponKindName})",
        ...slots.map((s) => _describeSlot(member, s, locked: locked)),
      ]);
      if (part == 0) return;
      final slot = slots[part - 1];

      if (slot == EquipSlot.leftHand && locked) {
        await _game.showMessageWindow(
          wtx.refusalMessage(RefusalReason.offHandLocked),
        );
        continue;
      }

      final candidates = party.candidates(member, slot);
      final worn = member.at(slot);
      final canClear =
          worn != null && (party.catalog[worn]?.removable ?? true);

      if (candidates.isEmpty && !canClear) {
        await _game.showMessageWindow(
          "${wtx.slotName(slot)}에 채울 것이 없다.",
        );
        continue;
      }

      final choices = <String>[
        "무엇을 채우는가",
        if (canClear) "(비운다) — ${_itemLabel(worn)}",
        ...candidates.map(_itemLabel),
      ];
      final picked = await _game.showWindowMenu(choices);
      if (picked == 0) continue;

      final refusal = (canClear && picked == 1)
          ? party.unequip(member, slot)
          : party.equip(
              member,
              slot,
              candidates[picked - (canClear ? 2 : 1)],
            );
      // 거절 이유를 말한다. **자리가 틀린 것과 직업이 틀린 것은 다른
      // 문장이다** — 하나로 뭉치면 왜 안 되는지 알 수 없다.
      if (refusal != null) {
        await _game.showMessageWindow(wtx.refusalMessage(refusal));
      }
      _game.refresh();
    }
  }

  String _describeSlot(Member m, EquipSlot slot, {required bool locked}) {
    final label = wtx.slotName(slot).padRight(6);
    if (slot == EquipSlot.leftHand && locked) {
      return "$label- (양손 무기라 잠김)";
    }
    return "$label- ${m.slotName(slot)}";
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
    // 번호가 곧 자리이므로 **자리 번호를 들고 다닌다** — 앉은 사람만 걸러
    // 놓고 그 목록의 위치로 자리를 바꾸면 빈 자리를 건너뛴 만큼 어긋난다.
    final seated = <({int seat, Member member})>[
      for (final (i, m) in party.members.indexed)
        if (m.isPresent) (seat: i, member: m),
    ];
    if (seated.length <= 1) {
      await _game.addLog("순서를 바꿀 수 있을만한 인원수가 아닙니다.");
      await _game.waitForAnyKey();
      _game.clearLogs();
      return;
    }

    final choices = [
      "누구의 순서를 바꾸겠습니까? (기준점)",
      ...seated.map((s) => s.member.displayName),
    ];
    int srcIdx = await _game.showWindowMenu(choices);
    if (srcIdx == 0) {
      _game.clearLogs();
      return;
    }

    final targetChoices = [
      "누구와 자리를 교환하겠습니까?",
      ...seated.map((s) => s.member.displayName),
    ];
    int destIdx = await _game.showWindowMenu(targetChoices);
    if (destIdx == 0) {
      _game.clearLogs();
      return;
    }

    HDPartyActions.swapMembers(
      party,
      seated[srcIdx - 1].seat,
      seated[destIdx - 1].seat,
    );

    await _game.addLog("일행의 순서가 변경되었습니다.");
    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  Future<void> _dismissPartyMember() async {
    final party = _session.party;
    final seated = <({int seat, Member member})>[
      for (final (i, m) in party.members.indexed)
        if (m.isPresent) (seat: i, member: m),
    ];
    if (seated.length <= 1) {
      await _game.addLog("더 이상 일행을 제외시킬 수 없습니다.");
      await _game.waitForAnyKey();
      _game.clearLogs();
      return;
    }

    final choices = [
      "누구를 일행에서 제외시키겠습니까?",
      ...seated.map((s) => s.member.displayName),
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

    final chosen = seated[selected - 1];
    // 이름은 **내보내기 전에** 붙잡는다 — `dismissMember` 가 지운다.
    final dismissedName = chosen.member.noun;
    HDPartyActions.dismissMember(party, chosen.seat);

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
