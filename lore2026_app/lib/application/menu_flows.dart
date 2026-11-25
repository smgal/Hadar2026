import 'dart:async';

import 'package:lore_world/lore_world.dart';

import 'dev/dev_jump.dart';
import 'dev/dev_mode.dart';
import 'field_magic.dart';
import 'field_rules.dart';
import 'game_reload_exception.dart';
import 'game_session.dart';
import 'ports/host_binding.dart';
import 'ports/ui_host.dart';
import 'save_manager.dart';
import 'scripting/script_engine_adapter.dart';
import 'tile_event_dispatcher.dart';
import 'title_flow.dart';
import 'world_text.dart';

/// 주 메뉴와 그 아래 화면들 (제13장 13.3 · 13.4, 제11장 11.6 · 11.9).
///
/// ```
/// 당신의 명령을 고르시오 ===>
///   일행의 상황을 본다          개인의 상황을 본다
///   일행이 가진 물품을 확인      일행의 건강 상태를 본다
///   마법을 사용한다             초능력을 사용한다
///   무기 장착 및 해제           여기서 쉰다
///   물품을 사용한다             게임 선택 상황
/// ```
///
/// 규칙은 전부 `LoreWorld` 의 명령이 정한다. 여기는 묻고, 넘기고, 돌아온
/// 결과를 말로 옮긴다 (`worldLines`).
class HDMenuFlows {
  static final HDMenuFlows _instance = HDMenuFlows._internal();
  factory HDMenuFlows() => _instance;
  HDMenuFlows._internal();

  UiHost get _game => HDHosts().ui;
  HDGameSession get _session => HDGameSession();
  LoreWorld get _world => _session.party.world;

  void _changed() {
    _session.party.notifyListeners();
    _game.refresh();
  }

  Future<void> _report(Outcome outcome) async {
    for (final line in worldLines(outcome)) {
      await _game.addLog(line);
    }
    _changed();
  }

  Future<void> _pause() async {
    await _game.waitForAnyKey();
    _game.clearLogs();
  }

  /// 「한 명을 고르시오」. [seats] 중에서 고른다. 취소하면 null.
  Future<int?> _pickSeat(String prompt, List<int> seats) async {
    if (seats.isEmpty) return null;
    final picked = await _game.showWindowMenu([
      prompt,
      for (final s in seats) _world.member(s)!.name,
    ]);
    return picked <= 0 ? null : seats[picked - 1];
  }

  List<int> get _commandSeats => [
    for (final s in _world.presentSeats)
      if (s != Seat.assistant) s,
  ];

  // ───────────────────────────────────────────────────── 주 메뉴

  Future<void> showMainMenu() async {
    if (_session.map == null) return;
    if (HDTileEventDispatcher().isScriptRunning) return;
    final choices = [
      "당신의 명령을 고르시오 ===>",
      "일행의 상황을 본다",
      "개인의 상황을 본다",
      "일행이 가진 물품을 확인",
      "일행의 건강 상태를 본다",
      "마법을 사용한다",
      "초능력을 사용한다",
      "무기 장착 및 해제",
      "여기서 쉰다",
      "물품을 사용한다",
      "게임 선택 상황",
      if (HDDevMode().enabled) "[개발] 개발자 메뉴",
    ];

    _game.beginNarrative();
    var navigated = false;
    try {
      // 메뉴가 도는 동안은 걷기와 타일 사건을 받지 않는다.
      await HDTileEventDispatcher().runExclusive(() async {
        final selected = await _game.showWindowMenu(choices, x: 200, y: 60);
        switch (selected) {
          case 1:
            await showPartyStatus();
          case 2:
            await showCharacterStatus();
          case 3:
            await showInventory();
          case 4:
            await showHealthStatus();
          case 5:
            await castMagic();
          case 6:
            await useEsp();
          case 7:
            await showEquipment();
          case 8:
            await restHere();
          case 9:
            await useItem();
          case 10:
            await selectGameOption();
          case 11:
            await HDDevJump().showDevMenu();
        }
        // 메뉴에서 한 일이 일행을 쓰러뜨렸을 수 있다 (없는 일이지만
        // 규칙이 바뀌어도 여기서 잡힌다).
        await HDFieldRules().checkGameOver();
      });
      navigated = HDScriptEngine().pendingNavigation != null;
    } on GameReloadException {
      // 불러왔거나 제목 화면으로 돌아갔다 — 메뉴를 접는다.
      navigated = true;
    } finally {
      await _game.endNarrative(autoFlush: !navigated);
    }
  }

  // ───────────────────────────────────────────────── 정보 화면

  String _yesNo(bool on) => on ? '가능' : '불가';

  Future<void> showPartyStatus() async {
    final party = _session.party;
    final w = _world;
    final c = w.calendar;
    _game.clearLogs();
    await _game.addLog("X 축 = ${party.x + 1}        마법의 횃불 : ${_yesNo(w.torch > 0)}");
    await _game.addLog("Y 축 = ${party.y + 1}        공중 부상   : ${_yesNo(w.buffs.canLevitate)}");
    await _game.addLog("남은 식량 = ${w.food}".padRight(16) + "물위를 걸음 : ${_yesNo(w.buffs.canWalkOnWater)}");
    await _game.addLog("남은 황금 = ${w.gold}".padRight(16) + "늪위를 걸음 : ${_yesNo(w.buffs.canWalkOnSwamp)}");
    await _game.addLog("남은 화살 = ${w.arrows}");
    if (w.episode == Episode.ep3) {
      // 제3부만: 네 종족의 글과 말.
      bool f(String name) => _session.gameOption.flag(name);
      await _game.addLog("");
      await _game.addLog("오크 글   : ${_yesNo(f('ORC_SCRIPT'))}    오크 말   : ${_yesNo(f('ORC_SPEECH'))}");
      await _game.addLog("트롤 글   : ${_yesNo(f('TROLL_SCRIPT'))}    트롤 말   : ${_yesNo(f('TROLL_SPEECH'))}");
      await _game.addLog("코볼트 글 : ${_yesNo(f('KOBOLD_SCRIPT'))}    코볼트 말 : ${_yesNo(f('KOBOLD_SPEECH'))}");
      await _game.addLog("드라콘 글 : ${_yesNo(f('DRACO_SCRIPT'))}    드라콘 말 : ${_yesNo(f('DRACO_SPEECH'))}");
    }
    await _game.addLog("");
    await _game.addLog("${c.year} 년 ${c.month} 월 ${c.day} 일   ${c.hour} 시 ${c.minute} 분");
    await _pause();
  }

  Future<void> showCharacterStatus() async {
    final seat = await _pickSeat("능력을 보고 싶은 인물을 선택하시오", _world.presentSeats);
    if (seat == null) return;
    final m = _world.member(seat)!;

    Future<void> head() async {
      _game.clearLogs();
      await _game.addLog("# 이름 : ${m.name}");
      await _game.addLog("# 성별 : ${genderName(m.gender)}");
      await _game.addLog("# 계급 : ${className(m)}");
      await _game.addLog("");
    }

    String pad(int v) => v.toString().padLeft(3);

    await head();
    await _game.addLog("체력   : ${pad(m.strength)}     민첩성 : ${pad(m.agility)}");
    await _game.addLog("정신력 : ${pad(m.mentality)}     정확성 : ${pad(m.accuracy)}");
    await _game.addLog("집중력 : ${pad(m.concentration)}     행운   : ${pad(m.luck)}");
    await _game.addLog("인내력 : ${pad(m.endurance)}     방어력 : ${pad(m.ac)}");
    await _game.addLog("저항력 : ${pad(m.resistance)}");
    await _game.addLog("");
    await _game.addLog("생명력 : ${m.hp} / ${m.maxHp}");
    await _game.addLog("마법 지수 : ${m.mp} / ${m.maxMp}");
    await _pause();

    await head();
    if (m.family == Family.fighter || m.family == Family.mage) {
      for (var i = 0; i < 6; i++) {
        await _game.addLog("${skillName(m, i).padRight(12)} : ${pad(m.skills[i])}");
      }
      await _game.addLog("");
    }
    await _game.addLog("## 경험치 : ${m.exp}");
    await _game.addLog("## 레벨   : ${m.level}");
    await _game.addLog("");
    await _game.addLog("사용 무기 - ${weaponNameOf(m)}");
    await _game.addLog("방패      - ${m.shield == null ? '없음' : itemName(m.shield!)}");
    await _game.addLog("갑옷      - ${m.armour == null ? '없음' : itemName(m.armour!)}");
    await _pause();
  }

  Future<void> showInventory() async {
    final w = _world;
    _game.clearLogs();
    await _game.addLog("@E일행이 가진 물품@@");
    for (final c in consumableTable) {
      await _game.addLog("${itemName(c.key).padRight(10)} : ${w.countOf(c.key)} 개");
    }
    await _pause();
    await _game.addLog("@E크리스탈@@");
    for (final c in crystalTable) {
      await _game.addLog("${itemName(c.key).padRight(12)} : ${w.countOf(c.key)} 개");
    }
    await _pause();
  }

  Future<void> showHealthStatus() async {
    _game.clearLogs();
    await _game.addLog("이름            중독  의식불명    죽음");
    await _game.addLog("");
    for (final seat in _world.presentSeats) {
      final m = _world.member(seat)!;
      await _game.addLog(
        "${m.name.padRight(12)} ${m.poison.toString().padLeft(6)} "
        "${m.unconscious.toString().padLeft(8)} ${m.dead.toString().padLeft(7)}",
      );
    }
    await _pause();
  }

  // ───────────────────────────────────────────────────── 마법

  Future<void> castMagic() async {
    final seat = await _pickSeat("누가 마법을 사용하겠습니까?", _commandSeats);
    if (seat == null) return;
    final m = _world.member(seat)!;
    _game.clearLogs();

    if (!m.canAct) {
      await _game.addLog("${josa(m.name, '은/는')} 마법을 사용할 수 있는 상태가 아닙니다.");
      await _pause();
      return;
    }
    if (!m.canUseCureMagic) {
      await _game.addLog("마법을 사용할 수 없는 계열입니다.");
      await _pause();
      return;
    }

    // 전사는 치료 마법만 쓴다.
    var school = 1;
    if (m.family == Family.mage) {
      school = await _game.showWindowMenu(["사용할 마법의 종류 ===>", "치료 마법", "변화 마법"]);
      if (school <= 0) return;
    }
    if (school == 1) {
      await _castCure(seat);
    } else {
      await _castChange(seat);
    }
  }

  Future<void> _castCure(int caster) async {
    final spells = _world.availableCureSpells(caster);
    if (spells.isEmpty) {
      await _game.addLog("아직 쓸 수 있는 치료 마법이 없습니다.");
      await _pause();
      return;
    }
    final picked = await _game.showWindowMenu([
      "치료 마법 ===>",
      for (final n in spells) spellName(spellAt(SpellSchool.cure, n)!.key),
    ]);
    if (picked <= 0) return;
    final spell = spells[picked - 1];

    int? target;
    if (spell <= 5) {
      target = await _pickSeat("누구에게?", _world.presentSeats);
      if (target == null) return;
    }
    await _report(_world.castCure(caster, spell, target: target));
    await _pause();
  }

  Future<void> _castChange(int caster) async {
    final spells = _world.availableChangeSpells(caster);
    if (spells.isEmpty) {
      await _game.addLog("아직 쓸 수 있는 변화 마법이 없습니다.");
      await _pause();
      return;
    }
    final picked = await _game.showWindowMenu([
      "변화 마법 ===>",
      for (final n in spells) spellName(spellAt(SpellSchool.change, n)!.key),
    ]);
    if (picked <= 0) return;
    final spell = spells[picked - 1];

    // 이 맵에서 막힌 마법은 쓰기 전에 걸러진다 — MP 가 줄지 않는다.
    final action = HDFieldMagic.actionOfChangeSpell(spell);
    if (action != null) {
      final blocked = HDFieldMagic().blockedHere(action);
      if (blocked != null) {
        await _game.addLog(blocked);
        await _pause();
        return;
      }
    }

    int? distance;
    if (spell == 8) {
      distance = await _askTeleportDistance();
      if (distance == null) return;
    }
    final outcome = _world.castChange(caster, spell, distance: distance);
    await _report(outcome);
    final needed = outcome.mapAction;
    if (needed != null) await HDFieldMagic().perform(needed);
    if (HDScriptEngine().pendingNavigation == null) await _pause();
  }

  /// 공간 이동의 칸 수 1~9. 기본 5.
  Future<int?> _askTeleportDistance() async {
    final picked = await _game.showWindowMenu([
      "몇 칸을 이동하겠습니까?",
      for (var n = teleportMin; n <= teleportMax; n++) "$n 칸",
    ], initialChoice: teleportDefault - teleportMin + 1);
    return picked <= 0 ? null : picked + teleportMin - 1;
  }

  // ─────────────────────────────────────────────────── 초능력

  Future<void> useEsp() async {
    final seat = await _pickSeat("누가 초능력을 사용하겠습니까?", _commandSeats);
    if (seat == null) return;
    _game.clearLogs();

    const powers = [
      FieldEsp.clairvoyance,
      FieldEsp.prophecy,
      FieldEsp.mindReading,
      FieldEsp.farSight,
      FieldEsp.telekinesis,
    ];
    final picked = await _game.showWindowMenu([
      "사용할 초능력 ===>",
      for (final p in powers) spellName(fieldEspKey(p)),
    ]);
    if (picked <= 0) return;
    final power = powers[picked - 1];

    final action = switch (power) {
      FieldEsp.clairvoyance => MapAction.revealHidden,
      FieldEsp.farSight => MapAction.farSight,
      _ => null,
    };
    if (action != null) {
      final blocked = HDFieldMagic().blockedHere(action);
      if (blocked != null) {
        await _game.addLog(blocked);
        await _pause();
        return;
      }
    }

    final outcome = _world.castFieldEsp(seat, power);
    await _report(outcome);
    final needed = outcome.mapAction;
    if (needed != null) await HDFieldMagic().perform(needed);
    if (HDScriptEngine().pendingNavigation == null) await _pause();
  }

  // ───────────────────────────────────────────────────── 장비

  Future<void> showEquipment() async {
    final seat = await _pickSeat("누구의 장비입니까?", _commandSeats);
    if (seat == null) return;

    const slots = [EquipSlot.weapon, EquipSlot.shield, EquipSlot.armour];
    const slotNames = ['무기', '방패', '갑옷'];
    while (true) {
      final m = _world.member(seat);
      if (m == null) return;
      final worn = [m.weapon, m.shield, m.armour];
      final part = await _game.showWindowMenu([
        "${m.name} — 어느 것을 바꾸겠습니까?",
        for (var i = 0; i < 3; i++)
          "${slotNames[i]} - ${worn[i] == null ? '없음' : itemName(worn[i]!)}",
      ]);
      if (part <= 0) return;
      final slot = slots[part - 1];
      final current = worn[part - 1];

      // 이미 찬 자리는 먼저 풀어야 한다.
      if (current != null) {
        final act = await _game.showWindowMenu([
          itemName(current),
          "해제한다",
        ]);
        if (act == 1) await _reportQuietly(_world.unequip(seat, slot));
        continue;
      }

      final candidates = [
        for (final key in _world.backpack.keys)
          if (equipSlotOf(key) == slot && _world.countOf(key) > 0) key,
      ];
      if (candidates.isEmpty) {
        await _game.showMessageWindow(
          "${josa(m.name, '은/는')} 가진 것이 아무것도 없다.",
        );
        continue;
      }
      final picked = await _game.showWindowMenu([
        "무엇을 장착하겠습니까?",
        for (final key in candidates)
          "${itemName(key)}  x${_world.countOf(key)}"
              "${_world.checkEquip(seat, key) == null ? '' : '  (불가)'}",
      ]);
      if (picked <= 0) continue;
      await _reportQuietly(_world.equip(seat, candidates[picked - 1]));
    }
  }

  /// 장비 화면은 창 위에서 돈다 — 거절만 창으로 알리고 성공은 조용히 반영한다.
  Future<void> _reportQuietly(Outcome outcome) async {
    if (outcome.isRefused) {
      await _game.showMessageWindow(refusalLine(outcome.refusal!));
    }
    _changed();
  }

  // ───────────────────────────────────────────────────── 휴식

  Future<void> restHere() async {
    final picked = await _game.showWindowMenu([
      "일행이 여기서 쉴 시간을 지정하십시오.",
      for (var h = 1; h <= 24; h++) "$h 시간",
    ], initialChoice: _world.options.restHours.clamp(1, 24));
    if (picked <= 0) return;

    _game.clearLogs();
    await HDFieldRules().rest(picked);
    await _pause();
    // 쉬는 동안 예약한 시각에 닿았으면 그 사건이 이어진다.
    await HDFieldRules().checkTimer();
  }

  // ─────────────────────────────────────────────────── 물품 사용

  Future<void> useItem() async {
    final kind = await _game.showWindowMenu([
      "물품을 사용한다 ===>",
      "약초나 약물을 사용한다",
      "크리스탈을 사용한다",
    ]);
    if (kind <= 0) return;
    _game.clearLogs();
    if (kind == 1) {
      await _useConsumable();
    } else {
      await _useCrystal();
    }
  }

  Future<void> _useConsumable() async {
    final user = await _pickSeat("누가 사용하겠습니까?", [
      for (final s in _commandSeats)
        if (_world.member(s)!.canAct) s,
    ]);
    if (user == null) return;

    final picked = await _game.showWindowMenu([
      "사용할 물품 ===>",
      for (final c in consumableTable)
        "${itemName(c.key)}  x${_world.countOf(c.key)}",
    ]);
    if (picked <= 0) return;
    final key = consumableTable[picked - 1].key;

    int? target;
    if (key == ItemKey.awakeningHerb || key == ItemKey.revivalHerb) {
      target = await _pickSeat("누구에게?", _world.presentSeats);
      if (target == null) return;
    }

    // 지도가 있어야 끝나는 물품은 이 맵에서 통하는지 먼저 본다 — 쓰면 사라진다.
    final action = switch (key) {
      ItemKey.seeingOrb => MapAction.showMap,
      ItemKey.warpOrb => MapAction.teleport,
      _ => null,
    };
    if (action != null && _world.countOf(key) > 0) {
      final blocked = HDFieldMagic().blockedHere(action);
      if (blocked != null) {
        await _game.addLog(blocked);
        await _pause();
        return;
      }
    }
    var distance = teleportDefault;
    if (key == ItemKey.warpOrb && _world.countOf(key) > 0) {
      final d = await _askTeleportDistance();
      if (d == null) return;
      distance = d;
    }

    // 효과가 없을 때는 한 번 묻는다 (기획서의 권고 — 원작은 그냥 사라졌다).
    if (_world.countOf(key) > 0 &&
        _world.consumableWouldBeWasted(key, user: user, target: target) !=
            null) {
      final sure = await _game.showWindowMenu([
        "지금 써도 효과가 없습니다. 그래도 쓰겠습니까?",
        "쓰지 않는다",
        "쓴다",
      ]);
      if (sure != 2) return;
    }

    final outcome = _world.useConsumable(
      key,
      user: user,
      target: target,
      distance: distance,
      rng: HDFieldRules().rng,
    );
    await _report(outcome);
    final needed = outcome.mapAction;
    if (needed != null) await HDFieldMagic().perform(needed);
    await _pause();
  }

  Future<void> _useCrystal() async {
    final usable = [
      for (final c in crystalTable)
        if (c.field) c.key,
    ];
    final picked = await _game.showWindowMenu([
      "사용할 크리스탈 ===>",
      for (final key in usable) "${itemName(key)}  x${_world.countOf(key)}",
    ]);
    if (picked <= 0) return;
    final key = usable[picked - 1];

    final outcome = _world.useCrystal(key, rng: HDFieldRules().rng);
    await _report(outcome);

    // 이야기가 정하는 크리스탈: 이 맵의 스크립트가 답한다. 아무도 답하지
    // 않으면 반응이 없는 것이다.
    // 크리스탈 볼은 주위가 트인 곳(필드)에서만 작동한다 — 원작은 맵 스크립트에
    // 묻기 전에 맵 유형을 본다 (MYST_1995_src/MYSTMENU.PAS:2068~2072).
    if (outcome.has<StoryCrystalUsed>() &&
        key == CrystalKey.ball &&
        _session.mapKind != MapKind.field) {
      await _game.addLog("크리스탈 볼은 주위가 트인 곳에서만 작동합니다.");
    } else if (outcome.has<StoryCrystalUsed>()) {
      final engine = HDScriptEngine()..usedItemKey = key;
      final before = _session.gameOption.toJson().toString();
      if (_session.currentMapCm2Path != null) {
        await engine.runMapMode(HDScriptMode.item);
      }
      engine.usedItemKey = '';
      final reacted = engine.pendingNavigation != null ||
          engine.handled ||
          before != _session.gameOption.toJson().toString();
      if (!reacted) {
        await _game.addLog("크리스탈에는 아무런 반응이 없었다.");
      }
    }
    if (HDScriptEngine().pendingNavigation == null) await _pause();
  }

  // ──────────────────────────────────────────────── 게임 선택 상황

  Future<void> selectGameOption() async {
    final selected = await _game.showWindowMenu([
      "게임 선택 상황",
      "난이도 조절",
      "정식 일행의 순서 정렬",
      "일행에서 제외시킴",
      "일행의 장비를 버림",
      "이전의 게임을 재개",
      "현재의 게임을 저장",
      "게임을 마침",
    ]);
    switch (selected) {
      case 1:
        await selectDifficulty();
      case 2:
        await _sortParty();
      case 3:
        await _dismissPartyMember();
      case 4:
        await _discardEquipment();
      case 5:
        if (await selectLoadMenu()) throw GameReloadException();
      case 6:
        await selectSaveMenu();
      case 7:
        await processGameOver(0);
    }
  }

  Future<void> selectDifficulty() async {
    final o = _world.options;
    final most = await _game.showWindowMenu([
      "한 번에 출현하는 적들의 최대치를 기입하십시오",
      for (var n = 3; n <= 8; n++) "$n명의 적들",
    ], initialChoice: o.maxEnemies.clamp(3, 8) - 2);
    if (most <= 0) return;
    o.maxEnemies = most + 2;

    // 화면의 순서는 「피하고 싶다」가 위 — 전투 성향 5 가 가장 드물다.
    final mood = await _game.showWindowMenu([
      "일행들의 지금 성격은 어떻습니까?",
      "일부러 전투를 피하고 싶다",
      "너무 잦은 전투는 원하지 않는다",
      "마주친 적과는 전투를 하겠다",
      "보이는 적들과는 모두 전투하겠다",
      "그들은 피에 굶주려 있다",
    ], initialChoice: 6 - o.encounterTendency.clamp(1, 5));
    if (mood <= 0) return;
    o.encounterTendency = 6 - mood;

    final finish = await _game.showWindowMenu([
      "의식 불명인 적까지 공격하겠습니까?",
      "물론 그렇다",
      "그렇지 않다",
    ], initialChoice: o.attackUnconscious ? 1 : 2);
    if (finish <= 0) return;
    o.attackUnconscious = finish == 1;
  }

  Future<void> _sortParty() async {
    final seats = [
      for (final s in _commandSeats)
        if (s != Seat.protagonist) s,
    ];
    if (seats.length < 2) {
      await _game.addLog("순서를 바꿀 수 있을 만한 인원수가 아닙니다.");
      await _pause();
      return;
    }
    final a = await _pickSeat("누구의 순서를 바꾸겠습니까?", seats);
    if (a == null) return;
    final b = await _pickSeat("누구와 자리를 교환하겠습니까?", seats);
    if (b == null || b == a) return;
    await _report(_world.swapSeats(a, b));
  }

  Future<void> _dismissPartyMember() async {
    final seats = [
      for (final s in _world.presentSeats)
        if (s != Seat.protagonist) s,
    ];
    if (seats.isEmpty) {
      await _game.addLog("더 이상 일행을 제외시킬 수 없습니다.");
      await _pause();
      return;
    }
    final seat = await _pickSeat("누구를 일행에서 제외시키겠습니까?", seats);
    if (seat == null) return;
    final name = _world.member(seat)!.name;
    final sure = await _game.showWindowMenu([
      "${josa(name, '은/는')} 다시 돌아오지 않습니다. 정말 내보내겠습니까?",
      "아니오",
      "예",
    ]);
    if (sure != 2) return;
    await _report(_world.dismiss(seat));
    await _pause();
  }

  Future<void> _discardEquipment() async {
    final seat = await _pickSeat("누구의 장비를 버리겠습니까?", _commandSeats);
    if (seat == null) return;
    final m = _world.member(seat)!;
    const slots = [EquipSlot.weapon, EquipSlot.shield, EquipSlot.armour];
    final worn = [m.weapon, m.shield, m.armour];
    final picked = await _game.showWindowMenu([
      "무엇을 버리겠습니까?",
      for (final key in worn) key == null ? '(없음)' : itemName(key),
    ]);
    if (picked <= 0 || worn[picked - 1] == null) return;
    await _report(_world.discardEquipped(seat, slots[picked - 1]));
    await _pause();
  }

  // ─────────────────────────────────────────────── 저장 · 불러오기

  static const List<String> _slotNames = [
    "본 게임 데이타",
    "게임 데이타 1 (부)",
    "게임 데이타 2 (부)",
    "게임 데이타 3 (부)",
  ];

  Future<List<String>> _slotLabels() async {
    final labels = <String>[];
    for (var i = 0; i < HDSaveManager.slotCount; i++) {
      final s = await HDSaveManager.summary(i);
      labels.add(
        s == null
            ? "${_slotNames[i]} — 비어 있음"
            : "${_slotNames[i]} — 제${s.episode}부 ${s.name} · ${s.mapTitle}",
      );
    }
    return labels;
  }

  /// 불러올 칸을 고르고 불러온다. 불러왔으면 true — 부른 쪽이
  /// `GameReloadException` 으로 돌던 스크립트를 접는다.
  Future<bool> selectLoadMenu() async {
    final selected = await _game.showWindowMenu([
      "불러 내고 싶은 게임을 선택하십시오.",
      ...await _slotLabels(),
    ]);
    if (selected <= 0) return false;

    await _game.addLog("저장했던 게임을 다시 불러옵니다");
    if (await HDSaveManager.loadGame(selected - 1)) {
      _session.sessionId++;
      _game.clearLogs();
      return true;
    }
    await _game.addLog("저장된 데이타가 없습니다!");
    await _pause();
    return false;
  }

  Future<bool> selectSaveMenu() async {
    final selected = await _game.showWindowMenu([
      "게임의 저장 장소를 선택하십시오.",
      ...await _slotLabels(),
    ]);
    if (selected <= 0) return false;

    await _game.addLog("현재의 게임을 저장합니다");
    final ok = await HDSaveManager.saveGame(selected - 1);
    await _game.addLog(ok ? "성공했습니다" : "저장하지 못했습니다.");
    await _pause();
    return ok;
  }

  // ─────────────────────────────────────────────────── 게임 오버

  /// [exitCode] — 0 플레이어가 끝내기를 골랐다 · 1 필드에서 전멸 ·
  /// 2 전투에서 패배 (원작 `EXITCODE_*`).
  ///
  /// 불러오기를 고르면 `GameReloadException` 을 던져 돌던 스크립트를 접고,
  /// 아니면 제목 화면으로 돌아간다. **프로그램을 끝내지 않는다** — 웹과
  /// 휴대폰에서는 「끝낸다」가 없다.
  Future<void> processGameOver(int exitCode) async {
    if (exitCode == 0) {
      final res = await _game.showWindowMenu([
        "정말로 끝내겠습니까?",
        "<< 아니오 >>",
        "<<   예   >>",
      ]);
      if (res != 2) return;
      await HDTitleFlow().returnToTitle(farewell: true);
      throw GameReloadException();
    }

    _game.clearLogs();
    await _game.addLog(
      exitCode == 2 ? "@C일행은 모두 전투에서 패했다!!@@" : "@C일행은 모험 중에 모두 목숨을 잃었다.@@",
    );
    await _game.waitForAnyKey();

    final res = await _game.showWindowMenu([
      "어떻게 하시겠습니까?",
      "이전의 게임을 재개한다",
      "게임을 끝낸다",
    ]);
    if (res == 1 && await selectLoadMenu()) throw GameReloadException();
    await HDTitleFlow().returnToTitle();
    throw GameReloadException();
  }
}
