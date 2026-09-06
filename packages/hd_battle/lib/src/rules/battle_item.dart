import '../contract/battle_event.dart';
import 'cure.dart';

/// Items usable in a battle (B2-06).
///
/// ## This is a decision, not a port
///
/// The C++ battle menu has **no item entry at all** — eight choices,
/// none of them an item (appendix R). The Unity port grew one
/// (`_SelectKindOfItem` → `_SelectMedicalItem` / `_SelectCrystalItem` /
/// `_SelectMonsterToSummon`), but that is the other battle, the one with
/// a different spell numbering and a shifted enemy table (appendix P-3).
///
/// So the shape is borrowed and the contents are ours: **medical** items
/// that run the same cure steps the spells do, and **crystals** that
/// deal elemental damage. Summoning is left out — B2-11 already has
/// enemies calling reinforcements, and a party-side summon needs a
/// roster slot to put it in.
///
/// The party's backpack is not touched. The battle is handed a
/// projection of what it may use, spends from that, and reports what it
/// spent in `BattleOutcome.consumedItems` (B2-06's contract note).
///
/// B6-03 added a third kind: **coating** vials laid on the user's own
/// weapon, and B6-05 a medical item that restores spell points.
enum BattleItemKind { medical, crystal, coating }

/// One usable item.
class BattleItem {
  const BattleItem({
    required this.key,
    required this.kind,
    this.cureSteps = const [],
    this.healPower = 0,
    this.damage = 0,
    this.hitsAll = false,
    this.spRestore = 0,
    this.coating,
  });

  /// Stable identity, matching the key the RPG hands over.
  final String key;

  final BattleItemKind kind;

  /// For [BattleItemKind.medical]: which cure steps it runs, in order.
  /// The ordering rule is the same one the spells live under — an
  /// antidote has to come before a heal (`rules/cure.dart`).
  final List<CureStep> cureSteps;

  /// Stands in for a caster's magic level when the item heals, so an
  /// item works the same in anyone's hands.
  final int healPower;

  /// For [BattleItemKind.crystal]: damage dealt.
  final int damage;

  /// Whether a crystal hits every enemy.
  final bool hitsAll;

  /// For [BattleItemKind.medical]: spell points restored (B6-05). A
  /// medical item may do this instead of, not as well as, a cure step.
  final int spRestore;

  /// For [BattleItemKind.coating]: what goes on the weapon (B6-03).
  final Coating? coating;

  bool get targetsAlly => kind == BattleItemKind.medical;

  /// Laid on the user's own weapon; nothing to aim.
  bool get targetsSelf => kind == BattleItemKind.coating;
}

/// The table. Small on purpose — these are the shapes, not a catalogue.
const Map<String, BattleItem> battleItems = {
  'potion': BattleItem(
    key: 'potion',
    kind: BattleItemKind.medical,
    cureSteps: [CureStep.heal],
    healPower: 8,
  ),
  'antidote': BattleItem(
    key: 'antidote',
    kind: BattleItemKind.medical,
    cureSteps: [CureStep.antidote],
  ),
  'elixir': BattleItem(
    key: 'elixir',
    kind: BattleItemKind.medical,
    cureSteps: [
      CureStep.recoverConsciousness,
      CureStep.antidote,
      CureStep.heal,
    ],
    healPower: 20,
  ),
  'revive_charm': BattleItem(
    key: 'revive_charm',
    kind: BattleItemKind.medical,
    cureSteps: [CureStep.revitalize],
  ),
  // B6-05 — the magicless need a way to top up a caster.
  'sp_tonic': BattleItem(
    key: 'sp_tonic',
    kind: BattleItemKind.medical,
    spRestore: 30,
  ),
  // B6-03 — coatings. Three rounds each; see `coating.dart`.
  'poison_vial': BattleItem(
    key: 'poison_vial',
    kind: BattleItemKind.coating,
    coating: Coating.poison,
  ),
  'paralysis_vial': BattleItem(
    key: 'paralysis_vial',
    kind: BattleItemKind.coating,
    coating: Coating.paralysis,
  ),
  'fire_vial': BattleItem(
    key: 'fire_vial',
    kind: BattleItemKind.coating,
    coating: Coating.fire,
  ),
  'fire_crystal': BattleItem(
    key: 'fire_crystal',
    kind: BattleItemKind.crystal,
    damage: 40,
  ),
  'storm_crystal': BattleItem(
    key: 'storm_crystal',
    kind: BattleItemKind.crystal,
    damage: 18,
    hitsAll: true,
  ),
};

/// Which of [held] can actually be used right now.
List<String> usableItems(Map<String, int> held) => [
  for (final entry in held.entries)
    if (entry.value > 0 && battleItems.containsKey(entry.key)) entry.key,
]..sort();

/// **Items cost no spell points.** That is the whole point of carrying
/// them — a medical item works for a character with no magic at all,
/// which the cure spells refuse to do (appendix R-5).
const int itemSpellPointCost = 0;
