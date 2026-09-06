import '../data/enemy_table.dart';
import '../rules/condition.dart';
import '../rules/position.dart';
import '../rules/preset.dart';
import '../rules/weapon.dart';
import '../rules/vitals.dart';

/// One enemy in one battle.
///
/// Stats are copied out of the table rather than read through it,
/// because the original let scripts change them mid-battle
/// (`Enemy::ChangeAttribute`, `script_engine_adapter.dart:509-510`).
class EnemyInstance {
  EnemyInstance(this.data, {int? rank})
    : rank =
          rank ??
          defaultEnemyRank(
            strength: data.strength,
            castLevel: data.castLevel,
            specialCastLevel: data.specialCastLevel,
            agility: data.agility,
          ),
      strength = data.strength,
      mentality = data.mentality,
      endurance = data.endurance,
      resistance = data.resistance,
      agility = data.agility,
      accuracy = List<int>.from(data.accuracy),
      ac = data.ac,
      special = data.special,
      castLevel = data.castLevel,
      specialCastLevel = data.specialCastLevel,
      level = data.level,
      hp = enemyInitialHp(endurance: data.endurance, level: data.level);

  final EnemyData data;

  /// True when a superhuman caster called this one in mid-battle
  /// (B2-11). Excluded from the victory settlement — see
  /// `summonsCountTowardSpoils`.
  bool summoned = false;

  int strength;
  int mentality;
  int endurance;
  int resistance;
  int agility;
  List<int> accuracy;
  int ac;
  int special;
  int castLevel;
  int specialCastLevel;
  int level;

  int hp;

  /// Which rank it stands in (B5-01). The encounter may say; otherwise
  /// [defaultEnemyRank] reads it off what the creature is.
  int rank;

  /// Driven back this round and still off balance (B5-06 · B5-07).
  ///
  /// Cleared at the top of its own side's next round. Synergy hangs off
  /// this state rather than off turn order, so a follow-up works no
  /// matter who moves first.
  bool staggered = false;

  int poison = 0;
  int unconscious = 0;
  int dead = 0;

  /// A paralytic coating took hold (B6-03): the next time this creature's
  /// turn comes up it does nothing, and the flag clears. Deliberately not
  /// a [Condition] — the original's four are kept as they are, and this
  /// is a consequence of a coating, not a state a status screen names.
  bool paralyzed = false;

  String get key => data.key;

  /// The standing orders this creature runs (B5-08).
  ///
  /// Derived from what it is; a handful are named by hand.
  Preset get preset => presetOf(
    enemyPreset(
      key: data.key,
      strength: data.strength,
      agility: data.agility,
      endurance: data.endurance,
      castLevel: data.castLevel,
      specialCastLevel: data.specialCastLevel,
      level: data.level,
    ),
  );

  /// What this creature fights with (B5-02). Belongs to the creature
  /// rather than to an equipment slot — an ogre's club is not something
  /// it could put down.
  WeaponProfile get weapon => weaponFor(
    enemyWeaponKey(
      key: data.key,
      strength: data.strength,
      agility: data.agility,
    ),
  );
  String get name => data.name;

  /// `enemy.dart:45-47`.
  bool get isConscious => hp > 0 && unconscious == 0 && dead == 0;

  /// Same rule the party uses. Reads the **live** [endurance] and
  /// [level], so the ability-drain spell (magic 16, which lowers
  /// `level`) also makes
  /// the target easier to finish off.
  int get deathThreshold =>
      unconsciousDeathThreshold(endurance: endurance, level: level);

  Condition get condition =>
      conditionOf(hp: hp, poison: poison, unconscious: unconscious, dead: dead);
}
