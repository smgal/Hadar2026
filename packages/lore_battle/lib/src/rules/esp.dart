import '../model/enemy_instance.dart';
import 'condition.dart';
import 'rng.dart';

/// ESP in battle — ch.9.6.
///
/// Six abilities, each gated on its own 초자연력 threshold rather than
/// on a tier of ten, and all paid from the same magic pool as spells.
/// 투시 · 예언 · 천리안 are field abilities and are **not here**: used
/// in battle they only say they cannot be, which is a turn spent on
/// nothing, so the menu never offers them.
enum EspAbility {
  /// 독심 — talks one enemy round. It leaves the fight and becomes the
  /// party's assistant member.
  persuade,

  /// 수소 핵융합 — damage to every enemy, no roll to hit or resist.
  fusion,

  /// 공포 생성 — frightens one enemy off the field, or leaves a mark.
  fear,

  /// 환상 생성 — dulls one enemy's aim and footing.
  illusion,

  /// 신진 대사 조절 — poisons one enemy, or tears into one already
  /// poisoned.
  metabolism,

  /// 유체 이탈 — drops one enemy where it stands, or nearly.
  astral,
}

/// One ability's gate and price.
class EspSpec {
  const EspSpec({
    required this.ability,
    required this.requiredSkill,
    required this.cost,
  });

  final EspAbility ability;

  /// The 초자연력 it needs.
  final int requiredSkill;

  final int cost;
}

/// The table, from ch.9.6, in the order the list shows them: 독심
/// first, then the five under 염력 by rising threshold.
const List<EspSpec> espSpecs = [
  EspSpec(ability: EspAbility.persuade, requiredSkill: 40, cost: 15),
  EspSpec(ability: EspAbility.fusion, requiredSkill: 20, cost: 100),
  EspSpec(ability: EspAbility.fear, requiredSkill: 30, cost: 100),
  EspSpec(ability: EspAbility.illusion, requiredSkill: 80, cost: 300),
  EspSpec(ability: EspAbility.metabolism, requiredSkill: 90, cost: 500),
  EspSpec(ability: EspAbility.astral, requiredSkill: 100, cost: 1000),
];

EspSpec espSpecOf(EspAbility ability) =>
    espSpecs.firstWhere((s) => s.ability == ability);

/// The abilities an ESP skill value opens.
List<EspAbility> espAbilitiesFor(int espSkill) => [
  for (final spec in espSpecs)
    if (espSkill >= spec.requiredSkill) spec.ability,
];

// --- 독심 --------------------------------------------------------------

/// How a persuasion attempt ended.
enum PersuadeOutcome {
  /// Not one of the creatures that can be talked to at all.
  immune,

  /// The enemy outranks the caster and the coin went against them —
  /// "아직 능력이 부족했다".
  outmatched,

  /// The persuasion roll failed.
  unmoved,

  /// "적은 우리의 편이 되었다".
  recruited,
}

/// Resolves 독심 against one enemy.
///
/// Two gates, in the document's order:
///
/// 1. `enemy level > caster level` → half the time it simply fails.
/// 2. `rand(60) <= (caster level − enemy level) × 2 + concentration`
///    succeeds — the level gap counts double.
///
/// An immune target draws nothing.
PersuadeOutcome resolvePersuade({
  required bool persuadable,
  required int enemyLevel,
  required int casterLevel,
  required int concentration,
  required BattleRng rng,
}) {
  if (!persuadable) return PersuadeOutcome.immune;
  if (enemyLevel > casterLevel && rng.next(2) == 0) {
    return PersuadeOutcome.outmatched;
  }
  if (rng.next(60) <= (casterLevel - enemyLevel) * 2 + concentration) {
    return PersuadeOutcome.recruited;
  }
  return PersuadeOutcome.unmoved;
}

// --- 수소 핵융합 --------------------------------------------------------

/// `concentration × level`, to each enemy.
int fusionDamage({required int concentration, required int level}) =>
    concentration * level;

/// The two lines the original picks between (우라늄 핵분열 / 수소
/// 핵융합). The model only draws the number.
const int fusionFlavours = 2;

// --- 공포 · 환상 · 신진 대사 · 유체 이탈 --------------------------------

/// What one of the four single-target abilities did.
enum EspEffect {
  /// Nothing took hold.
  none,

  /// Both resistances dropped.
  resistanceLowered,

  /// Endurance dropped.
  enduranceLowered,

  /// It ran. Gone from the field; the caster is paid for it.
  fled,

  /// Both accuracies dropped.
  accuracyLowered,

  /// Agility dropped.
  agilityLowered,

  /// Both accuracies and agility dropped — 환상's two rolls both came
  /// good.
  accuracyAndAgilityLowered,

  /// It is poisoned now.
  poisoned,

  /// A flat 5000 — the caller applies it as damage.
  heavyDamage,

  /// Dropped outright — hit points to zero, unconscious.
  struckDown,
}

/// The flat damage 신진 대사 조절 and 유체 이탈 deal.
const int espHeavyDamage = 5000;

/// 공포 생성.
///
/// `rand(40) < magic resistance` → both resistances −5. Otherwise
/// `rand(60) > concentration` → endurance −5. Otherwise it flees.
/// **Every branch leaves a mark**, which is what keeps a bad roll from
/// being a wasted turn.
EspEffect castFear({
  required EnemyInstance target,
  required int concentration,
  required BattleRng rng,
}) {
  if (rng.next(40) < target.magicResistance) {
    target.physicalResistance = reduceStat(target.physicalResistance, 5);
    target.magicResistance = reduceStat(target.magicResistance, 5);
    return EspEffect.resistanceLowered;
  }
  if (rng.next(60) > concentration) {
    target.endurance = reduceStat(target.endurance, 5);
    return EspEffect.enduranceLowered;
  }
  return EspEffect.fled;
}

/// 환상 생성.
///
/// Two independent rolls, both always taken: `rand(30) < concentration`
/// → both accuracies −4, and `rand(40) < magic resistance` → agility −5.
EspEffect castIllusion({
  required EnemyInstance target,
  required int concentration,
  required BattleRng rng,
}) {
  final dulled = rng.next(30) < concentration;
  final slowed = rng.next(40) < target.magicResistance;
  if (dulled) {
    target.accuracyPhysical = reduceStat(target.accuracyPhysical, 4);
    target.accuracyMagic = reduceStat(target.accuracyMagic, 4);
  }
  if (slowed) target.agility = reduceStat(target.agility, 5);
  if (dulled && slowed) return EspEffect.accuracyAndAgilityLowered;
  if (dulled) return EspEffect.accuracyLowered;
  if (slowed) return EspEffect.agilityLowered;
  return EspEffect.none;
}

/// 신진 대사 조절.
///
/// `rand(40) > concentration` fails. Otherwise an enemy that is already
/// poisoned takes 5000, and one that is not is poisoned.
EspEffect castMetabolism({
  required EnemyInstance target,
  required int concentration,
  required BattleRng rng,
}) {
  if (rng.next(40) > concentration) return EspEffect.none;
  if (target.poison > 0) return EspEffect.heavyDamage;
  target.poison = 1;
  return EspEffect.poisoned;
}

/// 유체 이탈.
///
/// `rand(40) < magic resistance` → both resistances −20. Otherwise
/// `rand(80) > concentration` → 5000 damage. Otherwise it drops where it
/// stands — hit points to zero, and the caster is paid as for any
/// knock-out (the original did neither, appendix A #38).
EspEffect castAstral({
  required EnemyInstance target,
  required int concentration,
  required BattleRng rng,
}) {
  if (rng.next(40) < target.magicResistance) {
    target.physicalResistance = reduceStat(target.physicalResistance, 20);
    target.magicResistance = reduceStat(target.magicResistance, 20);
    return EspEffect.resistanceLowered;
  }
  if (rng.next(80) > concentration) return EspEffect.heavyDamage;
  return EspEffect.struckDown;
}
