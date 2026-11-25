import '../contract/battle_setup.dart';
import '../contract/vocabulary.dart';
import '../rules/condition.dart';
import '../rules/position.dart';
import '../rules/weapon.dart';

/// A party member for the duration of one battle.
///
/// Built from a [CombatantSnapshot] and thrown away when the battle
/// ends. Nothing here reaches back into the RPG's own party object;
/// what changed comes out through `BattleOutcome`.
class Combatant {
  Combatant.fromSnapshot(this.snapshot, {this.joinedInBattle = false})
    : hp = snapshot.hp,
      mp = snapshot.mp,
      ac = snapshot.ac,
      poison = snapshot.poison,
      unconscious = snapshot.unconscious,
      dead = snapshot.dead,
      rank = clampRank(snapshot.rank);

  final CombatantSnapshot snapshot;

  /// True for an assistant the battle itself seated — a summon, a
  /// crystal creature, a persuaded enemy. The outcome hands these back
  /// as a full snapshot rather than a result row.
  final bool joinedInBattle;

  int hp;
  int mp;

  /// Live armour class. 갑옷 파괴 lowers it, and [acLoss] remembers by
  /// how much so the RPG can make it permanent.
  int ac;
  int acLoss = 0;

  int poison;
  int unconscious;
  int dead;

  /// Driven back this round and still off balance.
  bool staggered = false;

  /// Standing firm this round. The guard goes up sharply for the first
  /// blow, much less for the second, and they cannot be pushed.
  bool braced = false;

  /// How many blows have already landed on them this round. What keeps
  /// a braced tank from being unhittable.
  int hitsThisRound = 0;

  /// Which rank they are standing in right now. Starts from the
  /// snapshot and changes only as a consequence of an action.
  int rank;

  /// True once 정신 지배 took them over to the enemy side. Not a death —
  /// the seat is empty.
  bool departed = false;

  /// Accumulated during the battle and reported per seat.
  int experienceGained = 0;

  int get slot => snapshot.slot;
  String get name => snapshot.name;

  bool get isAssistant => slot == assistantSeat;

  /// What they are swinging.
  WeaponProfile get weapon => weaponFor(snapshot.weaponKey);

  /// How much punishment they absorb once unconscious, before dying —
  /// `endurance × level` (ch.7.7).
  int get deathThreshold => unconsciousDeathThreshold(
    endurance: snapshot.endurance,
    level: snapshot.level,
  );

  /// The condition a status screen would show.
  Condition get condition =>
      conditionOf(hp: hp, poison: poison, unconscious: unconscious, dead: dead);

  /// Still part of the party at all.
  bool get isPresent => !departed;

  /// "행동 가능" (ch.7.7): present, not unconscious, not dead, hit
  /// points above zero.
  bool get isConscious => !departed && hp > 0 && unconscious == 0 && dead == 0;

  CombatantResult toResult() => CombatantResult(
    slot: slot,
    hp: hp,
    mp: mp,
    poison: poison,
    unconscious: unconscious,
    dead: dead,
    experienceGained: experienceGained,
    acLoss: acLoss,
  );

  /// Where they stand now, as a snapshot — what the RPG seats when the
  /// battle created them.
  CombatantSnapshot toSnapshot() => CombatantSnapshot(
    slot: slot,
    name: snapshot.name,
    nameKey: snapshot.nameKey,
    family: snapshot.family,
    classId: snapshot.classId,
    level: snapshot.level,
    strength: snapshot.strength,
    mentality: snapshot.mentality,
    concentration: snapshot.concentration,
    endurance: snapshot.endurance,
    resistance: snapshot.resistance,
    agility: snapshot.agility,
    accuracy: snapshot.accuracy,
    luck: snapshot.luck,
    skills: snapshot.skills,
    hp: hp,
    maxHp: snapshot.maxHp,
    mp: mp,
    maxMp: snapshot.maxMp,
    ac: ac,
    weaponPower: snapshot.weaponPower,
    weaponKind: snapshot.weaponKind,
    shieldPower: snapshot.shieldPower,
    poison: poison,
    unconscious: unconscious,
    dead: dead,
    rank: rank,
    weaponKey: snapshot.weaponKey,
    weaponName: snapshot.weaponName,
    weaponNameKey: snapshot.weaponNameKey,
    attacksAll: snapshot.attacksAll,
    immuneToMindControl: snapshot.immuneToMindControl,
    weakTo: snapshot.weakTo,
    dodgesBack: snapshot.dodgesBack,
    preset: snapshot.preset,
    knownPresets: snapshot.knownPresets,
  );
}
