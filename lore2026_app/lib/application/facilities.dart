import 'package:lore_world/lore_world.dart';

import 'field_rules.dart';
import 'game_session.dart';
import 'ports/host_binding.dart';
import 'ports/ui_host.dart';
import 'world_text.dart';

/// 가게와 시설 — 식료품점 · 무기상점 · 약초 가게 · 물품 가게 · 병원 ·
/// 훈련소(마법 학교 · 전직) · 경험치 훈련장 (제10장 10.7).
///
/// 세 편의 모든 성이 같은 시설을 쓰므로 스크립트는 사람 칸에서
/// `Shop::Weapon()` 한 줄로 부른다. **값 · 한도 · 조건은 `LoreWorld` 가
/// 정한다** — 여기는 묻고, 답을 명령으로 넘기고, 돌아온 결과를 말로 옮긴다.
class HDFacilities {
  static final HDFacilities _instance = HDFacilities._internal();
  factory HDFacilities() => _instance;
  HDFacilities._internal();

  UiHost get _ui => HDHosts().ui;
  LoreWorld get _world => HDGameSession().party.world;

  void _changed() {
    HDGameSession().party.notifyListeners();
    _ui.refresh();
  }

  Future<void> _say(String text) => _ui.addLog(text);

  /// 명령의 결과를 말로 옮긴다. 거절이면 그 까닭을, 아니면 일어난 일을.
  Future<void> _report(Outcome outcome) async {
    for (final line in worldLines(outcome)) {
      await _say(line);
    }
    _changed();
  }

  /// 「누가 …?」 — 자리에 있는 사람 중에서 고른다. 취소하면 null.
  Future<int?> _pickSeat(String prompt, {bool companionsOnly = true}) async {
    final seats = [
      for (final s in _world.presentSeats)
        if (!companionsOnly || s != Seat.assistant) s,
    ];
    if (seats.isEmpty) return null;
    final picked = await _ui.showWindowMenu([
      prompt,
      for (final s in seats) _world.member(s)!.name,
    ]);
    return picked <= 0 ? null : seats[picked - 1];
  }

  String _price(int? gold) => gold == null ? '' : '금 $gold 개';

  String _row(String name, String right) => '${name.padRight(12)} $right';

  // ── 식료품점 ────────────────────────────────────────────

  Future<void> grocery() async {
    await _say('여기는 식료품점입니다. 몇 개를 원하십니까?');
    final picked = await _ui.showWindowMenu([
      '식량 (지금 ${_world.food} 인분)',
      '필요 없습니다',
      for (var packs = 1; packs <= 5; packs++)
        '${packs * foodPackSize} 인분 : ${_price(packs * foodPackPrice)}',
    ]);
    if (picked <= 1) {
      await _say('당신이 바란다면 ...');
      return;
    }
    final outcome = _world.buyFood(picked - 1);
    if (outcome.ok) {
      await _say('매우 고맙습니다.');
      _changed();
    } else {
      await _report(outcome);
    }
  }

  // ── 무기상점 ────────────────────────────────────────────

  Future<void> weaponShop() async {
    await _say(
      '여기는 무기상점입니다. 우리들은 무기, 방패, 갑옷을 팔고 있습니다. '
      '어떤 종류를 원하십니까?',
    );
    const kinds = [
      WeaponKind.slash,
      WeaponKind.chop,
      WeaponKind.pierce,
      WeaponKind.shoot,
    ];
    while (true) {
      final category = await _ui.showWindowMenu([
        '무기상점  (${_price(_world.gold)})',
        '베는 무기류',
        '찍는 무기류',
        '찌르는 무기류',
        '쏘는 무기류',
        '방패류',
        '갑옷류',
      ]);
      if (category <= 0) break;
      final keys = <String>[
        if (category <= 4)
          for (final w in weaponTable)
            if (w.kind == kinds[category - 1] && _world.isForSale(w.key)) w.key,
        if (category == 5)
          for (final s in shieldTable)
            if (_world.isForSale(s.key)) s.key,
        if (category == 6)
          for (final a in armourTable)
            if (_world.isForSale(a.key)) a.key,
      ];
      // 같은 종류를 이어서 살 수 있다. Esc 로 종류 고르기로 돌아간다.
      var cursor = 1;
      while (true) {
        final item = await _ui.showWindowMenu([
          '무엇을 사시겠습니까?  (${_price(_world.gold)})',
          for (final k in keys) _row(itemName(k), _price(_world.priceOf(k))),
        ], initialChoice: cursor);
        if (item <= 0) break;
        cursor = item;
        final outcome = _world.buyEquipment(keys[item - 1]);
        if (outcome.ok) {
          await _say('${josa(itemName(keys[item - 1]), '을/를')} 샀습니다. 매우 고맙습니다.');
          _changed();
        } else {
          await _report(outcome);
        }
      }
    }
  }

  // ── 약초 가게 · 물품 가게 ──────────────────────────────

  Future<void> herbShop() async {
    await _say('여기는 약초를 파는 곳입니다. 당신이 사고 싶은 약이나 약초를 고르십시오.');
    await _consumableShop(ShopKind.herb, withArrows: false);
  }

  Future<void> goodsShop() async {
    await _say('여기는 여러 가지 물품을 파는 곳입니다.');
    await _consumableShop(ShopKind.goods, withArrows: true);
  }

  Future<void> _consumableShop(ShopKind shop, {required bool withArrows}) async {
    final keys = [
      for (final c in consumableTable)
        if (c.shop == shop) c.key,
    ];
    var cursor = 1;
    while (true) {
      final picked = await _ui.showWindowMenu([
        '무엇을 사시겠습니까?  (${_price(_world.gold)})',
        if (withArrows)
          _row('화살', '$arrowPackSize개 ${_price(arrowPackPrice)}'),
        for (final k in keys) _row(itemName(k), _price(_world.priceOf(k))),
      ], initialChoice: cursor);
      if (picked <= 0) break;
      cursor = picked;
      final isArrows = withArrows && picked == 1;
      final key = isArrows ? null : keys[picked - (withArrows ? 2 : 1)];

      final count = await _ui.showWindowMenu([
        '갯수를 지정하십시오.',
        for (var n = 1; n <= 10; n++)
          isArrows ? '${n * arrowPackSize} 개' : '$n 개',
      ]);
      if (count <= 0) continue;

      final outcome = isArrows
          ? _world.buyArrows(count)
          : _world.buyConsumable(key!, count, shop: shop);
      if (outcome.ok) {
        await _say('매우 고맙습니다.');
        _changed();
      } else {
        await _report(outcome);
      }
    }
  }

  // ── 병원 ────────────────────────────────────────────────

  Future<void> hospital() async {
    await _say('여기는 병원입니다.');
    while (true) {
      final seat = await _pickSeat('누가 치료를 받겠습니까?', companionsOnly: false);
      if (seat == null) return;
      const treatments = [
        Treatment.wounds,
        Treatment.poison,
        Treatment.consciousness,
        Treatment.revival,
      ];
      const labels = ['상처를 치료', '독을 제거', '의식의 회복', '부활'];
      final picked = await _ui.showWindowMenu([
        '어떤 치료입니까?  (${_price(_world.gold)})',
        for (var i = 0; i < treatments.length; i++)
          _row(labels[i], _price(_world.hospitalFee(seat, treatments[i]))),
      ]);
      if (picked <= 0) continue;
      await _report(_world.hospitalTreat(seat, treatments[picked - 1]));
    }
  }

  // ── 훈련소 · 마법 학교 · 전직 ──────────────────────────

  Future<void> training() async {
    while (true) {
      final picked = await _ui.showWindowMenu([
        '어떤 일을 원하십니까?',
        '전투사 계열의 기술을 습득',
        '마법사 계열의 능력을 습득',
        '전투사 계열의 계급을 바꿈',
        '마법사 계열의 계급을 바꿈',
      ]);
      if (picked <= 0) return;
      final facility = picked.isOdd
          ? TrainingFacility.military
          : TrainingFacility.magicSchool;
      if (picked <= 2) {
        await _say(
          facility == TrainingFacility.military
              ? '여기는 군사 훈련소입니다. 만약 당신이 충분한 전투 경험을 쌓았다면, '
                    '당신은 더욱 능숙하게 무기를 다룰 것입니다.'
              : '여기는 마법 학교입니다. 만약 당신이 충분한 실전 경험을 쌓았다면, '
                    '당신은 더욱 능숙하게 마법을 다룰 것입니다.',
        );
        await _trainSkills(facility);
      } else {
        await _changeClass(facility);
      }
    }
  }

  Future<void> _trainSkills(TrainingFacility facility) async {
    final seat = await _pickSeat('누가 훈련을 받겠습니까?');
    if (seat == null) return;

    // 계열이 맞는지, 모든 과정을 마쳤는지는 문을 들어설 때 정해진다.
    final visit = _world.visitSchool(seat, facility);
    await _report(visit);
    if (visit.isRefused || visit.has<AllCoursesCompleted>()) return;

    var cursor = 1;
    while (true) {
      final m = _world.member(seat);
      if (m == null) return;
      final options = _world.trainingOptions(seat);
      final picked = await _ui.showWindowMenu([
        '${m.name}  경험치 ${m.exp}',
        for (final o in options)
          _row(
            skillName(m, o.skill),
            o.forClass ? '${o.value.toString().padLeft(3)}  (비용 ${o.cost})' : '  -',
          ),
      ], initialChoice: cursor);
      if (picked <= 0) return;
      cursor = picked;
      await _report(_world.train(seat, facility, options[picked - 1].skill));
    }
  }

  Future<void> _changeClass(TrainingFacility facility) async {
    final seat = await _pickSeat('누가 계급을 바꾸겠습니까?');
    if (seat == null) return;
    final m = _world.member(seat)!;
    final wanted = facility == TrainingFacility.military
        ? Family.fighter
        : Family.mage;
    if (m.family != wanted) {
      await _say(
        wanted == Family.fighter ? '당신은 전투사 계열이 아닙니다.' : '당신은 마법사 계열이 아닙니다.',
      );
      return;
    }
    final options = _world.classChangeOptions(seat);
    if (options.isEmpty) {
      await _say('지금 바꿀 수 있는 계급이 없습니다.');
      return;
    }
    final picked = await _ui.showWindowMenu([
      '어느 계급으로 바꾸겠습니까?  (금 $classChangeFee 개)',
      for (final id in options) classNameOf(m.family, id),
    ]);
    if (picked <= 0) return;
    await _report(_world.changeClass(seat, facility, options[picked - 1]));
  }

  // ── 경험치 훈련장 ──────────────────────────────────────

  Future<void> expTraining() async {
    await _say(
      '여기에서는 황금의 양만큼 훈련을 시켜서 경험치를 올려 주는 곳입니다. '
      '원하시는 금액을 고르십시오.',
    );
    final picked = await _ui.showWindowMenu([
      '경험치 훈련  (${_price(_world.gold)})',
      for (var n = 1; n <= 10; n++)
        '금 ${n * expTrainingUnit} 개; 소요 시간 : $n 시간',
    ]);
    if (picked <= 0) {
      await _say('당신이 바란다면 ...');
      return;
    }
    final outcome = _world.buyExpTraining(picked);
    if (outcome.isRefused) {
      await _report(outcome);
      return;
    }
    await _say('일행은 $picked 시간 동안 훈련을 받게 되었다.');
    await _ui.waitForAnyKey();
    await _say('일행은 훈련을 끝마쳤다.');
    _changed();
    // 훈련하는 동안 예약한 시각이 지났을 수 있다.
    await HDFieldRules().checkTimer();
  }
}
