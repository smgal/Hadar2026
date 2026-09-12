import '../domain/character_class.dart';
import '../domain/equip_slot.dart';
import '../domain/ids.dart';
import '../domain/member.dart';
import '../domain/stats.dart';
import '../rules/fighting_style.dart';

/// A member as content describes one, before it becomes a [Member].
///
/// [nameKey] is a key. This package never holds a display name, so a
/// front end resolves it — the same rule the item catalogue follows.
class MemberTemplate {
  const MemberTemplate({
    required this.ref,
    required this.nameKey,
    required this.clazz,
    required this.stats,
    required this.levels,
    required this.accuracy,
    required this.maxHitPoints,
    this.maxSpellPoints = 0,
    this.maxEspPoints = 0,
    this.baseDefence = 0,
    this.gender = 0,
    this.equipment = const {},
  });

  final String ref;
  final String nameKey;
  final CharacterClass clazz;
  final BaseStats stats;
  final Levels levels;
  final Accuracy accuracy;
  final int maxHitPoints;
  final int maxSpellPoints;
  final int maxEspPoints;

  /// Protection without gear.
  final int baseDefence;

  /// Display data. 0 unspecified, 1 male, 2 female.
  final int gender;

  /// Slot to item ref, as plain strings so a template can be written
  /// without importing the catalogue.
  final Map<EquipSlot, String> equipment;

  Member build() => Member(
    ref: MemberRef(ref),
    name: nameKey,
    clazz: clazz,
    stats: stats,
    levels: levels,
    accuracy: accuracy,
    baseMaxHitPoints: maxHitPoints,
    baseMaxSpellPoints: maxSpellPoints,
    baseMaxEspPoints: maxEspPoints,
    baseDefence: baseDefence,
    gender: gender,
    style: defaultStyleFor(clazz),
    equipment: {
      for (final e in equipment.entries) e.key: ItemRef(e.value),
    },
  );
}

/// A party of five, one per fighting style worth showing.
///
/// ## Why five and not two
///
/// The battle package measured its balance against two-member fixtures
/// and the numbers turned out not to be representative — a five-member
/// party halves the round count and is the first size at which an
/// enemy's special ability can fire at all. Anything meant for testing
/// starts at five here so that mistake is not repeated.
const List<MemberTemplate> sampleParty = [
  MemberTemplate(
    ref: 'knight',
    nameKey: 'member.knight',
    clazz: CharacterClass.knight,
    stats: BaseStats(
      strength: 16,
      endurance: 16,
      agility: 10,
      resistance: 4,
      luck: 5,
    ),
    levels: Levels(physical: 3),
    accuracy: Accuracy(physical: 14),
    maxHitPoints: 240,
    equipment: {
      EquipSlot.rightHand: 'weapon.sabre',
      EquipSlot.leftHand: 'shield.small_steel',
      EquipSlot.body: 'bodyArmour.bronze',
    },
  ),
  MemberTemplate(
    ref: 'paladin',
    nameKey: 'member.paladin',
    clazz: CharacterClass.paladin,
    stats: BaseStats(
      strength: 14,
      mentality: 12,
      endurance: 14,
      agility: 11,
      luck: 4,
    ),
    levels: Levels(physical: 3, magic: 2),
    accuracy: Accuracy(physical: 12, magic: 10),
    maxHitPoints: 190,
    maxSpellPoints: 24,
    equipment: {
      EquipSlot.rightHand: 'weapon.short_spear',
      EquipSlot.leftHand: 'shield.leather',
      EquipSlot.body: 'bodyArmour.leather',
    },
  ),
  MemberTemplate(
    ref: 'swordman',
    nameKey: 'member.swordman',
    clazz: CharacterClass.swordman,
    stats: BaseStats(strength: 18, endurance: 13, agility: 14, luck: 3),
    levels: Levels(physical: 3),
    accuracy: Accuracy(physical: 15),
    maxHitPoints: 195,
    equipment: {
      EquipSlot.rightHand: 'weapon.long_sword',
      EquipSlot.body: 'bodyArmour.leather',
    },
  ),
  MemberTemplate(
    ref: 'magician',
    nameKey: 'member.magician',
    clazz: CharacterClass.magician,
    stats: BaseStats(
      strength: 8,
      mentality: 18,
      concentration: 12,
      endurance: 9,
      agility: 10,
      luck: 6,
    ),
    levels: Levels(physical: 3, magic: 4, esp: 1),
    accuracy: Accuracy(physical: 8, magic: 16, esp: 8),
    maxHitPoints: 68,
    maxSpellPoints: 72,
    maxEspPoints: 12,
    equipment: {
      EquipSlot.rightHand: 'weapon.long_staff',
      EquipSlot.body: 'bodyArmour.plain_clothes',
    },
  ),
  MemberTemplate(
    ref: 'hunter',
    nameKey: 'member.hunter',
    clazz: CharacterClass.hunter,
    stats: BaseStats(strength: 12, endurance: 11, agility: 17, luck: 8),
    levels: Levels(physical: 3),
    accuracy: Accuracy(physical: 16),
    maxHitPoints: 165,
    equipment: {
      EquipSlot.rightHand: 'weapon.bow',
      EquipSlot.body: 'bodyArmour.leather',
    },
  ),
];

/// What the sample party is carrying, as `{item ref: count}`.
///
/// Deliberately more than the slots can hold: an equipment screen is
/// only interesting when something has to be left in the pack.
const Map<String, int> samplePack = {
  'weapon.dagger': 1,
  'weapon.long_sword': 1,
  'weapon.gladius': 1,
  'weapon.hand_axe': 2,
  'weapon.war_hammer': 1,
  'weapon.halberd': 1,
  'weapon.cavalry_lance': 1,
  'weapon.knife': 2,
  'weapon.rapier': 1,
  'weapon.club': 1,
  'weapon.crossbow': 1,
  'weapon.arbalest': 1,
  'weapon.javelin': 3,
  'shield.leather': 1,
  'shield.large_steel': 1,
  'light.torch': 3,
  'bodyArmour.steel': 1,
  'helmet.leather_helm': 2,
  'boots.leather_shoes': 2,
  'commonAmulet.ward': 1,
  'commonAmulet.hawk': 1,
  'commonAmulet.water': 1,
  'commonAmulet.marsh': 1,
  'commonAmulet.levitation': 1,
  'classAmulet.oath_crest': 1,
  'classAmulet.quiver': 1,
  'classAmulet.casting_seal': 1,
  // 마실 것과 바를 것을 한 번씩은 써 볼 수 있는 양. 이전 모델의
  // `startingBackpack()` 과 같은 구성이다.
  'consumable.potion': 3,
  'consumable.antidote': 1,
  'consumable.sp_tonic': 1,
  'consumable.poison_vial': 2,
  'consumable.paralysis_vial': 1,
  'consumable.fire_vial': 1,
};
