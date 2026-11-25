import '../contract/events.dart';
import '../contract/outcome.dart';
import '../data/equipment_table.dart';
import '../data/item_table.dart';
import '../domain/enums.dart';
import '../domain/member.dart';
import '../model/world.dart';

/// 상점(제10장 10.7). 어느 성에 어느 가게가 있는지는 **콘텐츠**라 여기 없다.
///
/// ## 한도에 걸릴 때
///
/// 이미 한도까지 갖고 있으면 거절한다(`atLimit`). 한도를 넘게 청하면
/// **들어가는 만큼만 주고 그만큼만 받는다.** 받지 못한 물건의 값을 치르는
/// 일은 없다.
extension ShopRules on LoreWorld {
  /// 이 편의 가게에서 파는가.
  bool isForSale(String key) {
    final weapon = weaponByKey(key);
    if (weapon != null)
      return weapon.onlyIn == null || weapon.onlyIn == episode;
    if (shieldByKey(key) != null) return true;
    final armour = armourByKey(key);
    if (armour != null) return armour.price != null;
    return consumableByKey(key) != null;
  }

  /// 한 개의 값. 팔지 않으면 null.
  int? priceOf(String key) {
    if (!isForSale(key)) return null;
    return equipmentPrice(key) ?? consumableByKey(key)?.price;
  }

  Outcome _buy({
    required String key,
    required int requested,
    required int unitPrice,
    required int have,
    required int limit,
  }) {
    if (have >= limit) return Outcome.refused(RefusalReason.atLimit, key: key);
    final room = limit - have;
    final count = requested < room ? requested : room;
    final cost = count * unitPrice;
    if (gold < cost) {
      return Outcome.refused(
        RefusalReason.notEnoughGold,
        key: key,
        amount: cost - gold,
      );
    }
    gold -= cost;
    give(key, count);
    return Outcome.accepted([Purchased(key, count, cost)]);
  }

  /// 식료품점. `packs` 는 1~5 (10인분 ~ 50인분), 10인분에 금 100.
  Outcome buyFood(int packs) {
    if (packs < 1 || packs > 5) {
      return Outcome.refused(RefusalReason.invalidAmount, key: SupplyKey.food);
    }
    return _buy(
      key: SupplyKey.food,
      requested: packs * foodPackSize,
      unitPrice: foodPackPrice ~/ foodPackSize,
      have: food,
      limit: foodLimit,
    );
  }

  /// 물품 가게의 화살. `packs` 는 1~10 (10개 ~ 100개), 10개에 금 500.
  Outcome buyArrows(int packs) {
    if (packs < 1 || packs > 10) {
      return Outcome.refused(
        RefusalReason.invalidAmount,
        key: SupplyKey.arrows,
      );
    }
    return _buy(
      key: SupplyKey.arrows,
      requested: packs * arrowPackSize,
      unitPrice: arrowPackPrice ~/ arrowPackSize,
      have: arrows,
      limit: arrowLimit,
    );
  }

  /// 무기상점 — 무기·방패·갑옷을 한 개 산다. 배낭에 들어간다.
  Outcome buyEquipment(String key) {
    if (equipSlotOf(key) == null) {
      return Outcome.refused(RefusalReason.unknownItem, key: key);
    }
    final price = priceOf(key);
    if (price == null)
      return Outcome.refused(RefusalReason.notForSale, key: key);
    return _buy(
      key: key,
      requested: 1,
      unitPrice: price,
      have: backpack[key] ?? 0,
      limit: stackLimit,
    );
  }

  /// 약초 가게 · 물품 가게 — 물품을 1~10개 산다.
  ///
  /// [shop] 을 주면 그 가게가 파는 물건인지도 본다.
  Outcome buyConsumable(String key, int count, {ShopKind? shop}) {
    final def = consumableByKey(key);
    if (def == null)
      return Outcome.refused(RefusalReason.unknownItem, key: key);
    if (shop != null && def.shop != shop) {
      return Outcome.refused(RefusalReason.wrongShop, key: key);
    }
    if (count < 1 || count > 10) {
      return Outcome.refused(RefusalReason.invalidAmount, key: key);
    }
    return _buy(
      key: key,
      requested: count,
      unitPrice: def.price,
      have: consumables[key] ?? 0,
      limit: stackLimit,
    );
  }
}

/// 병원(제10장 10.7).
extension HospitalRules on LoreWorld {
  /// 그 치료를 받을 수 없는 이유. 받을 수 있으면 null. 돈은 보지 않는다.
  RefusalReason? checkTreatment(Member m, Treatment treatment) {
    switch (treatment) {
      case Treatment.wounds:
        if (m.isDead) return RefusalReason.alreadyDead;
        if (m.isUnconscious) return RefusalReason.alreadyUnconscious;
        if (m.isPoisoned) return RefusalReason.poisonSpreading;
        if (m.hp >= m.maxHp) return RefusalReason.noTreatmentNeeded;
      case Treatment.poison:
        if (m.isDead) return RefusalReason.alreadyDead;
        if (m.isUnconscious) return RefusalReason.alreadyUnconscious;
        if (!m.isPoisoned) return RefusalReason.noTreatmentNeeded;
      case Treatment.consciousness:
        if (m.isDead) return RefusalReason.alreadyDead;
        if (!m.isUnconscious) return RefusalReason.noTreatmentNeeded;
      case Treatment.revival:
        if (!m.isDead) return RefusalReason.noTreatmentNeeded;
    }
    return null;
  }

  /// 치료비.
  ///
  /// * 상처 — round((최대 HP − 현재 HP) × 레벨 ÷ 10) + 1
  /// * 독 — 레벨 × 10
  /// * 의식 — 의식불명 수치 × 2
  /// * 부활 — 죽음 수치 × 100 + 400
  int treatmentFee(Member m, Treatment treatment) => switch (treatment) {
    Treatment.wounds => ((m.maxHp - m.hp) * m.level + 5) ~/ 10 + 1,
    Treatment.poison => m.level * 10,
    Treatment.consciousness => m.unconscious * 2,
    Treatment.revival => m.dead * 100 + 400,
  };

  /// 그 자리의 대원이 그 치료를 받으면 얼마인가. 받을 수 없으면 null.
  int? hospitalFee(int seat, Treatment treatment) {
    final m = member(seat);
    if (m == null || checkTreatment(m, treatment) != null) return null;
    return treatmentFee(m, treatment);
  }

  /// 치료를 받는다.
  ///
  /// 깊은 곳부터다 — 죽었으면 상처·독·의식 치료를 받을 수 없고, 의식불명이면
  /// 상처·독을, 중독이면 상처를 치료할 수 없다. 부활하면 **의식불명 상태로**
  /// 돌아오고, 의식을 찾으면 HP 1 이다.
  Outcome hospitalTreat(int seat, Treatment treatment) {
    final m = member(seat);
    if (m == null)
      return Outcome.refused(RefusalReason.noSuchMember, seat: seat);
    final refusal = checkTreatment(m, treatment);
    if (refusal != null) return Outcome.refused(refusal, seat: seat);
    final fee = treatmentFee(m, treatment);
    if (gold < fee) {
      return Outcome.refused(
        RefusalReason.notEnoughGold,
        seat: seat,
        amount: fee - gold,
      );
    }
    gold -= fee;
    final events = <LoreEvent>[HospitalTreated(seat, treatment, fee)];
    switch (treatment) {
      case Treatment.wounds:
        final gained = m.healHp(m.maxHp);
        events.add(HpRestored(seat, gained, full: true));
      case Treatment.poison:
        m.curePoison();
        events.add(PoisonCured(seat));
      case Treatment.consciousness:
        m.unconscious = 0;
        m.hp = 1;
        events.add(Awakened(seat));
      case Treatment.revival:
        m.revive();
        events.add(Revived(seat));
    }
    return Outcome.accepted(events);
  }
}
