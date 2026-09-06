import 'rng.dart';

/// What an enemy decided to do this turn.
enum EnemyIntent {
  /// Swing whatever it has.
  weapon,

  /// Work down the casting ladder — see [chooseEnemySpell].
  cast,

  /// Use its innate special ability ([EnemySpecial]).
  special,
}

/// The dispatcher, from `hd_class_pc_enemy.cpp` `PcEnemy::attack`.
///
/// ```cpp
/// if (special_cast_level > 0)
///     enemyCastSpellWithSpecialAbility(p_enemy);   // no return
/// int agility = min(agility, 20);
/// if ((special > 0) && (random(50) < agility)) {
///     if (getNumOfConsciousPlayer() > 3) { enemyAttackWithSpecialAbility(...); return; }
/// }
/// if ((random(acc[0]*1000) > random(acc[1]*1000)) && strength > 0)
///     enemyAttackWithWeapon(...);
/// else if (cast_level > 0) enemyCastSpell(...);
/// else                     enemyAttackWithWeapon(...);
/// ```
///
/// Two things the inherited Dart port lost:
///
/// * **A `special_cast_level` enemy acts twice.** The superhuman cast has
///   no `return` after it, so the enemy then takes a normal turn as
///   well. That field had zero readers in the port (appendix O), and
///   this is what it was for. The superhuman cast itself is B2-11 — it
///   summons and abducts, which changes the roster.
/// * **The special-ability attack needs four conscious party members.**
///   With the two-member starting party it can never fire, which is a
///   large part of why enemies felt flat.
///
/// [agilityCap] is the original's `if (agility > 20) agility = 20`.
EnemyIntent chooseEnemyIntent({
  required int special,
  required int castLevel,
  required int strength,
  required int agility,
  required int accuracyPhysical,
  required int accuracyMagical,
  required int consciousPlayers,
  required BattleRng rng,
}) {
  final capped = agility > 20 ? 20 : agility;
  if (special > 0 && rng.next(50) < capped && consciousPlayers > 3) {
    return EnemyIntent.special;
  }
  // `random(0)` would throw in Dart, so the ranges keep the `+ 1` the
  // port added. It shifts the odds by one draw in a million; the shape
  // is the original's.
  final favoursWeapon =
      rng.next(accuracyPhysical * 1000 + 1) >
      rng.next(accuracyMagical * 1000 + 1);
  if (favoursWeapon && strength > 0) return EnemyIntent.weapon;
  return castLevel > 0 ? EnemyIntent.cast : EnemyIntent.weapon;
}

/// Whether the enemy also gets a superhuman cast before its normal turn.
bool hasSuperhumanTurn({required int specialCastLevel}) => specialCastLevel > 0;

/// Who a spell is aimed at.
enum EnemySpellTarget {
  /// Any party slot at all, conscious or not — `cast_level` 1 picks
  /// blind and only retries once.
  anyone,

  /// A random conscious member.
  randomConscious,

  /// The conscious member with the fewest hit points.
  weakestConscious,

  /// Everybody.
  everyone,
}

/// What the casting ladder decided.
sealed class EnemySpellPlan {
  const EnemySpellPlan();
}

/// Attack one party member.
final class CastAtOne extends EnemySpellPlan {
  const CastAtOne(this.target);

  final EnemySpellTarget target;
}

/// Attack the whole party.
final class CastAtAll extends EnemySpellPlan {
  const CastAtAll();
}

/// Patch itself up.
final class HealSelf extends EnemySpellPlan {
  const HealSelf(this.amount);

  final int amount;
}

/// Patch up every ally, itself included. Reviving is part of it — see
/// [enemyCureTargetsDead].
final class HealAllies extends EnemySpellPlan {
  const HealAllies(this.amount);

  final int amount;
}

/// Wear the party's armour down — `cast_level` 6 only.
final class StripArmour extends EnemySpellPlan {
  const StripArmour();
}

/// Nothing happened.
final class NoSpell extends EnemySpellPlan {
  const NoSpell();
}

/// How much an enemy cure restores.
///
/// `level × mentality / 4` on itself, `/ 6` on an ally — an enemy looks
/// after itself better than its friends.
int enemyCureAmount({
  required int level,
  required int mentality,
  required bool onSelf,
}) => level * mentality ~/ (onSelf ? 4 : 6);

/// An enemy cure reaches the dead: it clears `dead` first, then
/// `unconscious`, and only heals hit points on a target that is standing
/// (`enemyCastCureSpell`). So **enemies revive their fallen allies**,
/// one stage per cast, exactly like the party's own revive chain
/// (`rules/cure.dart`).
const bool enemyCureTargetsDead = true;

/// The casting ladder, from `enemyCastSpell`.
///
/// | cast_level | behaviour |
/// |---|---|
/// | 1 | blind single target, one retry if it picked someone out cold |
/// | 2 | random conscious target |
/// | 3 | `random(conscious) < 2` ? single : the whole party |
/// | 4 | below a third of its health, coin(2) to heal itself; else as 3 |
/// | 5 | as 4 with coin(3), and can heal **all** its allies when the group is under a third; single targets pick the weakest |
/// | 6 | as 5, plus a coin(5) chance to grind the party's armour down when they are well armoured |
///
/// The health test is `hp < endurance × level / 3` — a third of the
/// maximum, since maximum hit points *are* `endurance × level` here.
EnemySpellPlan chooseEnemySpell({
  required int castLevel,
  required int hp,
  required int endurance,
  required int level,
  required int mentality,
  required int consciousPlayers,
  required int enemyCount,
  required int totalEnemyHp,
  required int totalEnemyMaxHp,
  required int averagePartyAc,
  required BattleRng rng,
}) {
  if (castLevel <= 0) return const NoSpell();

  final hurt = hp < endurance * level ~/ 3;
  final selfHeal = HealSelf(
    enemyCureAmount(level: level, mentality: mentality, onSelf: true),
  );
  final allyHeal = HealAllies(
    enemyCureAmount(level: level, mentality: mentality, onSelf: false),
  );

  switch (castLevel) {
    case 1:
      return const CastAtOne(EnemySpellTarget.anyone);
    case 2:
      return const CastAtOne(EnemySpellTarget.randomConscious);
    case 3:
      return rng.next(consciousPlayers < 1 ? 1 : consciousPlayers) < 2
          ? const CastAtOne(EnemySpellTarget.randomConscious)
          : const CastAtAll();
    case 4:
      if (hurt && rng.next(2) == 0) return selfHeal;
      return rng.next(consciousPlayers < 1 ? 1 : consciousPlayers) < 2
          ? const CastAtOne(EnemySpellTarget.randomConscious)
          : const CastAtAll();
    case 5:
      if (hurt && rng.next(3) == 0) return selfHeal;
      if (rng.next(consciousPlayers < 1 ? 1 : consciousPlayers) >= 2) {
        return const CastAtAll();
      }
      if (enemyCount > 2 &&
          totalEnemyHp * 3 < totalEnemyMaxHp &&
          rng.next(2) == 0) {
        return allyHeal;
      }
      return const CastAtOne(EnemySpellTarget.weakestConscious);
    default:
      // 6 and anything above it.
      if (hurt && rng.next(3) == 0) return selfHeal;
      if (averagePartyAc > 4 && rng.next(5) == 0) return const StripArmour();
      if (enemyCount > 2 &&
          totalEnemyHp * 3 < totalEnemyMaxHp &&
          rng.next(3) == 0) {
        return allyHeal;
      }
      return rng.next(consciousPlayers < 1 ? 1 : consciousPlayers) < 2
          ? const CastAtOne(EnemySpellTarget.weakestConscious)
          : const CastAtAll();
  }
}

/// Whether one party member's armour survives the level-6 grind.
///
/// `random(21) < luck` saves them. **Luck finally does something** — the
/// inherited port read it only in the escape formula.
bool armourGrindResisted({required int luck, required BattleRng rng}) =>
    luck > rng.next(21);

// --- innate special abilities ----------------------------------------

/// The three innate abilities, keyed by `PcEnemy.special`.
enum EnemySpecial {
  /// 1 — poisons someone who is not already poisoned.
  poison,

  /// 2 — puts someone out cold outright.
  knockOut,

  /// 3 — kills outright, and will finish someone already down.
  slay,
}

EnemySpecial? enemySpecialFor(int special) => switch (special) {
  1 => EnemySpecial.poison,
  2 => EnemySpecial.knockOut,
  3 => EnemySpecial.slay,
  _ => null,
};

/// How an innate ability turned out.
enum SpecialAbilityOutcome { noTarget, missed, luckSaved, applied }

/// The roll ranges, from `enemyAttackWithSpecialAbility`. A wider range
/// is a harder ability to land.
int specialAbilityRange(EnemySpecial ability) => switch (ability) {
  EnemySpecial.poison => 40,
  EnemySpecial.knockOut => 50,
  EnemySpecial.slay => 60,
};

/// Whether the ability may target someone already unconscious.
///
/// Only [EnemySpecial.slay] does — it uses `PLAYERSTATUS_NOT_DEAD` where
/// the other two use `PLAYERSTATUS_CONSCIOUS`. So a downed party member
/// is not safe from it, which is the second half of what makes the
/// two-stage collapse (B2-04) matter.
bool specialAbilityHitsDowned(EnemySpecial ability) =>
    ability == EnemySpecial.slay;

/// Resolves one innate ability against a chosen target.
///
/// Two gates, in this order: the enemy's own agility against the
/// ability's range, then the target's luck against `random(20)`.
SpecialAbilityOutcome resolveSpecialAbility(
  EnemySpecial ability, {
  required int enemyAgility,
  required int targetLuck,
  required BattleRng rng,
}) {
  if (rng.next(specialAbilityRange(ability)) > enemyAgility) {
    return SpecialAbilityOutcome.missed;
  }
  if (rng.next(20) < targetLuck) return SpecialAbilityOutcome.luckSaved;
  return SpecialAbilityOutcome.applied;
}

/// How many candidates the poison ability tries before giving up.
///
/// It re-rolls looking for someone not already poisoned
/// (`for (int i = 0; i < 5; i++)`), so a party that is already poisoned
/// all over shrugs it off.
const int poisonTargetAttempts = 5;
