import '../contract/vocabulary.dart';

/// Herbs, potions and crystals — ch.8.4 line 8, ch.9.8, ch.10.5.
///
/// The original's battle menu offers two shelves: the first five items
/// (the only ones a battle can use) and crystals one to seven. Here they
/// are one list in that order.
///
/// The party's pack is not touched. The battle is handed a projection
/// of what it may use, spends from that, and reports what it spent.

enum BattleItemKind { medicine, crystal }

/// Who an item is used on.
enum ItemTarget {
  /// The one using it. The two potions and the antidote are personal
  /// (ch.10.5 "사용자").
  self,

  /// One party member, chosen next — waking and raising.
  ally,

  /// One enemy, chosen next.
  enemy,

  /// Every enemy.
  allEnemies,

  /// Nothing to aim.
  none,
}

/// One usable item.
class BattleItem {
  const BattleItem({
    required this.key,
    required this.kind,
    required this.target,
    this.needsMagic = false,
  });

  /// Matches the key the RPG hands over ([ItemKey]).
  final String key;
  final BattleItemKind kind;
  final ItemTarget target;

  /// The magic potion only works for someone who holds magic points —
  /// the mage family and the paladin. The original took the potion
  /// anyway (appendix A #23); here it is simply not on that member's
  /// list.
  final bool needsMagic;
}

/// The list, in the original's menu order.
const List<BattleItem> battleItemList = [
  BattleItem(
    key: ItemKey.hpPotion,
    kind: BattleItemKind.medicine,
    target: ItemTarget.self,
  ),
  BattleItem(
    key: ItemKey.mpPotion,
    kind: BattleItemKind.medicine,
    target: ItemTarget.self,
    needsMagic: true,
  ),
  BattleItem(
    key: ItemKey.antidoteHerb,
    kind: BattleItemKind.medicine,
    target: ItemTarget.self,
  ),
  BattleItem(
    key: ItemKey.awakeningHerb,
    kind: BattleItemKind.medicine,
    target: ItemTarget.ally,
  ),
  BattleItem(
    key: ItemKey.revivalHerb,
    kind: BattleItemKind.medicine,
    target: ItemTarget.ally,
  ),
  BattleItem(
    key: ItemKey.flameCrystal,
    kind: BattleItemKind.crystal,
    target: ItemTarget.enemy,
  ),
  BattleItem(
    key: ItemKey.frostCrystal,
    kind: BattleItemKind.crystal,
    target: ItemTarget.allEnemies,
  ),
  // The pair. Either one opens the same use; it needs both.
  BattleItem(
    key: ItemKey.darkCrystal,
    kind: BattleItemKind.crystal,
    target: ItemTarget.none,
  ),
  BattleItem(
    key: ItemKey.ebonyCrystal,
    kind: BattleItemKind.crystal,
    target: ItemTarget.none,
  ),
  BattleItem(
    key: ItemKey.spiritCrystal,
    kind: BattleItemKind.crystal,
    target: ItemTarget.enemy,
  ),
  BattleItem(
    key: ItemKey.summonCrystal,
    kind: BattleItemKind.crystal,
    target: ItemTarget.none,
  ),
  BattleItem(
    key: ItemKey.energyCrystal,
    kind: BattleItemKind.crystal,
    target: ItemTarget.none,
  ),
];

final Map<String, BattleItem> battleItems = {
  for (final item in battleItemList) item.key: item,
};

/// Which of [held] this member can use right now, in menu order.
List<String> usableItems(Map<String, int> held, {required bool holdsMagic}) => [
  for (final item in battleItemList)
    if ((held[item.key] ?? 0) > 0 && (!item.needsMagic || holdsMagic)) item.key,
];

/// What each potion restores (ch.10.5).
const int potionRestore = 1000;

/// 화염의 크리스탈 — fixed damage to one enemy. No roll to hit; magic
/// resistance and armour still apply (ch.9.8).
const int flameCrystalDamage = 32500;

/// 한파의 크리스탈 — fixed damage to each enemy.
const int frostCrystalDamage = 20000;
