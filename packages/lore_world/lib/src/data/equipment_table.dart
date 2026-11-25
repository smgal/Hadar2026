import '../domain/enums.dart';

/// 맨손이거나 계급이 쓸 수 없는 무기의 공격력.
const int barePower = 5;

/// 배낭·물품·크리스탈 한 종류의 최대 개수.
const int stackLimit = 255;

/// 무기 하나(제10장 10.2).
///
/// 공격력은 **계급마다 다르다.** `power[열]` 의 열 순서는
/// 투사·기사·검사·사냥꾼·전투승·암살자·전사. 그 계급이 장착할 수 없는
/// 칸에도 참고치가 들어 있지만 읽히지 않는다 — 장착할 수 없으면 5 다.
final class WeaponDef {
  const WeaponDef(
    this.legacyId,
    this.key,
    this.kind,
    this.price,
    this.power, {
    this.onlyIn,
  });

  /// 원작의 1 부터 세는 번호. 맵 스크립트가 이 번호로 부른다.
  final int legacyId;
  final String key;
  final WeaponKind kind;
  final int price;
  final List<int> power;

  /// 이 편에서만 파는 무기면 그 편.
  final Episode? onlyIn;

  EquipSlot get slot => EquipSlot.weapon;
}

final class ShieldDef {
  const ShieldDef(this.legacyId, this.key, this.defence, this.price);

  final int legacyId;
  final String key;

  /// 방패 방어력(1~5). 방패 막기 확률에 쓰인다.
  final int defence;
  final int price;

  EquipSlot get slot => EquipSlot.shield;
}

final class ArmourDef {
  const ArmourDef(this.legacyId, this.key, this.defence, this.price);

  final int legacyId;
  final String key;
  final int defence;

  /// null 이면 팔지 않는다(흑요석 갑옷).
  final int? price;

  EquipSlot get slot => EquipSlot.armour;
}

const WeaponKind _s = WeaponKind.slash;
const WeaponKind _c = WeaponKind.chop;
const WeaponKind _p = WeaponKind.pierce;
const WeaponKind _a = WeaponKind.shoot;

/// 무기 28종 + 제1부 전용 화염검.
const List<WeaponDef> weaponTable = [
  // 베는 무기                                    투  기  검  사  승  암  전
  WeaponDef(1, 'weapon.short_sword', _s, 500, [15, 15, 15, 15, 15, 25, 15]),
  WeaponDef(2, 'weapon.gladius', _s, 3000, [30, 30, 25, 25, 25, 25, 30]),
  WeaponDef(3, 'weapon.sabre', _s, 5000, [35, 40, 35, 35, 35, 35, 40]),
  WeaponDef(4, 'weapon.scimitar', _s, 7000, [45, 48, 50, 40, 40, 40, 40]),
  WeaponDef(5, 'weapon.falchion', _s, 12000, [50, 55, 60, 50, 50, 50, 55]),
  WeaponDef(6, 'weapon.long_sword', _s, 40000, [60, 70, 70, 60, 60, 60, 65]),
  WeaponDef(7, 'weapon.flamberge', _s, 70000, [70, 70, 80, 70, 70, 70, 70]),
  // 찍는 무기
  WeaponDef(8, 'weapon.club', _c, 500, [15, 15, 15, 15, 15, 15, 15]),
  WeaponDef(9, 'weapon.hand_axe', _c, 3000, [35, 30, 30, 37, 30, 30, 30]),
  WeaponDef(10, 'weapon.flail', _c, 5000, [35, 40, 35, 35, 35, 35, 35]),
  WeaponDef(11, 'weapon.war_hammer', _c, 10000, [52, 45, 45, 45, 45, 45, 45]),
  WeaponDef(12, 'weapon.mace', _c, 30000, [60, 60, 55, 55, 55, 55, 55]),
  WeaponDef(13, 'weapon.battle_axe', _c, 60000, [75, 70, 70, 70, 70, 70, 70]),
  WeaponDef(14, 'weapon.halberd', _c, 100000, [80, 85, 80, 80, 80, 80, 80]),
  // 찌르는 무기
  WeaponDef(15, 'weapon.dagger', _p, 100, [10, 10, 10, 25, 10, 20, 10]),
  WeaponDef(16, 'weapon.lance', _p, 1000, [35, 40, 35, 35, 35, 35, 40]),
  WeaponDef(17, 'weapon.short_spear', _p, 1500, [35, 30, 30, 35, 30, 30, 30]),
  WeaponDef(18, 'weapon.rapier', _p, 4000, [40, 40, 40, 45, 40, 40, 40]),
  WeaponDef(19, 'weapon.trident', _p, 8000, [60, 60, 60, 60, 60, 60, 60]),
  WeaponDef(20, 'weapon.lancer', _p, 35000, [80, 80, 80, 80, 80, 80, 80]),
  WeaponDef(21, 'weapon.poleaxe', _p, 50000, [90, 90, 90, 90, 90, 90, 90]),
  // 쏘는 무기
  WeaponDef(22, 'weapon.blowpipe', _a, 200, [10, 10, 10, 15, 10, 15, 10]),
  WeaponDef(23, 'weapon.shuriken', _a, 300, [10, 10, 10, 10, 10, 20, 10]),
  WeaponDef(24, 'weapon.sling', _a, 800, [20, 20, 20, 27, 20, 20, 20]),
  WeaponDef(25, 'weapon.javelin', _a, 2000, [35, 35, 35, 40, 35, 38, 35]),
  WeaponDef(26, 'weapon.bow', _a, 5000, [45, 45, 45, 55, 45, 45, 45]),
  WeaponDef(27, 'weapon.crossbow', _a, 10000, [55, 55, 55, 65, 55, 55, 55]),
  WeaponDef(28, 'weapon.arbalest', _a, 30000, [70, 70, 70, 85, 70, 70, 70]),
  // 제1부 전용 — 화염검. 원작 값(100,000 · 공격력 50)을 그대로 둔다.
  WeaponDef(29, 'weapon.flame_sword', _s, 100000, [
    50,
    50,
    50,
    50,
    50,
    50,
    50,
  ], onlyIn: Episode.ep1),
];

const List<ShieldDef> shieldTable = [
  ShieldDef(1, 'shield.leather', 1, 3000),
  ShieldDef(2, 'shield.small_steel', 2, 15000),
  ShieldDef(3, 'shield.large_steel', 3, 45000),
  ShieldDef(4, 'shield.chromatic', 4, 80000),
  ShieldDef(5, 'shield.platinum', 5, 150000),
];

const List<ArmourDef> armourTable = [
  ArmourDef(1, 'armour.leather', 1, 2000),
  ArmourDef(2, 'armour.ring_mail', 2, 5000),
  ArmourDef(3, 'armour.chain_mail', 3, 22000),
  ArmourDef(4, 'armour.scale', 4, 45000),
  ArmourDef(5, 'armour.brigandine', 5, 75000),
  ArmourDef(6, 'armour.cuir_bouilli', 6, 100000),
  ArmourDef(7, 'armour.lamellar', 7, 140000),
  ArmourDef(8, 'armour.plate', 8, 200000),
  ArmourDef(9, 'armour.chromatic', 9, 350000),
  ArmourDef(10, 'armour.platinum', 10, 500000),
  // 데이터에만 있고 팔지 않는다. 제2부에서는 피라미드 호수의 보물이다.
  ArmourDef(11, 'armour.obsidian', 20, null),
];

WeaponDef? weaponByKey(String? key) {
  if (key == null) return null;
  for (final w in weaponTable) {
    if (w.key == key) return w;
  }
  return null;
}

ShieldDef? shieldByKey(String? key) {
  if (key == null) return null;
  for (final s in shieldTable) {
    if (s.key == key) return s;
  }
  return null;
}

ArmourDef? armourByKey(String? key) {
  if (key == null) return null;
  for (final a in armourTable) {
    if (a.key == key) return a;
  }
  return null;
}

WeaponDef? weaponByLegacyId(int id) {
  for (final w in weaponTable) {
    if (w.legacyId == id) return w;
  }
  return null;
}

ShieldDef? shieldByLegacyId(int id) {
  for (final s in shieldTable) {
    if (s.legacyId == id) return s;
  }
  return null;
}

ArmourDef? armourByLegacyId(int id) {
  for (final a in armourTable) {
    if (a.legacyId == id) return a;
  }
  return null;
}

/// 열쇠가 어느 칸의 장비인지. 장비가 아니면 null.
EquipSlot? equipSlotOf(String key) {
  if (weaponByKey(key) != null) return EquipSlot.weapon;
  if (shieldByKey(key) != null) return EquipSlot.shield;
  if (armourByKey(key) != null) return EquipSlot.armour;
  return null;
}

/// 상점 가격. 팔지 않거나 장비가 아니면 null.
int? equipmentPrice(String key) =>
    weaponByKey(key)?.price ??
    shieldByKey(key)?.price ??
    armourByKey(key)?.price;

/// 장비 열쇠 전부(무기 → 방패 → 갑옷, 원작 번호 순).
List<String> get allEquipmentKeys => [
  for (final w in weaponTable) w.key,
  for (final s in shieldTable) s.key,
  for (final a in armourTable) a.key,
];
