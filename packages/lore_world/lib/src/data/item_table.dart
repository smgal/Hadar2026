import '../domain/enums.dart';

/// 물품(소모품) 하나(제10장 10.5).
final class ConsumableDef {
  const ConsumableDef(
    this.legacyId,
    this.key,
    this.price,
    this.shop, {
    this.needsTarget = false,
    this.usableInBattle = false,
  });

  /// 원작 번호 1~10.
  final int legacyId;
  final String key;
  final int price;
  final ShopKind shop;

  /// 쓰는 사람과 받는 사람이 다를 수 있는가(의식의 약초·부활의 약초).
  final bool needsTarget;

  /// 전투 중에는 약초·약물(1~5번)만 쓴다.
  final bool usableInBattle;
}

abstract final class ItemKey {
  static const String hpPotion = 'item.hp_potion';
  static const String mpPotion = 'item.mp_potion';
  static const String antidoteHerb = 'item.antidote_herb';
  static const String awakeningHerb = 'item.awakening_herb';
  static const String revivalHerb = 'item.revival_herb';
  static const String summonScroll = 'item.summon_scroll';
  static const String bigTorch = 'item.big_torch';
  static const String seeingOrb = 'item.seeing_orb';
  static const String flyingBoots = 'item.flying_boots';
  static const String warpOrb = 'item.warp_orb';
}

const List<ConsumableDef> consumableTable = [
  ConsumableDef(1, ItemKey.hpPotion, 2000, ShopKind.herb, usableInBattle: true),
  ConsumableDef(2, ItemKey.mpPotion, 3000, ShopKind.herb, usableInBattle: true),
  ConsumableDef(
    3,
    ItemKey.antidoteHerb,
    1000,
    ShopKind.herb,
    usableInBattle: true,
  ),
  ConsumableDef(
    4,
    ItemKey.awakeningHerb,
    5000,
    ShopKind.herb,
    needsTarget: true,
    usableInBattle: true,
  ),
  ConsumableDef(
    5,
    ItemKey.revivalHerb,
    10000,
    ShopKind.herb,
    needsTarget: true,
    usableInBattle: true,
  ),
  ConsumableDef(6, ItemKey.summonScroll, 4000, ShopKind.goods),
  ConsumableDef(7, ItemKey.bigTorch, 300, ShopKind.goods),
  ConsumableDef(8, ItemKey.seeingOrb, 500, ShopKind.goods),
  ConsumableDef(9, ItemKey.flyingBoots, 1000, ShopKind.goods),
  ConsumableDef(10, ItemKey.warpOrb, 5000, ShopKind.goods),
];

/// 크리스탈 하나(제9장 9.8).
final class CrystalDef {
  const CrystalDef(
    this.legacyId,
    this.key, {
    this.field = false,
    this.battle = false,
    this.consumed = true,
    this.story = false,
  });

  /// 원작 번호 1~9.
  final int legacyId;
  final String key;

  /// 필드에서 쓸 수 있는가.
  final bool field;

  /// 전투에서 쓸 수 있는가.
  final bool battle;

  /// 쓰면 사라지는가.
  final bool consumed;

  /// 이야기가 정하는 크리스탈. 쓰면 「이야기」라고만 알리고 스크립트가 정한다.
  final bool story;
}

abstract final class CrystalKey {
  static const String flame = 'crystal.flame';
  static const String frost = 'crystal.frost';
  static const String dark = 'crystal.dark';
  static const String ebony = 'crystal.ebony';
  static const String spirit = 'crystal.spirit';
  static const String summon = 'crystal.summon';
  static const String energy = 'crystal.energy';
  static const String chromatic = 'crystal.chromatic';
  static const String ball = 'crystal.ball';
}

const List<CrystalDef> crystalTable = [
  CrystalDef(1, CrystalKey.flame, battle: true),
  CrystalDef(2, CrystalKey.frost, battle: true),
  CrystalDef(3, CrystalKey.dark, battle: true),
  CrystalDef(4, CrystalKey.ebony, battle: true),
  CrystalDef(5, CrystalKey.spirit, battle: true),
  CrystalDef(6, CrystalKey.summon, field: true, battle: true),
  CrystalDef(7, CrystalKey.energy, field: true, battle: true),
  CrystalDef(
    8,
    CrystalKey.chromatic,
    field: true,
    consumed: false,
    story: true,
  ),
  CrystalDef(9, CrystalKey.ball, field: true, consumed: false, story: true),
];

/// 일행 공용 물자의 이름. 상점 영수증과 저장에 쓰인다.
abstract final class SupplyKey {
  static const String gold = 'supply.gold';
  static const String food = 'supply.food';
  static const String arrows = 'supply.arrows';
}

const int foodLimit = 255;
const int arrowLimit = 65535;

/// 식료품점: 10인분에 금 100.
const int foodPackSize = 10;
const int foodPackPrice = 100;

/// 물품 가게: 화살 10개에 금 500.
const int arrowPackSize = 10;
const int arrowPackPrice = 500;

/// 전직 비용.
const int classChangeFee = 10000;

/// 경험치 훈련장: 금 10000 에 경험치 10000, 1시간.
const int expTrainingUnit = 10000;

ConsumableDef? consumableByKey(String key) {
  for (final c in consumableTable) {
    if (c.key == key) return c;
  }
  return null;
}

ConsumableDef? consumableByLegacyId(int id) {
  for (final c in consumableTable) {
    if (c.legacyId == id) return c;
  }
  return null;
}

CrystalDef? crystalByKey(String key) {
  for (final c in crystalTable) {
    if (c.key == key) return c;
  }
  return null;
}

CrystalDef? crystalByLegacyId(int id) {
  for (final c in crystalTable) {
    if (c.legacyId == id) return c;
  }
  return null;
}
