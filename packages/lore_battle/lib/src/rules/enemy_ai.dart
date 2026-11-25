import '../data/enemy_data.dart';
import 'rng.dart';

/// How an enemy decides what to do — ch.8.6.
///
/// Pure decisions: each function takes the numbers it needs and the
/// generator, and says what happens. `model/battle.dart` applies them.
/// One enemy's turn runs, in order:
///
/// 1. only a real enemy acts — an image (분신) does not
/// 2. one with supernatural abilities tries **one of them** first
/// 3. one with a special attack may use it instead of anything else
/// 4. otherwise weapon or magic, weighed by its two accuracies

/// What an enemy does with the rest of its turn.
enum EnemyIntent {
  /// Its single-target special attack.
  special,

  /// Swing whatever it has.
  weapon,

  /// Work down the casting ladder — see [chooseEnemySpell].
  cast,

  /// Nothing. A creature with no strength and no magic — the three
  /// healers — has no ordinary action at all.
  idle,
}

/// Steps 3 and 4.
///
/// The special attack fires on `rand(50) < min(agility, 20)` **and only
/// with four or more enemies still able to act**. That second half is
/// the original's and its intent is unclear (appendix A #19) — it means
/// a lone boss never uses its special attack. The chapter states it as
/// the rule, so it is the rule here; it is on the contract's
/// open-decision list.
///
/// Draws: one for the special roll, **only when there is a special
/// attack to roll for**; then two for the weapon-versus-magic weighing.
EnemyIntent chooseEnemyIntent({
  required EnemySpecial special,
  required int castLevel,
  required int strength,
  required int agility,
  required int accuracyPhysical,
  required int accuracyMagic,
  required int actingEnemies,
  required BattleRng rng,
}) {
  final capped = agility > 20 ? 20 : agility;
  if (special != EnemySpecial.none &&
      rng.next(50) < capped &&
      actingEnemies >= specialAttackQuorum) {
    return EnemyIntent.special;
  }
  // `rand(0)` is undefined, so the ranges carry a `+ 1`. It moves the
  // odds by one part in thousands.
  final favoursWeapon =
      rng.next(accuracyPhysical * 1000 + 1) >
      rng.next(accuracyMagic * 1000 + 1);
  if (favoursWeapon && strength > 0) return EnemyIntent.weapon;
  if (castLevel > 0) return EnemyIntent.cast;
  // No magic to fall back on: it swings if it can swing at all.
  return strength > 0 ? EnemyIntent.weapon : EnemyIntent.idle;
}

/// How many enemies have to be able to act before any of them uses a
/// special attack.
const int specialAttackQuorum = 4;

// --- special attacks ---------------------------------------------------

/// The roll each special attack has to pass — wider is harder to land.
int specialAttackRange(EnemySpecial special) => switch (special) {
  EnemySpecial.poison => 40,
  EnemySpecial.knockOut => 50,
  EnemySpecial.slay => 60,
  EnemySpecial.none => 1,
};

/// How a special attack turned out.
enum SpecialAttackOutcome {
  /// `rand(range) > enemy agility` — "독 공격은 실패했다".
  failed,

  /// `rand(20) < luck` — "그러나, {대원}는 독 공격을 피했다".
  evaded,

  applied,
}

/// Resolves a special attack against a chosen member. Two gates, in
/// this order: the enemy's agility, then the member's luck.
SpecialAttackOutcome resolveSpecialAttack(
  EnemySpecial special, {
  required int enemyAgility,
  required int targetLuck,
  required BattleRng rng,
}) {
  if (rng.next(specialAttackRange(special)) > enemyAgility) {
    return SpecialAttackOutcome.failed;
  }
  if (rng.next(20) < targetLuck) return SpecialAttackOutcome.evaded;
  return SpecialAttackOutcome.applied;
}

// --- enemy magic -------------------------------------------------------

/// The eleven spells an enemy casts. Names are the view's.
enum EnemySpellKind {
  // On one member.
  shock, // 충격
  chill, // 냉기
  pain, // 고통
  freeze, // 혹한
  flame, // 화염
  lightning, // 번개
  // On everyone.
  heatWave, // 열파
  energy, // 에너지
  ultrasonic, // 초음파
  coldSnap, // 혹한기
  fireStorm, // 화염폭풍
}

/// The spell an enemy throws at one member, and its coefficient, by
/// the enemy's mentality.
({EnemySpellKind kind, int coefficient}) enemySingleSpell(int mentality) {
  if (mentality <= 3) return (kind: EnemySpellKind.shock, coefficient: 1);
  if (mentality <= 8) return (kind: EnemySpellKind.chill, coefficient: 2);
  if (mentality <= 10) return (kind: EnemySpellKind.pain, coefficient: 4);
  if (mentality <= 14) return (kind: EnemySpellKind.freeze, coefficient: 6);
  if (mentality <= 18) return (kind: EnemySpellKind.flame, coefficient: 7);
  return (kind: EnemySpellKind.lightning, coefficient: 10);
}

/// The spell an enemy throws at the whole party.
({EnemySpellKind kind, int coefficient}) enemyAreaSpell(int mentality) {
  if (mentality <= 6) return (kind: EnemySpellKind.heatWave, coefficient: 1);
  if (mentality <= 12) return (kind: EnemySpellKind.energy, coefficient: 2);
  if (mentality <= 16) {
    return (kind: EnemySpellKind.ultrasonic, coefficient: 3);
  }
  if (mentality <= 20) return (kind: EnemySpellKind.coldSnap, coefficient: 5);
  return (kind: EnemySpellKind.fireStorm, coefficient: 8);
}

/// `coefficient × level × 5`.
int enemySpellPower({required int coefficient, required int level}) =>
    coefficient * level * 5;

/// `rand(20) >= magic accuracy` misses.
bool enemySpellMisses({required int accuracyMagic, required BattleRng rng}) =>
    rng.next(20) >= accuracyMagic;

/// `rand(50) < resistance` — the member shrugs the spell off. Rolled
/// against 50 where an enemy's resistance is rolled against 100, so a
/// member's resistance is worth twice the number.
bool memberResistsSpell({required int resistance, required BattleRng rng}) =>
    rng.next(50) < resistance;

/// `power − rand(power ÷ 2) − ac × level × (1..10) ÷ 10`.
int enemySpellDamage({
  required int power,
  required int memberAc,
  required int memberLevel,
  required BattleRng rng,
}) {
  final half = power ~/ 2;
  final spread = half < 1 ? 0 : rng.next(half);
  return power - spread - memberAc * memberLevel * (rng.next(10) + 1) ~/ 10;
}

/// Who a single spell is aimed at.
enum EnemySpellTarget {
  /// Any occupied seat, standing or not — cast level 1 does not look.
  anyPresent,

  /// A random member who can still act.
  randomConscious,

  /// The member with the fewest hit points among those who can act.
  weakestConscious,
}

/// What the casting ladder decided.
sealed class EnemySpellPlan {
  const EnemySpellPlan();
}

final class CastAtOne extends EnemySpellPlan {
  const CastAtOne(this.target);

  final EnemySpellTarget target;
}

final class CastAtAll extends EnemySpellPlan {
  const CastAtAll();
}

/// Heals itself, and that is its turn.
final class HealSelf extends EnemySpellPlan {
  const HealSelf(this.amount);

  final int amount;
}

/// Heals its whole side.
final class HealAllies extends EnemySpellPlan {
  const HealAllies(this.amount);

  final int amount;
}

/// 갑옷 파괴, from the top of the ladder.
final class BreakArmour extends EnemySpellPlan {
  const BreakArmour();
}

final class NoSpell extends EnemySpellPlan {
  const NoSpell();
}

/// The casting ladder — cast levels 0..6.
///
/// | level | behaviour |
/// |---|---|
/// | 0 | no magic |
/// | 1 | a single spell at any occupied seat, fallen or not |
/// | 2 | a single spell at someone who can act |
/// | 3 | `rand(able members) < 2` ? single : everyone |
/// | 4 | under 30% health, half the time heals itself (`level × mentality × 3`); else as 3 |
/// | 5 | under 30%, a third of the time heals itself. On a single turn: with three or more enemies and the side under a third of its health, half the time heals everyone (`level × mentality × 2`); else a single spell at **the weakest member**. On an area turn, everyone |
/// | 6 | under 40%, a third of the time heals itself. With the party's armour averaging over 4, one time in five breaks armour. With three or more enemies and the side under a third, two times in three heals everyone. Else single-at-the-weakest or everyone, as 5 |
EnemySpellPlan chooseEnemySpell({
  required int castLevel,
  required int hp,
  required int maxHp,
  required int level,
  required int mentality,
  required int ableMembers,
  required int enemyCount,
  required int totalEnemyHp,
  required int totalEnemyMaxHp,
  required int averagePartyAc,
  required BattleRng rng,
}) {
  if (castLevel <= 0) return const NoSpell();

  final selfHeal = HealSelf(level * mentality * 3);
  final allyHeal = HealAllies(level * mentality * 2);
  final sideIsFailing = enemyCount >= 3 && totalEnemyHp * 3 < totalEnemyMaxHp;
  bool singleTurn() => rng.next(ableMembers < 1 ? 1 : ableMembers) < 2;

  switch (castLevel) {
    case 1:
      return const CastAtOne(EnemySpellTarget.anyPresent);
    case 2:
      return const CastAtOne(EnemySpellTarget.randomConscious);
    case 3:
      return singleTurn()
          ? const CastAtOne(EnemySpellTarget.randomConscious)
          : const CastAtAll();
    case 4:
      if (hp * 10 < maxHp * 3 && rng.next(2) == 0) return selfHeal;
      return singleTurn()
          ? const CastAtOne(EnemySpellTarget.randomConscious)
          : const CastAtAll();
    case 5:
      if (hp * 10 < maxHp * 3 && rng.next(3) == 0) return selfHeal;
      if (!singleTurn()) return const CastAtAll();
      if (sideIsFailing && rng.next(2) == 0) return allyHeal;
      return const CastAtOne(EnemySpellTarget.weakestConscious);
    default:
      // 6, and anything an override pushed past it.
      if (hp * 10 < maxHp * 4 && rng.next(3) == 0) return selfHeal;
      if (averagePartyAc > 4 && rng.next(5) == 0) return const BreakArmour();
      if (sideIsFailing && rng.next(3) < 2) return allyHeal;
      return singleTurn()
          ? const CastAtOne(EnemySpellTarget.weakestConscious)
          : const CastAtAll();
  }
}

// --- Part 3's supernatural abilities -----------------------------------

/// 정신 지배 — one time in five. The caller has already checked that
/// there is an assistant to take and a line in the enemy list to put it
/// on.
bool mindControlFires(BattleRng rng) => rng.next(5) == 0;

/// 갑옷 파괴 — the party's armour has to average over 4, and then one
/// time in five.
bool armourBreakFires({required int averagePartyAc, required BattleRng rng}) =>
    averagePartyAc > 4 && rng.next(5) == 0;

/// `luck > rand(21)` saves one member's armour.
bool armourBreakResisted({required int luck, required BattleRng rng}) =>
    luck > rng.next(21);

/// 동료 소환 — when fewer than `rand(3) + 2` of its side can still act.
bool summonAllyFires({required int actingEnemies, required BattleRng rng}) =>
    actingEnemies < rng.next(3) + 2;

/// 전체 중독 · 기절 · 즉사 — only against a full party: `rand(3) + 5` or
/// more members able to act.
bool massStatusFires({required int ableMembers, required BattleRng rng}) =>
    ableMembers >= rng.next(3) + 5;

/// `rand(range) > luck` and the member is caught. The ranges shrink as
/// the effect gets worse, so death is the easiest to shrug off.
int massStatusRange(EnemyAbility ability) => switch (ability) {
  EnemyAbility.massPoison => 40,
  EnemyAbility.massStun => 30,
  EnemyAbility.massDeath => 22,
  _ => 1,
};

bool massStatusCatches({
  required EnemyAbility ability,
  required int luck,
  required BattleRng rng,
}) => rng.next(massStatusRange(ability)) > luck;

/// 전체 회복 restores `level × mentality × 4` to an enemy that is
/// standing. The fallen come back one stage instead (see the battle).
int healAllAmount({required int level, required int mentality}) =>
    level * mentality * 4;

/// Who 동료 소환 calls, by the caller's key — original numbers into
/// Part 3's table. Anyone not named calls one of the first fifteen.
const Map<String, List<int>> summonAllyCandidates = {
  'troll_necromancer': [1, 2, 3, 4, 5],
  'summoner_shaman': [6, 7, 8, 9, 10],
  'kobold_king': [39, 41],
  'summoner_dracon': [11, 12, 13, 14, 15],
  'draconian_king': [50],
  'lord_ahn': [71],
  'lord_ahn_795': [71],
};

const List<int> _defaultSummonAllies = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, //
];

/// Picks the original number of the enemy to call. One draw, unless
/// there is only one candidate.
int pickSummonedAlly(String casterKey, BattleRng rng) {
  final candidates = summonAllyCandidates[casterKey] ?? _defaultSummonAllies;
  return candidates.length == 1
      ? candidates.single
      : candidates[rng.next(candidates.length)];
}

// --- Parts 1 and 2: the supernatural grade -----------------------------

/// Grade 1 and up — calls reinforcements when its side has thinned out,
/// and then only one time in three.
bool gradeSummonFires({required int notDeadEnemies, required BattleRng rng}) {
  final threshold = rng.next(3) + 2;
  if (notDeadEnemies >= threshold) return false;
  return rng.next(3) == 0;
}

/// Who a graded enemy calls: a row 17 to 20 below its own number. Null
/// when that falls off the top of the table.
int? gradeSummonedLegacyId({
  required int casterLegacyId,
  required BattleRng rng,
}) {
  final id = casterLegacyId - 20 + rng.next(4);
  return id < 1 ? null : id;
}

/// Grade 2 and up — takes the assistant, when fewer than seven enemies
/// are left and one time in five.
bool gradeAbductFires({required int notDeadEnemies, required BattleRng rng}) =>
    notDeadEnemies < 7 && rng.next(5) == 0;

/// Grade 3 — death over the whole party, for a creature that has a
/// special attack at all, one time in five.
bool gradeMassSlayFires({
  required EnemySpecial special,
  required BattleRng rng,
}) => special != EnemySpecial.none && rng.next(5) == 0;
