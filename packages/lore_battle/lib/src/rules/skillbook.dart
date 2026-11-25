import '../contract/battle_command.dart';
import '../contract/battle_setup.dart';
import 'attack_magic.dart';
import 'cure.dart';
import 'esp.dart';
import 'special_magic.dart';
import 'summon.dart';

/// The one skill list, and what each id needs.
///
/// ## The id scheme
///
/// `category × 100 + tier`:
///
/// | ids | what |
/// |---|---|
/// | 101..110 | attack magic on one enemy, tier 1..10 |
/// | 201..210 | attack magic on every enemy, tier 1..10 |
/// | 300 | 독 — Part 1 only |
/// | 301..305 | special magic on one enemy |
/// | 306..310 | the same five on every enemy |
/// | 401..405 | cure one member |
/// | 406..410 | cure everyone |
/// | 501..506 | ESP: 독심 · 수소 핵융합 · 공포 생성 · 환상 생성 · 신진 대사 조절 · 유체 이탈 |
/// | 601..610 | summon, tier 1..10 |
///
/// Arithmetic, so nothing has to be looked up to read one, and the ids
/// cannot collide with `hd_battle`'s 1..45 by accident.

/// Builds an id.
int skillId(SkillCategory category, int tier) => category.hundreds * 100 + tier;

/// Part 1's 독, the one special spell outside the five-by-two grid.
const int partOnePoisonSkillId = 300;

/// The category an id belongs to, or null for a number that is not a
/// skill.
SkillCategory? categoryOfSkill(int id) {
  final hundreds = id ~/ 100;
  final tier = id % 100;
  for (final category in SkillCategory.values) {
    if (category.hundreds != hundreds) continue;
    final max = category == SkillCategory.esp ? espSpecs.length : 10;
    final min = category == SkillCategory.special ? 0 : 1;
    return tier >= min && tier <= max ? category : null;
  }
  return null;
}

/// The tier within its category, 1..10 (0 for Part 1's 독).
int tierOfSkill(int id) => id % 100;

/// The ESP ability an id casts.
EspAbility espAbilityOfSkill(int id) => espSpecs[tierOfSkill(id) - 1].ability;

/// The id an ESP ability is cast by.
int skillIdOfEsp(EspAbility ability) => skillId(
  SkillCategory.esp,
  espSpecs.indexWhere((s) => s.ability == ability) + 1,
);

/// The special spell an id casts.
SpecialKind specialKindOfSkill(int id) => id == partOnePoisonSkillId
    ? SpecialKind.poison
    : specialKindOfTier(tierOfSkill(id));

/// Who a chosen skill needs pointed at.
enum SkillTargeting {
  /// The caster picks one enemy next.
  singleEnemy,

  /// Every enemy; nothing to ask.
  allEnemies,

  /// The caster picks one ally next.
  singleAlly,

  /// The whole party.
  allAllies,

  /// Nothing to aim — a summon goes to the sixth seat.
  none,
}

SkillTargeting targetingOf(int id) {
  final tier = tierOfSkill(id);
  return switch (categoryOfSkill(id)) {
    SkillCategory.attackOne => SkillTargeting.singleEnemy,
    SkillCategory.attackAll => SkillTargeting.allEnemies,
    SkillCategory.special =>
      specialTierHitsAll(tier)
          ? SkillTargeting.allEnemies
          : SkillTargeting.singleEnemy,
    SkillCategory.cure =>
      cureTierTargetsAll(tier)
          ? SkillTargeting.allAllies
          : SkillTargeting.singleAlly,
    SkillCategory.esp =>
      espAbilityOfSkill(id) == EspAbility.fusion
          ? SkillTargeting.allEnemies
          : SkillTargeting.singleEnemy,
    SkillCategory.summon || null => SkillTargeting.none,
  };
}

/// The scope the view puts in front of an id.
SkillScope scopeOf(int id) => switch (categoryOfSkill(id)) {
  SkillCategory.special =>
    specialTierHitsAll(tierOfSkill(id))
        ? SkillScope.curseAll
        : SkillScope.curse,
  SkillCategory.summon || null => SkillScope.summon,
  _ => switch (targetingOf(id)) {
    SkillTargeting.singleEnemy => SkillScope.oneEnemy,
    SkillTargeting.allEnemies => SkillScope.allEnemies,
    SkillTargeting.singleAlly => SkillScope.oneAlly,
    SkillTargeting.allAllies => SkillScope.allAllies,
    SkillTargeting.none => SkillScope.summon,
  },
};

SkillResource resourceOf(int id) => categoryOfSkill(id) == SkillCategory.esp
    ? SkillResource.esp
    : SkillResource.mp;

/// What one cast costs, and whether that is per target.
///
/// -1 when it cannot be known before the target is — waking is priced
/// by the unconscious counter, raising by the death counter (ch.9.4).
({int cost, bool perTarget}) costOf(int id, CombatantSnapshot caster) {
  final tier = tierOfSkill(id);
  switch (categoryOfSkill(id)) {
    case SkillCategory.attackOne:
      return (
        cost: attackMagicCost(skill: caster.attackSkill, tier: tier),
        perTarget: false,
      );
    case SkillCategory.attackAll:
      return (
        cost: attackMagicCost(skill: caster.attackSkill, tier: tier),
        perTarget: true,
      );
    case SkillCategory.special:
      return (
        cost: specialSpells[specialKindOfSkill(id)]!.cost,
        perTarget: specialTierHitsAll(tier),
      );
    case SkillCategory.cure:
      final all = cureTierTargetsAll(tier);
      return switch ((tier - 1) % 5) {
        0 => (cost: caster.level * 2, perTarget: all),
        1 => (cost: 15, perTarget: all),
        _ => (cost: -1, perTarget: all),
      };
    case SkillCategory.esp:
      return (cost: espSpecOf(espAbilityOfSkill(id)).cost, perTarget: false);
    case SkillCategory.summon:
      return (
        cost: summonCost(skill: caster.summonSkill, tier: tier),
        perTarget: false,
      );
    case null:
      return (cost: -1, perTarget: false);
  }
}

/// Every id this member has learned, in list order: single attacks,
/// area attacks, special magic, cures, ESP, summons.
///
/// A fighter's list is empty and the menu then has no skill line at
/// all — the original showed the lines and quietly swung the weapon
/// instead (ch.8.4). A paladin's holds cures and nothing else.
///
/// Part 1's 독 is listed only when [episode] is 1, at the head of the
/// special magic, once any special magic is open.
List<int> castableSkills(CombatantSnapshot member, {required int episode}) {
  final ids = <int>[];
  final attack = tiersOpened(member.attackSkill);
  for (var tier = 1; tier <= attack; tier++) {
    ids.add(skillId(SkillCategory.attackOne, tier));
  }
  for (var tier = 1; tier <= attack; tier++) {
    ids.add(skillId(SkillCategory.attackAll, tier));
  }
  final special = tiersOpened(member.specialSkill);
  if (episode == 1 && special >= 1) ids.add(partOnePoisonSkillId);
  for (var tier = 1; tier <= special; tier++) {
    ids.add(skillId(SkillCategory.special, tier));
  }
  for (final tier in castableCureTiers(member.cureSkill)) {
    ids.add(skillId(SkillCategory.cure, tier));
  }
  for (final ability in espAbilitiesFor(member.espSkill)) {
    ids.add(skillIdOfEsp(ability));
  }
  for (final tier in castableSummonTiers(member.summonSkill)) {
    ids.add(skillId(SkillCategory.summon, tier));
  }
  return ids;
}

/// The list as the view receives it. [mp] is what the caster holds
/// right now, which may be less than the snapshot's.
List<SkillOption> skillOptions(
  CombatantSnapshot member, {
  required int mp,
  required int episode,
}) => [
  for (final id in castableSkills(member, episode: episode))
    () {
      final price = costOf(id, member);
      return SkillOption(
        magicId: id,
        category: categoryOfSkill(id)!,
        tier: tierOfSkill(id),
        scope: scopeOf(id),
        resource: resourceOf(id),
        cost: price.cost,
        perTarget: price.perTarget,
        // A cost that depends on the target is settled when the spell
        // lands; it cannot be refused up front.
        affordable: price.cost < 0 || mp >= price.cost,
      );
    }(),
];
