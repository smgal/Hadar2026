import 'character_class.dart';
import 'equip_slot.dart';
import 'fighting_style.dart';
import 'ids.dart';
import 'stats.dart';

/// One party member.
///
/// ## What is stored and what is not
///
/// Stored: who they are, what they carry, and the three pools that go
/// up and down. **Not stored**: anything that can be computed from
/// those plus the catalogue — the fighting style, the final defence
/// number, what the party can walk on. Every one of those is a
/// function, so none of them can drift out of date. The predecessor
/// stored derived party abilities in a `PartyBuffs` object and three of
/// its four fields ended up written by nothing or read by nothing.
class Member {
  Member({
    required this.ref,
    required this.name,
    this.clazz = CharacterClass.unknown,
    this.stats = const BaseStats(),
    this.levels = const Levels(),
    this.accuracy = const Accuracy(),
    this.baseMaxHitPoints = 0,
    this.baseMaxSpellPoints = 0,
    this.baseMaxEspPoints = 0,
    this.baseDefence = 0,
    this.style = FightingStyle.assault,
    this.thrift = false,
    int? hitPoints,
    int? spellPoints,
    int? espPoints,
    this.poison = 0,
    this.unconscious = 0,
    this.dead = 0,
    this.experience = 0,
    this.gender = 0,
    Map<EquipSlot, ItemRef>? equipment,
  }) : hitPoints = hitPoints ?? baseMaxHitPoints,
       spellPoints = spellPoints ?? baseMaxSpellPoints,
       espPoints = espPoints ?? baseMaxEspPoints,
       equipment = {...?equipment};

  final MemberRef ref;

  /// The display name. Player-entered data, not a literal in this
  /// package.
  String name;

  CharacterClass clazz;
  BaseStats stats;
  Levels levels;
  Accuracy accuracy;

  /// Maxima before equipment. See [vitalityFor] for how a new character
  /// would get these.
  int baseMaxHitPoints;
  int baseMaxSpellPoints;
  int baseMaxEspPoints;

  /// Protection this member has without wearing anything.
  ///
  /// Toughness rather than gear — hide, training, a body that is simply
  /// harder to hurt. Stored like the maxima above, because nothing can
  /// derive it: the previous model called it `baseAc` and the starting
  /// party leaned on it for most of its defence.
  int baseDefence;

  int hitPoints;
  int spellPoints;
  int espPoints;

  /// How badly poisoned. Survives a fight and decays with rest, which is
  /// why it lives here rather than in the battle.
  int poison;

  /// Collapsed, and how long for.
  int unconscious;

  /// Dead. Distinct from collapsed: a collapsed member can be brought
  /// round, a dead one has to be raised.
  int dead;

  /// Accumulated. **The world owns levelling** — a battle reports what
  /// was earned and deliberately carries no ladder of its own.
  int experience;

  /// Display data. 0 unspecified, 1 male, 2 female, the original's
  /// numbering.
  int gender;

  /// The standing order this member acts on when the leader hands the
  /// round over. Chosen from a list, never written as conditions.
  FightingStyle style;

  /// Spare the spell points: a toggle over whatever [style] is, not a
  /// style of its own.
  bool thrift;

  /// What is worn, by slot. An absent key is an empty slot.
  final Map<EquipSlot, ItemRef> equipment;

  ItemRef? at(EquipSlot slot) => equipment[slot];

  ClassType get classType => classTypeOf(clazz);

  /// Able to act. The conditions in the order they override each other,
  /// as the original had them.
  bool get isConscious =>
      name.isNotEmpty && hitPoints > 0 && unconscious == 0 && dead == 0;

  /// Still part of the party at all.
  bool get isPresent => name.isNotEmpty;

  /// What a status screen would show.
  MemberCondition get condition {
    if (dead > 0) return MemberCondition.dead;
    if (unconscious > 0) return MemberCondition.unconscious;
    if (poison > 0) return MemberCondition.poisoned;
    return MemberCondition.well;
  }
}

/// The four states a status screen tells apart.
///
/// Ordered worst first, the way the checks cascade: being dead hides
/// being poisoned, and nothing is two of these at once.
enum MemberCondition { dead, unconscious, poisoned, well }
