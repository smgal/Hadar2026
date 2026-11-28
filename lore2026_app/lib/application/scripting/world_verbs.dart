import 'package:cm2_script/cm2_script.dart';
import 'package:flutter/foundation.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart' as wt;

import '../battle_bridge/cm2_battle_adapter.dart';
import '../facilities.dart';
import '../field_rules.dart';
import '../game_session.dart';
import '../menu_flows.dart';
import '../ports/host_binding.dart';
import '../select.dart';
import '../title_flow.dart';
import 'script_engine_adapter.dart';

/// 일행 · 물건 · 시간 · 가게 · 전투 · 게임 흐름 동사.
///
/// 글 · 고르기 · 진행 상태 · 맵 동사는 `script_engine_adapter.dart` 에 있다.
/// 여기는 **규칙을 가진 세계**(`packages/lore_world`, `packages/lore_battle`)
/// 를 만지는 쪽이라 따로 뒀다 — 규칙은 그 패키지들이 정하고, 이 파일은
/// 스크립트의 낱말을 그 명령으로 옮기기만 한다.
void registerWorldVerbs(ScriptEngine e, HDScriptEngine host) {
  LoreWorld world() => HDGameSession().party.world;
  void changed() {
    HDGameSession().party.notifyListeners();
    HDHosts().ui.refresh();
  }

  String str(ScriptEngine eng, List<String> a, int i) =>
      HDScriptEngine.str(eng, a, i);
  int integer(
    ScriptEngine eng,
    List<String> a,
    int i, {
    int fallback = 0,
    String symbol = '',
  }) => HDScriptEngine.integer(eng, a, i, fallback: fallback, symbol: symbol);

  /// 스크립트의 대원 번호(1~6) → 자리(0~5). 범위 밖이면 알리고 null.
  int? seatArg(int n, String symbol) {
    if (n < 1 || n > Seat.count) {
      debugPrint('[cm2] $symbol: 대원 번호 $n 은 1~${Seat.count} 밖이다 — 무시했다');
      return null;
    }
    return n - 1;
  }

  Member? memberArg(int n, String symbol) {
    final seat = seatArg(n, symbol);
    if (seat == null) return null;
    final m = world().member(seat);
    if (m == null) debugPrint('[cm2] $symbol: $n번 자리는 비어 있다');
    return m;
  }

  // ---- 일행 ----

  e.registerCommand('Party::Join', (stmt, eng) async {
    final key = str(eng, stmt.args, 0);
    host.lastJoinSucceeded = false;
    host.lastJoinSeat = 0;
    final entry = rosterOf(world().episode)[key];
    if (entry == null) {
      debugPrint('[cm2] Party::Join("$key") — 이 편의 동료 표에 없는 키다');
      return;
    }
    final seat = world().firstFreeCompanionSeat;
    final outcome = world().join(entry.build());
    host.lastJoinSucceeded = outcome.ok;
    host.lastJoinSeat = outcome.ok && seat != null ? seat + 1 : 0;
    changed();
  });

  // 제1부의 「합류 교체」(1st/04 §4.3). 2~5번에 빈자리가 있으면 거기 앉히고,
  // 없으면 「교체 시킬 인물은 누구입니까?」 — 2~6번 중 하나를 고른다.
  // 6번이 비었으면 그 줄은 「보조 일원으로 둠」. 바뀐 사람은 영영 떠난다.
  // 취소하면 아무도 앉지 않는다 — `Party::Joined()` 가 0.
  e.registerCommand('Party::JoinReplace', (stmt, eng) async {
    final key = str(eng, stmt.args, 0);
    host.lastJoinSucceeded = false;
    host.lastJoinSeat = 0;
    final w = world();
    final entry = rosterOf(w.episode)[key];
    if (entry == null) {
      debugPrint('[cm2] Party::JoinReplace("$key") — 이 편의 동료 표에 없는 키다');
      return;
    }
    final free = w.firstFreeCompanionSeat;
    if (free != null) {
      host.lastJoinSucceeded = w.join(entry.build()).ok;
      if (host.lastJoinSucceeded) host.lastJoinSeat = free + 1;
      changed();
      return;
    }
    final choices = <int>[];
    final select = HDSelect()
      ..init()
      ..add('교체 시킬 인물은 누구입니까?');
    for (var seat = 1; seat < Seat.count; seat++) {
      final m = w.member(seat);
      if (m != null) {
        select.add(wt.memberName(m, episode: w.episode));
      } else if (seat == Seat.assistant) {
        select.add('보조 일원으로 둠');
      } else {
        continue;
      }
      choices.add(seat);
    }
    await select.run();
    final picked = select.result();
    if (picked < 1 || picked > choices.length) return;
    host.lastJoinSucceeded = w.replace(choices[picked - 1], entry.build()).ok;
    if (host.lastJoinSucceeded) host.lastJoinSeat = choices[picked - 1] + 1;
    changed();
  });

  // `Party::ArmBareHanded("weapon.dagger")` — 무기를 들지 않은 1~5번 각자에게
  // 그 무기를 하나씩 쥐여 준다(제1부 로어성 무기고, 1st/05 M1). 쓸 수 없는
  // 계급(무기를 쓰지 않는 전투승 등)은 장비 규칙이 거절하므로 건너뛴다.
  // `Party::ArmBareHanded("weapon.dagger")` — 맨손인 대원에게 그 무기를 쥐여 준다(쓸 수 없는 계급은 건너뛴다 —
  // 전투승은 원작에서도 받지 않는다). 둘째 값 "fighter" 면 전투사 계열만 받는다(2부 무기고, DARKSPEC.PAS:1197~1203).
  e.registerCommand('Party::ArmBareHanded', (stmt, eng) async {
    final key = str(eng, stmt.args, 0);
    final fightersOnly =
        stmt.args.length > 1 && str(eng, stmt.args, 1) == 'fighter';
    final w = world();
    for (var seat = 0; seat < Seat.assistant; seat++) {
      final m = w.member(seat);
      if (m == null) continue;
      if (fightersOnly && m.family != Family.fighter) continue;
      if (w.equippedIn(seat, EquipSlot.weapon) != null) continue;
      w.give(key);
      if (w.equip(seat, key).isRefused) w.take(key);
    }
    changed();
  });

  // `Shop::StatTraining("mentality", 30)` — 제2부 고대 유적의 석상이 황금을 받고 1~5번 중 한 명의
  // 능력치를 1 올린다 (2nd/09 §9.3). 값은 「올릴 수치 n 번째」(정확성은 n+1 번째) — 29번째는 원작 표의
  // 오타 350,000 대신 3,500,000 (부록 A #26).
  e.registerCommand('Shop::StatTraining', (stmt, eng) async {
    const prices = [
      30, 60, 125, 250, 500, 1000, 2000, 3000, 4000, 6000,
      8000, 12000, 16000, 24000, 32000, 64000, 96000, 128000, 192000, 256000,
      384000, 512000, 770000, 1000000, 1500000, 2000000, 2500000, 3000000, 3500000, 4000000,
    ];
    const labels = {
      'mentality': '정신력',
      'endurance': '인내력',
      'strength': '체력',
      'agility': '민첩성',
      'accuracy': '정확성',
    };
    final attr = str(eng, stmt.args, 0);
    final max = integer(eng, stmt.args, 1, fallback: 20, symbol: 'Shop::StatTraining');
    final label = labels[attr] ?? attr;
    final ui = HDHosts().ui;
    final w = world();
    await ui.addLog(
      '@B석상@@ : 당신은 나의 문제를 모두 맞추었소. 그 보답으로, 당신이 황금을 나에게 바친다면 '
      '당신들 중의 한 사람의 ${wt.josa(label, '을/를')} 한 단계 올려 주겠소.',
    );
    final seats = <int>[];
    final select = HDSelect()
      ..init()
      ..add('누구의 ${wt.josa(label, '을/를')} 올리겠습니까?');
    for (var seat = 0; seat < Seat.assistant; seat++) {
      final m = w.member(seat);
      if (m == null) continue;
      select.add(wt.memberName(m, episode: w.episode));
      seats.add(seat);
    }
    await select.run();
    final picked = select.result();
    if (picked < 1 || picked > seats.length) return;
    final m = w.member(seats[picked - 1])!;
    final name = wt.memberName(m, episode: w.episode);
    final cur = readAttribute(m, attr) ?? 0;
    if (cur >= max) {
      await ui.addLog('@B석상@@ : ${wt.josa(name, '은/는')} 지금 최고의 $label 수치입니다.');
      return;
    }
    final index = (attr == 'accuracy' ? cur + 2 : cur + 1).clamp(1, prices.length);
    final price = prices[index - 1];
    if (w.gold < price) {
      await ui.addLog('@B석상@@ : 일행은 $price개의 황금이 필요합니다.');
      return;
    }
    w.addGold(-price);
    writeAttribute(m, attr, cur + 1);
    await ui.addLog('$name의 ${wt.josa(label, '은/는')} 이제 ${cur + 1}입니다.');
    changed();
  });

  // `Party::StripEquipment()` — 1~5번 대원이 장착한 것을 모두 잃는다 (제2부 은행에서 항복할 때).
  e.registerCommand('Party::StripEquipment', (_, _) async {
    final w = world();
    for (var seat = 0; seat < Seat.assistant; seat++) {
      if (w.member(seat) == null) continue;
      for (final slot in EquipSlot.values) {
        if (w.equippedIn(seat, slot) != null) w.discardEquipped(seat, slot);
      }
    }
    changed();
  });

  // `Party::ReviveFallen()` — 쓰러진 대원(의식불명·죽음)을 HP 1 로 일으킨다.
  // 제2부의 이벤트 패배 전투에서 레드 안타레스가 구해 줄 때 (2nd/07 §7.2).
  // 제1부 리겔의 「신의 축복」 — 무기를 든 대원마다 행운 판정 두 번, 둘 다
  // 통과하면 그 무기의 공격력 ×1.2 (1st/05 S8). 원작처럼 누가 받았는지는 말하지
  // 않는다 — 스크립트의 문장 하나가 전부다.
  e.registerCommand('Party::BlessWeapons', (_, _) async {
    world().blessWeapons(rng: HDFieldRules().rng);
    changed();
  });

  e.registerCommand('Party::ReviveFallen', (_, _) async {
    for (final m in world().presentMembers) {
      if (m.canAct) continue;
      m.dead = 0;
      m.unconscious = 0;
      if (m.hp < 1) m.hp = 1;
    }
    changed();
  });

  // 제1부: 던전 오브 이블에서 일행 전원이 반신반인이 된다 (1st/07 §7.4).
  e.registerCommand('Party::PromoteDemigod', (_, _) async {
    world().promoteAllToDemigod();
    changed();
  });

  // 제1부의 해금 (1st/07 §7.4). "special_magic" — 레드 안타레스의 「간접 공격」,
  // "esp" — 스피카를 만나기 전에는 초자연력 기술치를 올릴 수 없다.
  e.registerCommand('Party::Unlock', (stmt, eng) async {
    final what = str(eng, stmt.args, 0);
    switch (what) {
      case 'special_magic':
        world().specialMagicUnlocked = true;
      case 'esp':
        world().espTrainingUnlocked = true;
      default:
        debugPrint('[cm2] Party::Unlock("$what") — special_magic · esp 만 안다');
    }
    changed();
  });

  e.registerCommand('Party::Dismiss', (stmt, eng) async {
    final seat = seatArg(integer(eng, stmt.args, 0), 'Party::Dismiss');
    if (seat == null) return;
    final outcome = world().dismiss(seat);
    if (outcome.isRefused) {
      debugPrint('[cm2] Party::Dismiss — ${outcome.reason?.name}');
    }
    changed();
  });

  // `Party::SetAssistant("draco_prisoner")` — 동료 표의 보조 일원.
  // `Party::SetAssistant("enemy", 15)` — 그 편 적 표의 적을 보조 일원으로.
  e.registerCommand('Party::SetAssistant', (stmt, eng) async {
    final key = str(eng, stmt.args, 0);
    Member? newcomer;
    if (key == 'enemy') {
      newcomer = HDCm2BattleAdapter().assistantFromEnemy(
        integer(eng, stmt.args, 1, symbol: 'Party::SetAssistant'),
      );
    } else {
      newcomer = rosterOf(world().episode)[key]?.build();
    }
    if (newcomer == null) {
      debugPrint('[cm2] Party::SetAssistant("$key") — 그런 보조 일원이 없다');
      return;
    }
    world().setAssistant(newcomer);
    changed();
  });

  e.registerCommand('Party::RemoveAssistant', (_, _) async {
    world().removeAssistant();
    changed();
  });

  e.registerCommand('Party::HideCompanions', (_, _) async {
    world().hideCompanions();
    changed();
  });
  e.registerCommand('Party::RestoreCompanions', (_, _) async {
    world().restoreCompanions();
    changed();
  });

  e.registerCommand('Party::PlusGold', (stmt, eng) async {
    world().addGold(integer(eng, stmt.args, 0, symbol: 'Party::PlusGold'));
    changed();
  });
  e.registerCommand('Party::PlusFood', (stmt, eng) async {
    world().addFood(integer(eng, stmt.args, 0, symbol: 'Party::PlusFood'));
    changed();
  });
  e.registerCommand('Party::PlusArrows', (stmt, eng) async {
    world().addArrows(integer(eng, stmt.args, 0, symbol: 'Party::PlusArrows'));
    changed();
  });

  e.registerCommand('Party::GiveExp', (stmt, eng) async {
    world().grantExp(integer(eng, stmt.args, 0, symbol: 'Party::GiveExp'));
    changed();
  });

  // 전원 완전 회복 — 이야기가 주는 치료(구출 · 축복). 깊은 것부터 푼다.
  e.registerCommand('Party::HealAll', (_, _) async {
    for (final m in world().presentMembers) {
      m
        ..dead = 0
        ..unconscious = 0
        ..poison = 0
        ..hp = m.maxHp
        ..mp = m.maxMp;
    }
    changed();
  });

  // 쉰 것으로 처리한다. 문장 없이 — 사건이 시간을 보내는 자리다
  // (오크 비석 앞에서 쓰러졌다 깨어나는 식). 메뉴의 「여기서 쉰다」는
  // HDMenuFlows.restHere 가 맡는다.
  e.registerCommand('Party::Rest', (stmt, eng) async {
    await HDFieldRules().rest(
      integer(eng, stmt.args, 0, fallback: 1, symbol: 'Party::Rest'),
      silent: true,
    );
  });

  e.registerCommand('Party::SetTorch', (stmt, eng) async {
    world().setTorch(integer(eng, stmt.args, 0, symbol: 'Party::SetTorch'));
    changed();
  });

  e.registerCommand('Party::SetBuff', (stmt, eng) async {
    final which = integer(eng, stmt.args, 0, symbol: 'Party::SetBuff');
    final value = integer(eng, stmt.args, 1, symbol: 'Party::SetBuff');
    final w = world();
    switch (which) {
      case 0: // CHECKIF_MAGICTORCH
        w.setTorch(value);
      case 1: // CHECKIF_LEVITATION
        w.buffs.levitation = value.clamp(0, FieldBuffs.full);
      case 2: // CHECKIF_WALKONWATER
        w.buffs.waterWalk = value.clamp(0, FieldBuffs.full);
      case 3: // CHECKIF_WALKONSWAMP
        w.buffs.swampWalk = value.clamp(0, FieldBuffs.full);
      case 4: // CHECKIF_MINDCONTROL
        w.buffs.mindReadSteps = value.clamp(0, FieldBuffs.mindReadDuration);
      default:
        debugPrint('[cm2] Party::SetBuff($which) — CHECKIF_* 상수를 쓴다');
    }
    changed();
  });

  // ---- 대원 ----

  e.registerCommand('Player::ChangeAttribute', (stmt, eng) async {
    final m = memberArg(
      integer(eng, stmt.args, 0),
      'Player::ChangeAttribute',
    );
    if (m == null) return;
    final attr = str(eng, stmt.args, 1);
    if (attr == 'name') {
      m.name = str(eng, stmt.args, 2);
    } else if (!writeAttribute(m, attr, integer(eng, stmt.args, 2))) {
      debugPrint('[cm2] Player::ChangeAttribute("$attr") — 쓸 수 없는 속성이다');
    }
    changed();
  });

  // `Player::AddAttribute(n, "agility", 1, 20)` — 상한이 있으면 넘지 않는다.
  e.registerCommand('Player::AddAttribute', (stmt, eng) async {
    final m = memberArg(integer(eng, stmt.args, 0), 'Player::AddAttribute');
    if (m == null) return;
    final attr = str(eng, stmt.args, 1);
    final current = readAttribute(m, attr);
    if (current == null) {
      debugPrint('[cm2] Player::AddAttribute("$attr") — 그런 속성이 없다');
      return;
    }
    var next = current + integer(eng, stmt.args, 2);
    if (stmt.args.length > 3) {
      final cap = integer(eng, stmt.args, 3);
      // 이미 상한을 넘어 있으면 깎지 않는다 — 이벤트로 20 을 넘긴 능력치를
      // 다음 이벤트가 되돌리면 안 된다.
      if (next > cap) next = current > cap ? current : cap;
    }
    writeAttribute(m, attr, next);
    changed();
  });

  // ---- 물건 ----

  e.registerCommand('Item::Give', (stmt, eng) async {
    final key = str(eng, stmt.args, 0);
    final count = stmt.args.length > 1 ? integer(eng, stmt.args, 1) : 1;
    if (world().limitOf(key) == null) {
      debugPrint('[cm2] Item::Give("$key") — 모르는 물건 키다. 무시했다');
      return;
    }
    world().give(key, count);
    changed();
  });

  e.registerCommand('Item::Take', (stmt, eng) async {
    final key = str(eng, stmt.args, 0);
    final count = stmt.args.length > 1 ? integer(eng, stmt.args, 1) : 1;
    if (!world().take(key, count)) {
      debugPrint('[cm2] Item::Take("$key", $count) — 그만큼 갖고 있지 않다');
    }
    changed();
  });

  // ---- 시간 ----

  e.registerCommand('Time::Pass', (stmt, eng) async {
    world().calendar.advance(
      hours: integer(eng, stmt.args, 0, symbol: 'Time::Pass'),
      minutes: stmt.args.length > 1 ? integer(eng, stmt.args, 1) : 0,
    );
    changed();
  });

  e.registerCommand('Time::Set', (stmt, eng) async {
    world().calendar
      ..year = integer(eng, stmt.args, 0, symbol: 'Time::Set')
      ..month = integer(eng, stmt.args, 1, fallback: 1).clamp(1, 12)
      ..day = integer(eng, stmt.args, 2, fallback: 1).clamp(1, 30)
      ..hour = integer(eng, stmt.args, 3).clamp(0, 23)
      ..minute = integer(eng, stmt.args, 4).clamp(0, 59)
      ..second = 0;
    changed();
  });

  // ---- 가게와 시설 ----

  e.registerCommand('Shop::Grocery', (_, _) => HDFacilities().grocery());
  e.registerCommand('Shop::Weapon', (_, _) => HDFacilities().weaponShop());
  e.registerCommand('Shop::Herb', (_, _) => HDFacilities().herbShop());
  e.registerCommand('Shop::Goods', (_, _) => HDFacilities().goodsShop());
  e.registerCommand('Shop::Hospital', (_, _) => HDFacilities().hospital());
  e.registerCommand('Shop::Training', (_, _) => HDFacilities().training());
  e.registerCommand(
    'Shop::ExpTraining',
    (_, _) => HDFacilities().expTraining(),
  );

  // ---- 전투 ----

  e.registerCommand('Battle::Init', (_, _) async => HDCm2BattleAdapter().init());

  e.registerCommand('Battle::RegisterEnemy', (stmt, eng) async {
    final no = integer(eng, stmt.args, 0, symbol: 'Battle::RegisterEnemy');
    final count = stmt.args.length > 1 ? integer(eng, stmt.args, 1) : 1;
    for (var i = 0; i < count; i++) {
      HDCm2BattleAdapter().registerEnemy(no);
    }
  });

  // `Battle::RegisterVariant("major_mummy", 1)` — 이름·수치를 바꾼 보스(변형).
  e.registerCommand('Battle::RegisterVariant', (stmt, eng) async {
    final key = str(eng, stmt.args, 0);
    final count = stmt.args.length > 1 ? integer(eng, stmt.args, 1) : 1;
    for (var i = 0; i < count; i++) {
      HDCm2BattleAdapter().registerVariant(key);
    }
  });

  // `Battle::RegisterPartyClones(70, 60)` — 일행 여섯의 분신(바탕 적 70), 빈자리는 60.
  e.registerCommand('Battle::RegisterPartyClones', (stmt, eng) async {
    HDCm2BattleAdapter().registerPartyClones(
      integer(eng, stmt.args, 0, symbol: 'Battle::RegisterPartyClones'),
      integer(eng, stmt.args, 1, symbol: 'Battle::RegisterPartyClones'),
    );
  });

  // `Battle::SetRepeatText("...")` — BATTLE_REPEAT 전투에서 도망친 뒤 다시 붙을 때의 문장.
  e.registerCommand('Battle::SetRepeatText', (stmt, eng) async {
    HDCm2BattleAdapter().repeatText = host.expand(str(eng, stmt.args, 0));
  });

  // `Battle::SetRenewText("...")` — BATTLE_RENEW 전투에서 이긴 뒤 새 편성이 덤벼 오기 전의 문장.
  e.registerCommand('Battle::SetRenewText', (stmt, eng) async {
    HDCm2BattleAdapter().renewText = host.expand(str(eng, stmt.args, 0));
  });

  e.registerCommand('Enemy::ChangeAttribute', (stmt, eng) async {
    final index = integer(eng, stmt.args, 0, symbol: 'Enemy::ChangeAttribute');
    final attr = str(eng, stmt.args, 1);
    final ok = attr == 'name'
        ? HDCm2BattleAdapter().renameEnemy(index, host.expand(str(eng, stmt.args, 2)))
        : HDCm2BattleAdapter().overrideEnemy(index, attr, integer(eng, stmt.args, 2));
    if (!ok) {
      debugPrint(
        '[cm2] Enemy::ChangeAttribute($index, "$attr") — 등록된 적이 아니거나 '
        '모르는 속성이다',
      );
    }
  });

  // `Battle::ShowEnemyNames()` — 등록한 적을 싸우지 않고 지도 칸에 이름만 띄운다(1부 반신반인 장면의
  // 로드안 · 에인션트 이블, LORESPEC.PAS:2050). `Battle::HideEnemyNames()` 로 걷는다(맵을 옮겨도 걷힌다).
  e.registerCommand('Battle::ShowEnemyNames', (_, _) async {
    HDHosts().ui.showNameList(HDCm2BattleAdapter().enemyNameList());
  });
  e.registerCommand('Battle::HideEnemyNames', (_, _) async {
    HDHosts().ui.showNameList(const []);
  });

  e.registerCommand('Battle::Start', (stmt, eng) async {
    HDHosts().ui.showNameList(const []);
    final flags = stmt.args.isEmpty ? 0 : integer(eng, stmt.args, 0);
    await HDCm2BattleAdapter().start(flags);
  });

  // ---- 무작위 조우 ----

  e.registerCommand('Encounter::Clear', (_, _) async {
    HDGameSession().mapRuntime.encounterTable.clear();
  });
  e.registerCommand('Encounter::Add', (stmt, eng) async {
    final from = integer(eng, stmt.args, 0, symbol: 'Encounter::Add');
    final to = stmt.args.length > 1 ? integer(eng, stmt.args, 1) : from;
    final table = HDGameSession().mapRuntime.encounterTable;
    for (var no = from; no <= to; no++) {
      table.add(no);
    }
  });
  e.registerCommand('Encounter::Enable', (stmt, eng) async {
    HDGameSession().mapRuntime.encounterEnabled =
        integer(eng, stmt.args, 0, fallback: 1) != 0;
  });

  // ---- 게임 흐름 ----

  e.registerCommand('Game::Over', (_, _) async {
    await HDMenuFlows().processGameOver(1);
  });

  // 엔딩 — 본 것을 적고 제목 화면으로 돌아간다. 글은 스크립트가 이미 냈다.
  e.registerCommand('Game::Ending', (stmt, eng) async {
    final which = str(eng, stmt.args, 0);
    await HDTitleFlow().finishWithEnding(which);
    eng.halted = true;
  });

  e.registerCommand('Game::Start', (stmt, eng) async {
    final episode = integer(eng, stmt.args, 0, symbol: 'Game::Start');
    eng.halted = true;
    await HDTitleFlow().startEpisode(episode);
  });

  // ============================================================== 함수

  e.registerFunction('Party::CheckIf', (args, _) {
    final w = world();
    return switch (HDScriptEngine.num0(args, 0, fallback: -1)) {
          0 => w.torch > 0, // CHECKIF_MAGICTORCH
          1 => w.buffs.canLevitate, // CHECKIF_LEVITATION
          2 => w.buffs.canWalkOnWater, // CHECKIF_WALKONWATER
          3 => w.buffs.canWalkOnSwamp, // CHECKIF_WALKONSWAMP
          4 => w.buffs.isMindReading, // CHECKIF_MINDCONTROL
          _ => false,
        }
        ? 1
        : 0;
  });

  e.registerFunction(
    'Party::HasFreeSeat',
    (_, _) => world().firstFreeCompanionSeat != null ? 1 : 0,
  );

  e.registerFunction('Party::Has', (args, _) {
    final key = args.isEmpty ? '' : args[0].toString();
    return world().presentMembers.any((m) => m.nameKey == key) ? 1 : 0;
  });

  e.registerFunction(
    'Party::HasAssistant',
    (_, _) => world().assistant != null ? 1 : 0,
  );

  // 1~5번 중 있는 사람 수 (보조 일원은 세지 않는다).
  e.registerFunction(
    'Party::Count',
    (_, _) => world().presentSeats.where((s) => s != Seat.assistant).length,
  );
  // 일행 중 초자연력 기술치가 n 이상인 마법사 계열이 있는가 (스피카의 합류 조건).
  e.registerFunction(
    'Party::HasEsp',
    (args, _) => world().anyoneHasEsp(
          args.isEmpty ? 1 : int.tryParse(args[0].toString()) ?? 1,
        )
        ? 1
        : 0,
  );
  e.registerFunction('Party::AvgLevel', (_, _) => world().averageCommandLevel);
  e.registerFunction('Party::Gold', (_, _) => world().gold);
  e.registerFunction('Party::Food', (_, _) => world().food);
  e.registerFunction('Party::Arrows', (_, _) => world().arrows);
  e.registerFunction('Party::Torch', (_, _) => world().torch);

  Member? seatOf(List<dynamic> args) {
    final n = HDScriptEngine.num0(args, 0);
    return (n >= 1 && n <= Seat.count) ? world().member(n - 1) : null;
  }

  e.registerFunction('Player::GetName', (args, _) => seatOf(args)?.name ?? '');
  e.registerFunction(
    'Player::IsAvailable',
    (args, _) => seatOf(args) != null ? 1 : 0,
  );
  e.registerFunction(
    'Player::CanAct',
    (args, _) => (seatOf(args)?.canAct ?? false) ? 1 : 0,
  );

  e.registerFunction('Player::GetAttribute', (args, _) {
    final m = seatOf(args);
    if (m == null || args.length < 2) return 0;
    final attr = args[1].toString();
    final value = readAttribute(m, attr);
    if (value == null) {
      // 0 을 돌려줄 수밖에 없지만 반드시 알린다 — 모르는 이름에 0 을 주고
      // 조용히 다른 갈래를 타는 것이 cm2 의 가장 흔한 사고다.
      debugPrint('[cm2] Player::GetAttribute("$attr") — 그런 속성이 없다. 0');
      return 0;
    }
    return value;
  });

  e.registerFunction('Item::Count', (args, _) {
    if (args.isEmpty) return 0;
    return world().countOf(args[0].toString());
  });

  // 날 단위 기한 (제2부의 월식 · 레굴루스가 돌아오는 날).
  // `Time::DayNumber()` — 달력 첫날부터 센 오늘의 번호. 「N일 뒤」는 Add(Time::DayNumber(), N).
  // `Time::YearAfter(n)` · `Time::MonthAfter(n)` · `Time::DayAfter(n)` — n일 뒤의 연·월·일(글에 날짜를 낼 때).
  e.registerFunction('Time::DayNumber', (_, _) => world().calendar.totalSeconds ~/ 86400);
  LoreCalendar after(List<dynamic> args) =>
      world().calendar.copy()..advance(hours: 24 * HDScriptEngine.num0(args, 0));
  e.registerFunction('Time::YearAfter', (args, _) => after(args).year);
  e.registerFunction('Time::MonthAfter', (args, _) => after(args).month);
  e.registerFunction('Time::DayAfter', (args, _) => after(args).day);

  e.registerFunction('Time::Year', (_, _) => world().calendar.year);
  e.registerFunction('Time::Month', (_, _) => world().calendar.month);
  e.registerFunction('Time::Day', (_, _) => world().calendar.day);
  e.registerFunction('Time::Hour', (_, _) => world().calendar.hour);
  e.registerFunction('Time::Minute', (_, _) => world().calendar.minute);

  e.registerFunction('Battle::Result', (_, _) => HDCm2BattleAdapter().result());
  // 마지막 전투에서 등록 순서 n 번째 적이 쓰러졌는가(의식불명·죽음) — 도망쳤어도 본다.
  e.registerFunction(
    'Battle::EnemyDown',
    (args, _) => HDCm2BattleAdapter().enemyDown(HDScriptEngine.num0(args, 0)) ? 1 : 0,
  );
  // 마지막 전투에서 쓰러뜨린 등록된 적의 수 — 도망쳤어도 센다.
  e.registerFunction('Battle::Downed', (_, _) => HDCm2BattleAdapter().enemiesDown());
}
