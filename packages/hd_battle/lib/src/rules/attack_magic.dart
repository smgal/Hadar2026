import 'condition.dart';
import 'rng.dart';

/// The three ranges attack magic comes in. Before B6 these were keyed by
/// the menu action that opened them; the menu no longer has one line per
/// range, so the range has to have a name of its own.
enum MagicGroup { single, area, special }

/// Which group an id belongs to, or null for anything that is not attack
/// magic (cures, ESP, the out-of-battle spells).
MagicGroup? magicGroupOf(int magicId) {
  if (magicId >= 1 && magicId <= 6) return MagicGroup.single;
  if (magicId >= 7 && magicId <= 12) return MagicGroup.area;
  if (magicId >= 13 && magicId <= 18) return MagicGroup.special;
  return null;
}

/// Attack magic: the three offensive categories, 1-18.
///
/// ## The category boundaries were wrong
///
/// The inherited Dart port had them as 1-3 / 4-10 / 11-18
/// (`magic_system.dart:201-217`). The C++ battle menu builds each list
/// from `ixMagicOffset` of **0 / 6 / 12** and six entries each
/// (`hd_base_game_main.cpp`), so the real split is:
///
/// | category | ids | spells |
/// |---|---|---|
/// | single target | **1-6** | 마법 화살 · 마법 화구 · 마법 단창 · 독 바늘 · 맥동 광선 · 직격 뇌전 |
/// | all enemies | **7-12** | 공기 폭풍 · 열선 파동 · 초음파 · 초냉기 · 인공 지진 · 차원 이탈 |
/// | special | **13-18** | 독 · 기술 무력화 · 방어 무력화 · 능력 저하 · 마법 불능 · 탈 초인화 |
///
/// which is what the names say: a poison needle and a lightning bolt are
/// single targets, an air storm and an earthquake are not, and the last
/// six are the stat-drains (appendix Q-1). The old boundaries put
/// 독 바늘 in the area list and 인공 지진 in the debuff list.
///
/// Ids 33-40 remain unreachable from combat, and 41-45 are ESP (B2-10).
///
/// ## Everything below is per spell
///
/// The inherited port ran every spell in a category through one of two
/// formulas, so 마법 화살 and 직격 뇌전 hit identically. Here the
/// spell's **position in its category** drives both damage and cost.
class AttackMagicCategory {
  const AttackMagicCategory({
    required this.group,
    required this.minId,
    required this.maxId,
    required this.tiers,
  });

  final MagicGroup group;
  final int minId;
  final int maxId;

  /// `(magicLevel ceiling, spells offered)` pairs, lowest first. Above
  /// the last ceiling the whole category is offered.
  final List<(int, int)> tiers;

  int get size => maxId - minId + 1;

  /// 1-based position of [magicId] within this category, or 0 if it does
  /// not belong here. This is the `ix_object` the C++ formulas use.
  int indexOf(int magicId) =>
      (magicId < minId || magicId > maxId) ? 0 : magicId - minId + 1;
}

/// The level gates, from `hd_base_game_main.cpp` cases 2-4.
///
/// Tiered rather than "one spell per level" — the inherited port used
/// `available = level.magic` capped at the category size
/// (`magic_system.dart:225-227`), which handed a level-6 caster every
/// single-target spell it had.
const Map<MagicGroup, AttackMagicCategory> attackMagicCategories = {
  MagicGroup.single: AttackMagicCategory(
    group: MagicGroup.single,
    minId: 1,
    maxId: 6,
    tiers: [(1, 2), (3, 3), (7, 4), (11, 5), (15, 6)],
  ),
  MagicGroup.area: AttackMagicCategory(
    group: MagicGroup.area,
    minId: 7,
    maxId: 12,
    tiers: [(1, 1), (2, 2), (5, 3), (9, 4), (13, 5), (17, 6)],
  ),
  // The special six keep their gate, but B6-02 moved two of them out of
  // this group's *menu*: 13 became the weapon coating (cast on oneself)
  // and 16 became ESP. Their level gate still reads off this table —
  // `castableSkills` in `spellbook.dart` filters the two out.
  MagicGroup.special: AttackMagicCategory(
    group: MagicGroup.special,
    minId: 13,
    maxId: 18,
    tiers: [(4, 1), (9, 2), (11, 3), (13, 4), (15, 5), (17, 6)],
  ),
};

/// How many spells of [category] a caster at [magicLevel] may choose.
int attackSpellsEnabled(AttackMagicCategory category, int magicLevel) {
  for (final (ceiling, count) in category.tiers) {
    if (magicLevel <= ceiling) return count;
  }
  return category.size;
}

/// The spell ids this caster can pick from [category].
List<int> castableAttackSpells(AttackMagicCategory category, int magicLevel) {
  final count = attackSpellsEnabled(category, magicLevel);
  return [for (var i = 0; i < count; i++) category.minId + i];
}

// --- single and area attack magic ------------------------------------

/// Spell points one cast costs — `(index² × magicLevel + 1) / 2`.
///
/// From `castSpellToOne`. It grows quadratically with the spell's
/// position, so the strong end of a category is expensive, and it scales
/// with the caster's level so a stronger caster also pays more.
///
/// **This is spent for real.** The inherited port checked a flat
/// category cost and never subtracted it (appendix O-1), which made
/// combat magic free.
int attackSpellCost({required int spellIndex, required int magicLevel}) =>
    (spellIndex * spellIndex * magicLevel + 1) ~/ 2;

/// Base damage — `index² × magicLevel × 2`.
///
/// So within a category the last spell hits 36 times as hard as the
/// first. That spread is the whole point of having six of them.
int attackSpellPower({required int spellIndex, required int magicLevel}) =>
    spellIndex * spellIndex * magicLevel * 2;

/// Whether the cast goes wide — `random(20) >= accuracyMagic`.
///
/// Note the `>=`, where the physical roll uses `>`
/// (`physical.dart`). At the same accuracy value magic misses one draw
/// more often. The asymmetry is the original's, in both trees.
bool magicAttackMisses({required int accuracyMagic, required BattleRng rng}) =>
    rng.next(20) >= accuracyMagic;

/// The target's magic resistance roll — `random(100) < resistance`.
bool enemyResistsMagic({
  required int enemyResistance,
  required BattleRng rng,
}) => rng.next(100) < enemyResistance;

/// The armour term subtracted from spell damage.
///
/// `(ac × level × (random(10) + 1) + 5) / 10` — note the `+ 5`, which
/// rounds where the physical term truncates. Kept as it is; it makes
/// armour very slightly better against magic than against a weapon.
int magicDefence({
  required int enemyAc,
  required int enemyLevel,
  required BattleRng rng,
}) => (enemyAc * enemyLevel * (rng.next(10) + 1) + 5) ~/ 10;

// --- special magic 13-18 ---------------------------------------------

/// What a debuff spell did.
enum DebuffOutcome { resisted, missed, applied, notAffordable }

/// One special-magic spell's parameters.
///
/// All from `castSpellWithSpecialAbility` (appendix Q-1). Each has its
/// own spell-point cost and its own two roll ranges, and none of them
/// deal damage — they take an enemy's capabilities away.
class DebuffSpell {
  const DebuffSpell({
    required this.magicId,
    required this.cost,
    required this.resistRange,
    required this.accuracyRange,
  });

  final int magicId;

  /// Flat spell-point cost — these do not use [attackSpellCost].
  final int cost;

  /// `random(resistRange) < resistance` blocks the spell.
  final int resistRange;

  /// `random(accuracyRange) > accuracyMagic` misses. A wider range is a
  /// harder spell to land.
  final int accuracyRange;
}

/// 13-18, keyed by magic id.
const Map<int, DebuffSpell> debuffSpells = {
  13: DebuffSpell(magicId: 13, cost: 10, resistRange: 100, accuracyRange: 40),
  14: DebuffSpell(magicId: 14, cost: 30, resistRange: 100, accuracyRange: 60),
  15: DebuffSpell(magicId: 15, cost: 15, resistRange: 100, accuracyRange: 40),
  16: DebuffSpell(magicId: 16, cost: 20, resistRange: 200, accuracyRange: 30),
  17: DebuffSpell(magicId: 17, cost: 15, resistRange: 100, accuracyRange: 100),
  18: DebuffSpell(magicId: 18, cost: 20, resistRange: 100, accuracyRange: 100),
};

/// The enemy stats a debuff can change.
class EnemyStats {
  const EnemyStats({
    required this.ac,
    required this.resistance,
    required this.level,
    required this.castLevel,
    required this.specialCastLevel,
    required this.special,
    required this.poison,
  });

  final int ac;
  final int resistance;
  final int level;
  final int castLevel;
  final int specialCastLevel;
  final int special;
  final int poison;

  EnemyStats copyWith({
    int? ac,
    int? resistance,
    int? level,
    int? castLevel,
    int? specialCastLevel,
    int? special,
    int? poison,
  }) => EnemyStats(
    ac: ac ?? this.ac,
    resistance: resistance ?? this.resistance,
    level: level ?? this.level,
    castLevel: castLevel ?? this.castLevel,
    specialCastLevel: specialCastLevel ?? this.specialCastLevel,
    special: special ?? this.special,
    poison: poison ?? this.poison,
  );
}

/// Result of one debuff cast.
class DebuffResult {
  const DebuffResult({
    required this.stats,
    required this.outcome,
    required this.spSpent,
  });

  final EnemyStats stats;
  final DebuffOutcome outcome;
  final int spSpent;
}

/// Casts one of 13-18.
///
/// The accuracy range for 방어 무력화 (15) depends on the target: a
/// lightly armoured enemy is easier to strip (`ac < 5 ? 40 : 25`).
///
/// Every reduction goes through [reduceStat], which is where the C++
/// tree's two unclamped `resistance -= 10` sites are fixed
/// (appendix Q-4).
DebuffResult castDebuff(
  int magicId, {
  required EnemyStats stats,
  required int accuracyMagic,
  required int casterSp,
  required BattleRng rng,
}) {
  final spell = debuffSpells[magicId]!;
  if (casterSp < spell.cost) {
    return DebuffResult(
      stats: stats,
      outcome: DebuffOutcome.notAffordable,
      spSpent: 0,
    );
  }
  // The cost is paid before the rolls, as in the original — a blocked
  // spell still costs.
  if (rng.next(spell.resistRange) < stats.resistance) {
    return DebuffResult(
      stats: stats,
      outcome: DebuffOutcome.resisted,
      spSpent: spell.cost,
    );
  }
  final accuracyRange = magicId == 15
      ? (stats.ac < 5 ? 40 : 25)
      : spell.accuracyRange;
  if (rng.next(accuracyRange) > accuracyMagic) {
    return DebuffResult(
      stats: stats,
      outcome: DebuffOutcome.missed,
      spSpent: spell.cost,
    );
  }

  final EnemyStats next;
  switch (magicId) {
    case 13: // 독 — stacks, so repeated casts hurt more per round.
      next = stats.copyWith(poison: stats.poison + 1);
    case 14: // 기술 무력화 — removes the special ability outright.
      next = stats.copyWith(special: 0);
    case 15: // 방어 무력화 — armour, or resistance on a resistant target.
      if (stats.resistance < 31 || rng.next(2) == 0) {
        next = stats.copyWith(ac: reduceStat(stats.ac, 1));
      } else {
        next = stats.copyWith(resistance: reduceStat(stats.resistance, 10));
      }
    case 16: // 능력 저하 — level and resistance together.
      next = stats.copyWith(
        level: reduceStat(stats.level, 1, floor: 1),
        resistance: reduceStat(stats.resistance, 10),
      );
    case 17: // 마법 불능
      next = stats.copyWith(castLevel: reduceStat(stats.castLevel, 1));
    case 18: // 탈 초인화
      next = stats.copyWith(
        specialCastLevel: reduceStat(stats.specialCastLevel, 1),
      );
    default:
      throw ArgumentError('$magicId is not a special-magic id');
  }
  return DebuffResult(
    stats: next,
    outcome: DebuffOutcome.applied,
    spSpent: spell.cost,
  );
}
