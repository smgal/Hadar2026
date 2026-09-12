import '../contract/battle_command.dart';
import 'attack_magic.dart';
import 'coating.dart';
import 'cure.dart';
import 'esp.dart';

/// The one skill list (B6-01), and what each id needs.
///
/// ## What changed in B6
///
/// The original encoded spells as five menu categories by id range
/// (`magic_system.dart` `castBattleSpellUI`), and the battle menu had a
/// line for each. B6 keeps the ids and the level gates and drops the
/// categories as a menu concept: a caster opens **one** list holding
/// everything they have learned, and each line says who it is aimed at
/// ([SkillScope]) and what it costs ([SkillResource]).
///
/// Two ids changed category on the way (B6-02): 13 (독) is now a coating
/// laid on the caster's own weapon, and 16 (능력 저하) is now ESP.
/// Nothing else moved and no id was renumbered.

/// Who a chosen skill needs pointed at.
enum SpellTargeting {
  /// The caster picks one enemy. The original left a placeholder in the
  /// command and let the battle ask next (`magic_system.dart:262-264`).
  singleEnemy,

  /// Every conscious enemy.
  allEnemies,

  /// One ally. The original never asked who (`magic_system.dart:268-270`);
  /// the cure goes to whoever needs it most (`Battle._cureTargetFor`).
  singleAlly,

  /// The whole party.
  allAllies,

  /// The caster's own weapon. Nothing to ask.
  selfWeapon,
}

/// Where a skill is aimed, by id.
SpellTargeting targetingFor(int magicId) {
  if (magicId == coatingSpellId) return SpellTargeting.selfWeapon;
  if (magicId >= 7 && magicId <= 12) return SpellTargeting.allEnemies;
  if (magicId >= 19 && magicId <= 25) return SpellTargeting.singleAlly;
  if (magicId >= 26 && magicId <= 32) return SpellTargeting.allAllies;
  return SpellTargeting.singleEnemy;
}

/// The poison spell, which B6-02 turned into a weapon coating.
const int coatingSpellId = 13;

/// 능력 저하 — a special spell by number, ESP by nature (B6-02).
///
/// Psychokinesis (45) already leaves `resistanceDown` · `enduranceDown` ·
/// `agilityDown` behind when it fails (`esp.dart`), so lowering a
/// creature's abilities was already something the mind did.
const int abilityDrainSpellId = 16;

/// ESP level at which 능력 저하 opens. The five ESP abilities open one per
/// level (41 at 1 … 45 at 5); this one sits at the top of that ladder.
const int abilityDrainEspLevel = 5;

/// The scope glyph the view puts in front of an id.
SkillScope scopeOf(int magicId) {
  if (magicId == coatingSpellId) return SkillScope.selfWeapon;
  if (magicId == abilityDrainSpellId) return SkillScope.oneEnemy;
  if (magicId >= 14 && magicId <= 18) return SkillScope.curse;
  return switch (targetingFor(magicId)) {
    SpellTargeting.singleEnemy => SkillScope.oneEnemy,
    SpellTargeting.allEnemies => SkillScope.allEnemies,
    SpellTargeting.singleAlly => SkillScope.oneAlly,
    SpellTargeting.allAllies => SkillScope.allAllies,
    SpellTargeting.selfWeapon => SkillScope.selfWeapon,
  };
}

/// Which pool an id spends from.
SkillResource resourceOf(int magicId) =>
    (magicId == abilityDrainSpellId || (magicId >= 41 && magicId <= 45))
    ? SkillResource.esp
    : SkillResource.sp;

/// Whether an id is one of the curses — special magic that stays special
/// after B6-02 moved 13 and 16 out.
bool isCurse(int magicId) =>
    magicId == 14 || magicId == 15 || magicId == 17 || magicId == 18;

/// The fixed cost of an id, or -1 when it depends on the cast.
///
/// Attack magic is charged per spell **per enemy** for the area range and
/// per target for the cures, so those cannot be priced before the cast
/// — the view shows `~` and the cast reports `NotEnoughSpellPoints` if
/// it runs dry.
int fixedCostOf(int magicId, {required int levelMagic}) {
  if (magicId == coatingSpellId) return coatingSpellCost;
  if (isCurse(magicId) || magicId == abilityDrainSpellId) {
    return debuffSpells[magicId]!.cost;
  }
  final group = magicGroupOf(magicId);
  if (group == MagicGroup.single) {
    return attackSpellCost(
      spellIndex: attackMagicCategories[group]!.indexOf(magicId),
      magicLevel: levelMagic,
    );
  }
  if (magicId >= 41 && magicId <= 45) {
    final ability = espAbilityFor(magicId);
    return ability == null ? 0 : espCost(ability);
  }
  return -1;
}

/// Whether the caster can pay for [magicId] right now.
///
/// Variable-cost skills are always "affordable" at selection time — the
/// cast itself pays step by step and reports when it cannot.
bool skillAffordable(
  int magicId, {
  required int levelMagic,
  required int sp,
  required int esp,
}) {
  final cost = fixedCostOf(magicId, levelMagic: levelMagic);
  if (cost < 0) return true;
  return resourceOf(magicId) == SkillResource.esp ? esp >= cost : sp >= cost;
}

/// Every id this caster has learned, in list order.
///
/// Order is by kind so the glyphs cluster: single attacks, area attacks,
/// the coating, curses, cures, ESP. The gates are the ones B2 ported —
/// tiers for attack magic (`attackMagicCategories`), the cure curves
/// (`castableCures`), one per level for ESP.
List<int> castableSkills({required int levelMagic, required int levelEsp}) {
  final ids = <int>[];
  ids.addAll(
    castableAttackSpells(attackMagicCategories[MagicGroup.single]!, levelMagic),
  );
  ids.addAll(
    castableAttackSpells(attackMagicCategories[MagicGroup.area]!, levelMagic),
  );
  // The special range keeps its gate; two of its members have moved.
  final special = castableAttackSpells(
    attackMagicCategories[MagicGroup.special]!,
    levelMagic,
  );
  if (special.contains(coatingSpellId)) ids.add(coatingSpellId);
  ids.addAll([
    for (final id in special)
      if (isCurse(id)) id,
  ]);
  ids.addAll(castableCures(magicLevel: levelMagic));
  // **The inert three do not appear.** 41 · 42 · 44 read the future,
  // read minds and see far — their effect is outside a fight, and the
  // original printed the name and returned. Offering them spends a turn
  // on nothing, which is the one thing B5 forbids: a wasted turn must
  // not be reachable through the menu.
  //
  // Spells 33-40 were left out for the same reason (B6-01); these three
  // are the same case and were missed. They are still field abilities.
  final espCount = levelEsp > 5 ? 5 : levelEsp;
  ids.addAll([
    for (var i = 0; i < espCount; i++)
      if (espAbilityFor(41 + i) != EspAbility.inert) 41 + i,
  ]);
  if (levelEsp >= abilityDrainEspLevel) ids.add(abilityDrainSpellId);
  return ids;
}

/// The list as the view receives it.
List<SkillOption> skillOptions({
  required int levelMagic,
  required int levelEsp,
  required int sp,
  required int esp,
}) => [
  for (final id in castableSkills(levelMagic: levelMagic, levelEsp: levelEsp))
    SkillOption(
      magicId: id,
      scope: scopeOf(id),
      resource: resourceOf(id),
      cost: fixedCostOf(id, levelMagic: levelMagic),
      affordable: skillAffordable(id, levelMagic: levelMagic, sp: sp, esp: esp),
    ),
];

/// **[해소됨]** The inherited port checked a flat cost and never
/// subtracted it, so combat magic was free (appendix O-1). B2-02 made
/// the cures spend, B2-01 the attack spells. Kept as a record.
const bool spendsCost = false;
