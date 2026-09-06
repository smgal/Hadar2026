import '../contract/battle_setup.dart';
import '../rules/coating.dart';
import '../rules/condition.dart';
import '../rules/position.dart';
import '../rules/weapon.dart';

/// A party member for the duration of one battle.
///
/// Built from a [CombatantSnapshot] and thrown away when the battle
/// ends. Nothing here reaches back into the RPG's own party object; what
/// changed comes out through `BattleOutcome`.
class Combatant {
  Combatant.fromSnapshot(this.snapshot)
    : hp = snapshot.hp,
      sp = snapshot.sp,
      esp = snapshot.esp,
      poison = snapshot.poison,
      unconscious = snapshot.unconscious,
      dead = snapshot.dead,
      rank = clampRank(snapshot.rank);

  final CombatantSnapshot snapshot;

  int hp;
  int sp;
  int esp;
  int poison;
  int unconscious;
  int dead;

  /// Driven back this round and still off balance (B5-07).
  bool staggered = false;

  /// Standing firm this round (B5-03). Shield chance up sharply for the
  /// first blow, much less for the second, and cannot be pushed.
  bool braced = false;

  /// How many blows have already landed on them this round. What keeps
  /// a braced tank from being unhittable.
  int hitsThisRound = 0;

  /// Which rank they are standing in right now (B5-01).
  ///
  /// Starts from the snapshot and changes only as a consequence of an
  /// action — a charge, a knockback, the dodge-back passive. There is
  /// no positioning phase.
  int rank;

  /// True once a superhuman caster dragged them over to the enemy side
  /// (B2-11). Not a death — the slot is gone, and the outcome reports it
  /// in `departedSlots` so the RPG clears it.
  bool departed = false;

  /// What is on the weapon right now, if anything (B6-03). Counts down
  /// at the top of each round and is replaced, not stacked, by a new one.
  WeaponCoating? coating;

  /// Accumulated during the battle and reported per slot. The original
  /// wrote straight into the player's `experience` field, and did it in
  /// two different distributions — see [CombatantResult.experienceGained].
  int experienceGained = 0;

  int get slot => snapshot.slot;
  String get name => snapshot.name;

  /// What they are swinging (B5-02).
  WeaponProfile get weapon => weaponFor(snapshot.weaponKey);

  /// How much punishment this member absorbs once collapsed, before
  /// dying — `endurance x physical level`, the C++ tree's rule
  /// (`condition.dart`).
  int get deathThreshold => unconsciousDeathThreshold(
    endurance: snapshot.endurance,
    level: snapshot.levelPhysical,
  );

  /// The condition a status screen would show.
  Condition get condition =>
      conditionOf(hp: hp, poison: poison, unconscious: unconscious, dead: dead);

  /// `player.dart:209-213` — `isValid() && unconscious == 0 &&
  /// dead == 0 && hp > 0`, where validity is a non-empty name.
  bool get isConscious =>
      !departed && name.isNotEmpty && hp > 0 && unconscious == 0 && dead == 0;

  /// Still part of the party at all.
  bool get isPresent => !departed && name.isNotEmpty;

  CombatantResult toResult() => CombatantResult(
    slot: slot,
    hp: hp,
    sp: sp,
    esp: esp,
    poison: poison,
    unconscious: unconscious,
    dead: dead,
    experienceGained: experienceGained,
  );
}
