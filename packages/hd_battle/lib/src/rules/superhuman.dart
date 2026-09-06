import 'rng.dart';

/// Superhuman casting — the extra turn a `specialCastLevel` enemy takes
/// (B2-11).
///
/// `enemyCastSpellWithSpecialAbility` stacks three tiers, and the lower
/// ones keep rolling at the higher levels. Two of them change the party
/// roster, which is why this is separate from B2-07.

/// One tier's decision.
enum SuperhumanTier {
  /// Level 1 and up — calls in reinforcements.
  summon,

  /// Level 2 and up — drags a party member over to the enemy side.
  abduct,

  /// Level 3 and up — a killing wave over the whole party.
  massSlay,
}

/// Whether the summon tier fires.
///
/// `num_not_dead < random(3) + 2 && random(3) == 0` — a thinned-out
/// group calls for help, and only sometimes.
bool summonFires({required int notDeadEnemies, required BattleRng rng}) {
  final threshold = rng.next(3) + 2;
  if (notDeadEnemies >= threshold) return false;
  return rng.next(3) == 0;
}

/// Which enemy gets called in — `ed_number + random(4) - 20`.
///
/// Twenty rows below itself, give or take three: a strong caster brings
/// weaker help. Returns null when that lands outside the table, which
/// **the original never checked**: an `ed_number` under 20 would index
/// negatively. Guarded here rather than ported (6th decision).
int? summonedLegacyId({
  required int casterLegacyId,
  required int tableSize,
  required BattleRng rng,
}) {
  final id = casterLegacyId + rng.next(4) - 20;
  if (id < 0 || id >= tableSize) return null;
  return id;
}

/// Whether the abduct tier fires.
///
/// `p_last_player->isValid() && num_not_dead < 7 && random(5) == 0`.
bool abductFires({
  required bool hasValidMember,
  required int notDeadEnemies,
  required BattleRng rng,
}) {
  if (!hasValidMember) return false;
  if (notDeadEnemies >= 7) return false;
  return rng.next(5) == 0;
}

/// Whether the mass-slay tier fires — `special != 0 && random(5) == 0`.
///
/// Note it needs an innate `special` as well as the cast level; a
/// superhuman caster with no special ability never reaches it.
bool massSlayFires({required int special, required BattleRng rng}) {
  if (special == 0) return false;
  return rng.next(5) == 0;
}

/// Highest tier this caster can reach.
List<SuperhumanTier> tiersFor({required int specialCastLevel}) => [
  if (specialCastLevel >= 1) SuperhumanTier.summon,
  if (specialCastLevel >= 2) SuperhumanTier.abduct,
  if (specialCastLevel >= 3) SuperhumanTier.massSlay,
];

/// How many enemies a battle will hold.
///
/// The original bounded summoning by `enemy.capacity()`, a C++ vector's
/// spare room — an implementation detail rather than a rule. A limit is
/// still needed or a level-1 superhuman caster can farm reinforcements
/// forever, so this is ours: three enemies for each one the battle
/// started with, and never fewer than eight.
int summonLimit({required int startingEnemies}) {
  final limit = startingEnemies * 3;
  return limit < 8 ? 8 : limit;
}

/// **Summoned enemies are worth no experience or gold.**
///
/// The original settled over whatever was in the enemy list at the end,
/// so reinforcements paid out like anything else — and a caster that
/// summons every round would pay out forever. Marked at the source and
/// excluded from the settlement instead.
const bool summonsCountTowardSpoils = false;
