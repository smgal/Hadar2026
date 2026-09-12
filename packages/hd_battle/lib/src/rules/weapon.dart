import 'affinity.dart';
import 'position.dart';

/// What a weapon can do, and how far (B5-02).
///
/// ## Why a weapon is a table and not a number
///
/// The original defends and attacks with single integers: `ac` on one
/// side, `pow_of_weapon` on the other. Ten weapons — bare hand, dagger,
/// club, halberd, long sword, mace, lance, poleaxe, trident, flame
/// sword — collapse into one ladder, so there is never a reason to keep
/// the dagger.
///
/// Four of those ten are polearms. The idea that length differs is
/// already in the original's own name list; only the numbers lost it.
///
/// ## Minimum reach is what keeps this from degenerating
///
/// Without it, reach is strictly dominant. At gap 2 a side with reach 2
/// against a side with reach 1 spends one leader's turn holding the
/// distance while the other side spends a leader's turn *and* every
/// other member's turn unable to swing — one turn against five. Long
/// weapons would simply win.
///
/// With a minimum, the long side wants the gap open and the short side
/// wants it closed, and neither is right in general. It also gives the
/// lance its shape: charge in, hit hard, and then be the wrong weapon
/// for where you now are.
///
/// ## No sidearm slot
///
/// A pike-wielder who cannot act at gap 0 is a wasted turn, and wasted
/// turns are the one thing B5 does not allow. That could be answered
/// with a backup-weapon slot, but a slot whose answer is always "the
/// best dagger I own" is not a decision, and it would put a new item
/// type through every shop and drop table.
///
/// Instead every long weapon carries a **close-quarters method of its
/// own** — the shaft of the spear. No new slot, no new items, and it is
/// the same mechanism [WeaponAttack.element] already needs.

/// How a blow is delivered. Feeds the affinity table (B5-06).
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
  });

  final AttackMethod method;

  /// Closest distance this works at. A lance cannot be brought to bear
  /// on something already on top of you.
  final int minReach;

  /// Furthest distance this works at.
  final int maxReach;

  /// Percentage applied to the wielder's `powOfWeapon`. The backup
  /// method of a long weapon is deliberately weak.
  final int power;

  /// Whether this can be used to close and strike in one action
  /// (B5-03).
  final bool charge;

  Element get element => elementOfMethod(method);

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

  /// The furthest anything on this weapon reaches. Feeds the targeting
  /// falloff (B5-04).
  int get longestReach =>
      attacks.map((a) => a.maxReach).reduce((a, b) => a > b ? a : b);

  bool get canCharge => attacks.any((a) => a.charge);
}

/// Picks the way to use a weapon at a given distance.
///
/// Anything that fits wins, strongest first. Nothing fits — the whole
/// point of the close-in method — and it falls to whichever is least
/// far outside its band. **Always returns something.**
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

/// The weapons the battle knows about.
///
/// Keyed by string like the enemy table, and for the same reason: the
/// battle owns its own tables so it can be balanced without dragging
/// the RPG's item data along. The RPG supplies **how hard**
/// (`powOfWeapon`); this supplies **how it reaches**.
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
      // Short and quick. Has to be in close, which is where the
      // targeting weights put you at the front of the line.
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
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 60,
      ),
    ],
  ),
  'poleaxe': WeaponProfile(
    key: 'poleaxe',
    attacks: [
      WeaponAttack(method: AttackMethod.slash, minReach: 1, maxReach: 2),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 60,
      ),
    ],
  ),
  'trident': WeaponProfile(
    key: 'trident',
    attacks: [
      WeaponAttack(method: AttackMethod.pierce, minReach: 1, maxReach: 2),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 60,
      ),
    ],
  ),
  'lance': WeaponProfile(
    key: 'lance',
    attacks: [
      // The longest thing in the game, and the only one that charges.
      // Its own minimum is what balances that: close with it and you
      // are holding the wrong weapon.
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
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 60,
      ),
    ],
  ),

  // --- W1-06: the styles a pair of hands can make -------------------
  //
  // `hd_world` reads a fighting style off what the two hands hold, and
  // four of the styles it can name had **no profile here at all**: the
  // original ships seven missile weapons and this table had none, so a
  // hunter holding a bow could not be handed to a battle. These rows
  // close that gap.
  //
  // The reach bands are the ones BP-45 argued for. Nothing above this
  // line changed — the enemy table and every fixture keep the keys they
  // already used.

  /// One blade, the other hand free.
  'one_hand_slash': WeaponProfile(
    key: 'one_hand_slash',
    attacks: [
      WeaponAttack(method: AttackMethod.slash, minReach: 0, maxReach: 1),
    ],
  ),

  /// A blade and a shield. The shield is the second way to strike, which
  /// is what gives a swordsman an answer to bone and stone.
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

  /// A one-handed spear. Holds a line at arm's length whether or not the
  /// other hand carries a shield.
  'spear': WeaponProfile(
    key: 'spear',
    attacks: [
      WeaponAttack(method: AttackMethod.pierce, minReach: 1, maxReach: 2),
      WeaponAttack(
        method: AttackMethod.blunt,
        minReach: 0,
        maxReach: 1,
        power: 60,
      ),
    ],
  ),

  /// Two-handed weight. Charges, and the charge is the point of it.
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

  /// Reaches the whole board from the back rank, and is helpless once
  /// something is on top of it — the bowstave is all it has at zero.
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

  /// The opposite trade: weaker, and shoots from anywhere at all.
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

  /// The hardest-hitting missile, from a set position.
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

  /// Thrown from the middle rank, with a hand left over for a shield.
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
};

/// The weapon for a key, falling back to bare hands.
WeaponProfile weaponFor(String key) =>
    weaponTable[key] ?? weaponTable['unarmed']!;

/// What an enemy fights with.
///
/// Enemy weapons belong to the creature rather than to an equipment
/// slot, so this is a property of the row. The 75-row table is
/// generated from the original binary, so most of it is derived from
/// what the creature is and only the ones worth naming are named.
const Map<String, String> enemyWeapons = {
  // Reach is what makes the gap mean anything. If both sides only ever
  // held reach-1 weapons the gap would be decoration, so the roster
  // needs spread.
  'giant': 'club',
  'troll': 'club',
  'ogre': 'mace',
  'skeleton': 'long_sword',
  'orc_soldier': 'halberd',
  'lizard_man': 'trident',
  'centaur': 'lance',
  'knight': 'long_sword',
  'black_knight': 'great_sword',
  'death_knight': 'great_sword',
  'devil_hunter': 'halberd',
  'dragon': 'unarmed',
  'wolf': 'unarmed',
  'basilisk': 'unarmed',
};

/// Falls back to what the creature looks like it fights with.
///
/// Something with no arms bites, so it has to be in close; something
/// big and strong swings something long.
String enemyWeaponKey({
  required String key,
  required int strength,
  required int agility,
}) {
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

/// A sanity bound: nothing reaches further than the board is deep.
const int longestPossibleReach = maxGap + 2 + 2;
