import '../contract/vocabulary.dart';
import 'affinity.dart';
import 'position.dart';

/// What a weapon can do, and how far — carried over from `hd_battle`.
///
/// ## Two worlds share a weapon
///
/// The RPG says **how hard** it hits (`weaponPower`, which in this
/// system even depends on the wielder's class) and which skill it is
/// measured by (`weaponKind`). The battle says **how it reaches** — the
/// row here, picked by `weaponKey`. The design documents have no reach
/// at all; this table is the fork's inherited layer, and it is why the
/// trilogy's 28 weapons are not listed one by one: several of them
/// reach the same way.
///
/// ## Minimum reach is what keeps this from degenerating
///
/// Without it, reach is strictly dominant: the long side holds the gap
/// with one turn while the short side loses all of theirs. With a
/// minimum, the long side wants the gap open and the short side wants
/// it closed, and neither is right in general.
///
/// ## No sidearm slot
///
/// A pike-wielder who cannot act at gap 0 is a wasted turn, and wasted
/// turns are the one thing this skeleton does not allow. So every long
/// weapon carries a **close-quarters method of its own** — the shaft of
/// the spear.

/// How a blow is delivered. Feeds the affinity chart.
enum AttackMethod { slash, pierce, blunt }

Element elementOfMethod(AttackMethod method) => switch (method) {
  AttackMethod.slash => Element.slash,
  AttackMethod.pierce => Element.pierce,
  AttackMethod.blunt => Element.blunt,
};

/// One way of using a weapon.
class WeaponAttack {
  const WeaponAttack({
    required this.method,
    required this.minReach,
    required this.maxReach,
    this.power = 100,
    this.charge = false,
    this.elementOverride,
  });

  final AttackMethod method;

  /// Closest distance this works at.
  final int minReach;

  /// Furthest distance this works at.
  final int maxReach;

  /// Percentage applied to the attack's base damage. The backup method
  /// of a long weapon is deliberately weak.
  final int power;

  /// Whether this can be used to close and strike in one action.
  final bool charge;

  /// For a natural weapon that is not a blade, a point or a weight — a
  /// flame, a breath. The element it goes through the chart with.
  final Element? elementOverride;

  Element get element => elementOverride ?? elementOfMethod(method);

  bool covers(int distance) => distance >= minReach && distance <= maxReach;

  /// How many steps outside the band [distance] is. 0 when it fits.
  int shortfall(int distance) {
    if (distance < minReach) return minReach - distance;
    if (distance > maxReach) return distance - maxReach;
    return 0;
  }
}

/// A weapon: one or two ways of using it.
class WeaponProfile {
  const WeaponProfile({required this.key, required this.attacks});

  final String key;

  /// Primary first. The second, when there is one, is the close-in
  /// answer that keeps a long weapon from ever wasting a turn.
  final List<WeaponAttack> attacks;

  /// The furthest anything on this weapon reaches.
  int get longestReach =>
      attacks.map((a) => a.maxReach).reduce((a, b) => a > b ? a : b);

  bool get canCharge => attacks.any((a) => a.charge);
}

/// Picks the way to use a weapon at a given distance.
///
/// Anything that fits wins, strongest first. Nothing fits and it falls
/// to whichever is least far outside its band. **Always returns
/// something.**
WeaponAttack chooseAttack(WeaponProfile weapon, int distance) {
  WeaponAttack? best;
  for (final attack in weapon.attacks) {
    if (!attack.covers(distance)) continue;
    if (best == null || attack.power > best.power) best = attack;
  }
  if (best != null) return best;
  for (final attack in weapon.attacks) {
    if (best == null || attack.shortfall(distance) < best.shortfall(distance)) {
      best = attack;
    }
  }
  return best!;
}

const WeaponAttack _shaft = WeaponAttack(
  method: AttackMethod.blunt,
  minReach: 0,
  maxReach: 1,
  power: 60,
);

/// The weapons the battle knows about.
///
/// The first block is `hd_battle`'s table, row for row. The second adds
/// what the trilogy's armoury needs that had no row, and the third the
/// natural weapons an assistant member fights with.
const Map<String, WeaponProfile> weaponTable = {
  'unarmed': WeaponProfile(
    key: 'unarmed',
    attacks: [
      WeaponAttack(method: AttackMethod.blunt, minReach: 0, maxReach: 1),
    ],
  ),
  'dagger': WeaponProfile(
    key: 'dagger',
    attacks: [
      WeaponAttack(method: AttackMethod.pierce, minReach: 0, maxReach: 1),
    ],
  ),
  'club': WeaponProfile(
    key: 'club',
    attacks: [
      WeaponAttack(method: AttackMethod.blunt, minReach: 0, maxReach: 1),
    ],
  ),
  'mace': WeaponProfile(
    key: 'mace',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 110,
      ),
    ],
  ),
  'staff': WeaponProfile(
    key: 'staff',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 2,
        power: 80,
      ),
    ],
  ),
  'long_sword': WeaponProfile(
    key: 'long_sword',
    attacks: [
      WeaponAttack(method: AttackMethod.slash, minReach: 1, maxReach: 2),
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 0,
        maxReach: 1,
        power: 70,
      ),
    ],
  ),
  'flame_sword': WeaponProfile(
    key: 'flame_sword',
    attacks: [
      WeaponAttack(
        method: AttackMethod.slash,
        minReach: 1,
        maxReach: 2,
        power: 110,
      ),
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 0,
        maxReach: 1,
        power: 70,
      ),
    ],
  ),
  'halberd': WeaponProfile(
    key: 'halberd',
    attacks: [
      WeaponAttack(method: AttackMethod.pierce, minReach: 1, maxReach: 2),
      // The shaft. Weak, but it means the turn is never lost.
      _shaft,
    ],
  ),
  'poleaxe': WeaponProfile(
    key: 'poleaxe',
    attacks: [
      WeaponAttack(method: AttackMethod.slash, minReach: 1, maxReach: 2),
      _shaft,
    ],
  ),
  'trident': WeaponProfile(
    key: 'trident',
    attacks: [
      WeaponAttack(method: AttackMethod.pierce, minReach: 1, maxReach: 2),
      _shaft,
    ],
  ),
  'lance': WeaponProfile(
    key: 'lance',
    attacks: [
      // The longest thing in the game, and it charges. Its own minimum
      // is what balances that: close with it and you are holding the
      // wrong weapon.
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 2,
        maxReach: 3,
        power: 120,
        charge: true,
      ),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 50,
      ),
    ],
  ),
  'great_sword': WeaponProfile(
    key: 'great_sword',
    attacks: [
      WeaponAttack(
        method: AttackMethod.slash,
        minReach: 1,
        maxReach: 2,
        power: 115,
        charge: true,
      ),
      _shaft,
    ],
  ),
  'one_hand_slash': WeaponProfile(
    key: 'one_hand_slash',
    attacks: [
      WeaponAttack(method: AttackMethod.slash, minReach: 0, maxReach: 1),
    ],
  ),
  'sword_shield': WeaponProfile(
    key: 'sword_shield',
    attacks: [
      WeaponAttack(method: AttackMethod.slash, minReach: 0, maxReach: 1),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 0,
        power: 55,
      ),
    ],
  ),
  'spear': WeaponProfile(
    key: 'spear',
    attacks: [
      WeaponAttack(method: AttackMethod.pierce, minReach: 1, maxReach: 2),
      _shaft,
    ],
  ),
  'war_hammer': WeaponProfile(
    key: 'war_hammer',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 120,
        charge: true,
      ),
    ],
  ),
  'bow': WeaponProfile(
    key: 'bow',
    attacks: [
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 1,
        maxReach: 3,
        power: 90,
      ),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 0,
        power: 40,
      ),
    ],
  ),
  'crossbow': WeaponProfile(
    key: 'crossbow',
    attacks: [
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 0,
        maxReach: 3,
        power: 85,
      ),
    ],
  ),
  'arbalest': WeaponProfile(
    key: 'arbalest',
    attacks: [
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 2,
        maxReach: 3,
        power: 130,
      ),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 45,
      ),
    ],
  ),
  'thrown': WeaponProfile(
    key: 'thrown',
    attacks: [
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 1,
        maxReach: 2,
        power: 70,
      ),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 0,
        power: 40,
      ),
    ],
  ),

  // --- the trilogy's armoury ----------------------------------------
  //
  // Ch.10.2 lists 28 weapons in four kinds. Most reach the way a row
  // above already does; these are the ones that did not have one.

  /// 소형 도끼. Chopped with, so it is a 찍는 weapon by skill — but an
  /// edge by what it does to flesh.
  'axe': WeaponProfile(
    key: 'axe',
    attacks: [
      WeaponAttack(method: AttackMethod.slash, minReach: 0, maxReach: 1),
    ],
  ),

  /// 양날 전투 도끼. Two-handed weight that charges.
  'battle_axe': WeaponProfile(
    key: 'battle_axe',
    attacks: [
      WeaponAttack(
        method: AttackMethod.slash,
        minReach: 0,
        maxReach: 1,
        power: 115,
        charge: true,
      ),
    ],
  ),

  /// 레이피어. A point at arm's length, and still a point up close.
  'rapier': WeaponProfile(
    key: 'rapier',
    attacks: [
      WeaponAttack(method: AttackMethod.pierce, minReach: 1, maxReach: 2),
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 0,
        maxReach: 1,
        power: 75,
      ),
    ],
  ),

  /// 블로우 파이프. Light, and from anywhere but nose to nose.
  'blowpipe': WeaponProfile(
    key: 'blowpipe',
    attacks: [
      WeaponAttack(
        method: AttackMethod.pierce,
        minReach: 1,
        maxReach: 3,
        power: 80,
      ),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 0,
        power: 30,
      ),
    ],
  ),

  /// 투석기. The one missile that lands as weight.
  'sling': WeaponProfile(
    key: 'sling',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 1,
        maxReach: 3,
        power: 85,
      ),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 0,
        power: 40,
      ),
    ],
  ),

  // --- natural weapons ----------------------------------------------
  //
  // What an assistant member fights with (ch.9.7): it has no equipment
  // screen, so its weapon is part of what it is. The assistant cannot
  // be told where to stand, so the ones that are not teeth and claws
  // reach the whole board — an automatic attack that spent its turns
  // straining would be the wasted turn this skeleton forbids. They are
  // named for how they land, not for what they are: fangs and a spear
  // are both `natural_pierce`.
  'natural_slash': WeaponProfile(
    key: 'natural_slash',
    attacks: [
      WeaponAttack(method: AttackMethod.slash, minReach: 0, maxReach: 2),
    ],
  ),
  'natural_pierce': WeaponProfile(
    key: 'natural_pierce',
    attacks: [
      WeaponAttack(method: AttackMethod.pierce, minReach: 0, maxReach: 2),
    ],
  ),
  'natural_blunt': WeaponProfile(
    key: 'natural_blunt',
    attacks: [
      WeaponAttack(method: AttackMethod.blunt, minReach: 0, maxReach: 2),
    ],
  ),
  'natural_hurl': WeaponProfile(
    key: 'natural_hurl',
    attacks: [
      WeaponAttack(method: AttackMethod.blunt, minReach: 0, maxReach: 4),
    ],
  ),
  'natural_fire': WeaponProfile(
    key: 'natural_fire',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 4,
        elementOverride: Element.fire,
      ),
    ],
  ),
  'natural_ice': WeaponProfile(
    key: 'natural_ice',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 4,
        elementOverride: Element.ice,
      ),
    ],
  ),
  'natural_lightning': WeaponProfile(
    key: 'natural_lightning',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 4,
        elementOverride: Element.lightning,
      ),
    ],
  ),
  'natural_force': WeaponProfile(
    key: 'natural_force',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 4,
        elementOverride: Element.force,
      ),
    ],
  ),
  'natural_poison': WeaponProfile(
    key: 'natural_poison',
    attacks: [
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 4,
        elementOverride: Element.poison,
      ),
    ],
  ),
};

/// The weapon for a key, falling back to bare hands.
WeaponProfile weaponFor(String key) =>
    weaponTable[key] ?? weaponTable['unarmed']!;

/// A row that fits a weapon kind when the RPG has nothing more specific
/// to say. The bridge is expected to do better — a lance and a dagger
/// are both 찌르는 — but a snapshot built from the kind alone still
/// fights sensibly.
String defaultWeaponKeyFor(WeaponKind kind) => switch (kind) {
  WeaponKind.bare => 'unarmed',
  WeaponKind.slash => 'one_hand_slash',
  WeaponKind.chop => 'club',
  WeaponKind.pierce => 'spear',
  WeaponKind.shoot => 'bow',
  WeaponKind.special => 'natural_slash',
};

/// Enemies whose weapon is in their name.
///
/// Enemy weapons belong to the creature rather than to an equipment
/// slot. Reach is what makes the gap mean anything — if both sides only
/// ever held reach-1 weapons the gap would be decoration — so the
/// roster needs spread, and the hunters and knights are where the
/// documents hand it over.
const Map<String, String> enemyWeapons = {
  // Part 3
  'troll_hunter': 'bow',
  'orc_soldier': 'halberd',
  'troll_knight': 'lance',
  'royal_guard_knight': 'lance',
  'knight_dracon': 'lance',
  'lore_knight': 'long_sword',
  'variant_knight': 'long_sword',
  'bodyguard_knight': 'long_sword',
  // Parts 1 and 2
  'skeleton_soldier': 'long_sword',
  'man_eating_wolf': 'natural_pierce',
  'giant': 'club',
  'troll': 'club',
  'ogre': 'mace',
  'skeleton': 'long_sword',
  'devil_hunter': 'halberd',
  'death_knight': 'great_sword',
  'black_knight': 'great_sword',
  'wolf': 'natural_pierce',
  'basilisk': 'natural_pierce',
  'dragon': 'natural_slash',
};

/// What an enemy fights with: its named weapon, or what a creature of
/// that strength looks like it swings.
String enemyWeaponKey({required String key, required int strength}) {
  final named = enemyWeapons[key];
  if (named != null) return named;
  if (strength <= 0) return 'unarmed';
  if (strength >= 30) return 'great_sword';
  if (strength >= 18) return 'halberd';
  if (strength >= 10) return 'long_sword';
  return 'unarmed';
}

/// The reach the targeting weights should assume for a wielder.
int reachOf(WeaponProfile weapon) => weapon.longestReach;

/// A sanity bound: nothing stands further apart than this.
const int longestPossibleReach = maxGap + 2 + 2;
