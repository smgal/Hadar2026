import '../contract/battle_setup.dart';
import '../data/enemy_data.dart';
import '../rules/affinity.dart';
import '../rules/condition.dart';
import '../rules/position.dart';
import '../rules/weapon.dart';

/// One enemy in one battle.
///
/// Stats are copied out of the table rather than read through it: the
/// special spells and ESP change them for the rest of the fight
/// (ch.9.5, ch.9.6), and an [EnemyOverride] may have changed them
/// before it began.
class EnemyInstance {
  EnemyInstance(
    this.data, {
    required this.episode,
    EnemyOverride? override,
    int? rank,
  }) : nameKey = override?.nameKey ?? data.key,
       displayName = override?.displayName,
       level = override?.level ?? data.level,
       strength = override?.strength ?? data.strength,
       mentality = override?.mentality ?? data.mentality,
       endurance = override?.endurance ?? data.endurance,
       physicalResistance =
           override?.physicalResistance ?? data.physicalResistance,
       magicResistance = override?.magicResistance ?? data.magicResistance,
       agility = override?.agility ?? data.agility,
       accuracyPhysical = override?.accuracyPhysical ?? data.accuracyPhysical,
       accuracyMagic = override?.accuracyMagic ?? data.accuracyMagic,
       ac = override?.ac ?? data.ac,
       special = override?.special ?? data.special,
       castLevel = override?.castLevel ?? data.castLevel,
       abilities = {...(override?.abilities ?? data.abilities)},
       superLevel = override?.superLevel ?? data.superLevel,
       persuadable = override?.persuadable ?? data.persuadable,
       persuadeLevel = override?.persuadeLevel ?? data.persuadeLevel,
       rewardLevel = override?.rewardLevel,
       rewardAc = override?.rewardAc,
       givesGold = override?.givesGold ?? data.givesGold,
       poison = override?.poison ?? 0,
       unconscious = override?.unconscious ?? 0,
       dead = override?.dead ?? 0,
       hp = 0,
       rank = 1 {
    // Hit points follow the level unless the override pins them: a row
    // fielded at another level is recomputed, a row fielded as it is
    // keeps the document's own figure.
    final rescaled = override?.level != null || override?.endurance != null;
    hp =
        override?.hp ??
        (rescaled
            ? enemyMaxHp(endurance: endurance, level: level, episode: episode)
            : data.hp);
    this.rank =
        rank ??
        defaultEnemyRank(
          strength: strength,
          castLevel: castLevel,
          specialCastLevel: abilities.isNotEmpty ? 1 : superLevel,
          agility: agility,
        );
  }

  /// A false image of [real] — same numbers, one hit point (ch.8.6
  /// 분신). It never acts and pays nothing.
  factory EnemyInstance.cloneOf(EnemyInstance real) {
    final clone = EnemyInstance(
      real.data,
      episode: real.episode,
      override: real._liveOverride(),
      rank: real.rank,
    );
    clone
      ..isClone = true
      ..cloneOwner = real
      ..abilities.clear()
      ..superLevel = 0
      ..hp = 1
      ..poison = 0
      ..unconscious = 0
      ..dead = 0;
    return clone;
  }

  final EnemyData data;
  final int episode;

  /// What the text package should call it — the row's key, or the
  /// override's alias.
  final String nameKey;

  /// A literal name the RPG supplied. Wins over [nameKey].
  final String? displayName;

  int level;
  int strength;
  int mentality;
  int endurance;
  int physicalResistance;
  int magicResistance;
  int agility;
  int accuracyPhysical;
  int accuracyMagic;
  int ac;
  EnemySpecial special;
  int castLevel;
  final Set<EnemyAbility> abilities;
  int superLevel;
  bool persuadable;
  int? persuadeLevel;
  int? rewardLevel;
  int? rewardAc;
  bool givesGold;

  int hp;
  int poison;

  /// A flag for enemies, not a counter: an unconscious enemy that is
  /// struck again is finished outright (ch.8.5 step 2).
  int unconscious;
  int dead;

  /// Which rank it stands in. The encounter may say; otherwise
  /// [defaultEnemyRank] reads it off what the creature is.
  int rank;

  /// Driven back this round and still off balance. Cleared at the top
  /// of the next round.
  bool staggered = false;

  /// One of the images a 분신 user hides among.
  bool isClone = false;

  /// The real one a clone copies.
  EnemyInstance? cloneOwner;

  /// Called in mid-battle by 동료 소환.
  bool summoned = false;

  /// Ran from 공포 생성. Gone from the field; not a death.
  bool fled = false;

  /// Talked round by 독심 and now sitting in the party's sixth seat.
  bool recruited = false;

  /// Was the party's assistant until 정신 지배 took it. Pays no gold.
  bool wasAssistant = false;

  String get key => data.key;

  /// No longer on the field for a reason other than falling.
  bool get hasLeft => fled || recruited;

  bool get isConscious => !hasLeft && hp > 0 && unconscious == 0 && dead == 0;

  /// Still a body on the field — standing or unconscious.
  bool get isPresent => !hasLeft && dead == 0;

  /// Whether it takes turns at all. Images do not.
  bool get acts => !isClone;

  bool get hasSupernatural => abilities.isNotEmpty || superLevel > 0;

  /// Whether the enemy list should draw it the way it draws an image:
  /// always in the "full health" colour, so the real one cannot be told
  /// from its copies by how hurt it is (ch.8.7).
  bool get showsAsClone => isClone || abilities.contains(EnemyAbility.clone);

  /// Reads the live numbers, so 능력 저하 lowers it too.
  int get maxHp =>
      enemyMaxHp(endurance: endurance, level: level, episode: episode);

  /// The level experience is worked out from.
  int get experienceLevel => rewardLevel ?? level;

  /// The armour class gold is worked out from.
  int get goldAc => rewardAc ?? ac;

  /// The level 독심 measures the caster against.
  int get levelForPersuasion => persuadeLevel ?? level;

  bool get paysGold => givesGold && !isClone && !recruited && !wasAssistant;

  bool get paysExperience => !isClone;

  /// What this creature fights with. Belongs to the creature rather
  /// than to an equipment slot.
  WeaponProfile get weapon =>
      weaponFor(enemyWeaponKey(key: data.key, strength: strength));

  /// Its affinity chart, read off the **table row** — what it is made
  /// of does not change when a spell lowers its numbers.
  Affinity get affinity => affinityFor(
    key: data.key,
    strength: data.strength,
    ac: data.ac,
    agility: data.agility,
    endurance: data.endurance,
  );

  Condition get condition =>
      conditionOf(hp: hp, poison: poison, unconscious: unconscious, dead: dead);

  /// Puts an image back the way it was made.
  void resetClone() {
    hp = 1;
    poison = 0;
    unconscious = 0;
    dead = 0;
    staggered = false;
  }

  EnemyOverride _liveOverride() => EnemyOverride(
    nameKey: nameKey == data.key ? null : nameKey,
    displayName: displayName,
    level: level,
    hp: hp,
    strength: strength,
    mentality: mentality,
    endurance: endurance,
    physicalResistance: physicalResistance,
    magicResistance: magicResistance,
    agility: agility,
    accuracyPhysical: accuracyPhysical,
    accuracyMagic: accuracyMagic,
    ac: ac,
    special: special,
    castLevel: castLevel,
    abilities: {...abilities},
    superLevel: superLevel,
    persuadable: persuadable,
    persuadeLevel: persuadeLevel,
    rewardLevel: rewardLevel,
    rewardAc: rewardAc,
    givesGold: givesGold,
    poison: poison,
    unconscious: unconscious,
    dead: dead,
  );

  /// Where it stands now, for [BattleOutcome.enemies].
  EnemyState toState() => EnemyState(
    key: data.key,
    hp: hp,
    unconscious: unconscious,
    dead: dead,
    left: hasLeft || isClone,
    resume: _liveOverride(),
  );
}
