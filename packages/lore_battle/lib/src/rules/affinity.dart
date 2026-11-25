/// Elemental affinity — one of the layers `hd_battle` puts on top of
/// the base numbers, carried over as it was.
///
/// ## Not in the design documents
///
/// Part 3 says outright that an attack spell's description is flavour
/// and its effect is pure damage (ch.9.2). So nothing here is the
/// trilogy's: it is the fork's inherited skeleton, kept because position
/// hangs off it — the reward for hitting a weakness with weight is that
/// the target is **driven back a rank**, and that is what joins elements
/// and position into one system.
///
/// It stays thin for the same reason it was thin there: one element per
/// attack, a short list of resistances and weaknesses per creature, one
/// multiplier.
enum Element {
  /// No element. Most spells.
  none,
  fire,
  ice,
  lightning,

  /// Wind, quakes, raw force.
  force,

  /// Mind and ESP.
  mind,
  poison,

  // Physical elements — the way a weapon is brought to bear. On the
  // same axis as the magical ones on purpose: one chart, not two.
  slash,
  pierce,
  blunt,
}

/// What an enemy resists and what it cannot stand.
class Affinity {
  const Affinity({this.resists = const {}, this.weakTo = const {}});

  final Set<Element> resists;
  final Set<Element> weakTo;

  static const Affinity none = Affinity();
}

/// How affinity moves damage — doubling and halving.
int applyAffinity({
  required int damage,
  required Element element,
  required Affinity affinity,
}) {
  if (element == Element.none) return damage;
  if (affinity.weakTo.contains(element)) return damage * 2;
  if (affinity.resists.contains(element)) return damage ~/ 2;
  return damage;
}

/// What affinity did, so the view can say so.
enum AffinityResult { neutral, weak, resisted }

AffinityResult affinityResult({
  required Element element,
  required Affinity affinity,
}) {
  if (element == Element.none) return AffinityResult.neutral;
  if (affinity.weakTo.contains(element)) return AffinityResult.weak;
  if (affinity.resists.contains(element)) return AffinityResult.resisted;
  return AffinityResult.neutral;
}

/// What a creature is made of, for the purpose of assigning affinities.
///
/// Three tables of 75 rows times nine elements is two thousand cells,
/// and nobody is filling that in by hand. So the bulk is derived from
/// what the creature *is* and only the ones worth naming are named.
enum Constitution {
  /// Flesh and bone. No strong opinion about anything.
  ordinary,

  /// Bone, rot and old malice. Cutting accomplishes little; breaking
  /// accomplishes a great deal.
  undead,

  /// Held together by nothing in particular. A blade passes through.
  formless,

  /// Plated or shelled. Edges skid; weight goes through.
  armoured,

  /// Small, fast and fragile.
  vermin,

  /// Made of fire.
  fiery,

  /// Made of cold.
  frozen,
}

/// Creatures whose make-up is in their name. Keys from all three
/// episodes share these sets — a `vampire` is undead in whichever table
/// it appears.
const Set<String> _undead = {
  // Part 1
  'phantom', 'skeleton', 'ghost', 'mummy', 'vampire', 'great_lich',
  'rotten_corpse', 'grim_death', 'evil_soul', 'dark_soul', 'reaper',
  'wraith', 'death_skull', 'death_knight', 'ancient_evil',
  'neo_necromancer',
  // Part 2
  'spirit', 'skeleton_soldier', 'grim_reaper', 'death_god',
  // Part 3
  'death_messenger', 'zombie', 'dracula', 'orc_revenant', 'troll_revenant',
  'kobold_revenant', 'dracon_revenant',
};

const Set<String> _formless = {
  'slime', 'wisp', 'sprite', 'mud_man', 'astral_mud', 'molten_monster',
  'fairy', 'mud_creature', 'formless_monster', //
  'water_spirit', 'wind_spirit', 'invisible_man', //
};

const Set<String> _vermin = {
  'insects', 'giant_spider', 'buzz_bug', 'blood_bat', 'giant_rat', //
  'insect_swarm', 'killer_bee', 'vampire_bat', //
};

const Set<String> _fiery = {
  'salamander', 'hell_fire', 'fire_lizard', 'fire_spirit', //
};

const Set<String> _frozen = {'frost_dragon', 'frost_dracon', 'ice_elemental'};

/// Reads a creature's make-up off its name and, failing that, its own
/// numbers. Deliberately crude — a defensible default for three whole
/// tables, not a bestiary.
Constitution constitutionOf({
  required String key,
  required int strength,
  required int ac,
  required int agility,
  required int endurance,
}) {
  if (_undead.contains(key)) return Constitution.undead;
  if (_formless.contains(key)) return Constitution.formless;
  if (_vermin.contains(key)) return Constitution.vermin;
  if (_fiery.contains(key)) return Constitution.fiery;
  if (_frozen.contains(key)) return Constitution.frozen;
  // Something with no strength at all is not a body in the usual sense.
  if (strength <= 0) return Constitution.formless;
  if (ac >= 8) return Constitution.armoured;
  if (endurance <= 6 && agility >= 12) return Constitution.vermin;
  return Constitution.ordinary;
}

/// The chart, by make-up. Every make-up has at least one weakness — a
/// creature nothing works on would just be a wall.
Affinity affinityOfConstitution(Constitution constitution) =>
    switch (constitution) {
      // Flesh and bone: a blade opens it, a club is absorbed by muscle.
      Constitution.ordinary => const Affinity(
        resists: {Element.blunt},
        weakTo: {Element.slash},
      ),
      Constitution.undead => const Affinity(
        resists: {Element.slash, Element.pierce, Element.poison, Element.mind},
        weakTo: {Element.blunt},
      ),
      Constitution.formless => const Affinity(
        resists: {Element.slash, Element.blunt, Element.force},
        weakTo: {Element.pierce},
      ),
      Constitution.armoured => const Affinity(
        resists: {Element.slash},
        weakTo: {Element.blunt},
      ),
      Constitution.vermin => const Affinity(
        resists: {Element.blunt},
        weakTo: {Element.pierce, Element.fire},
      ),
      Constitution.fiery => const Affinity(
        resists: {Element.slash, Element.fire},
        weakTo: {Element.pierce, Element.ice},
      ),
      Constitution.frozen => const Affinity(
        resists: {Element.slash, Element.ice},
        weakTo: {Element.blunt, Element.fire},
      ),
    };

/// The whole chart for one enemy.
Affinity affinityFor({
  required String key,
  required int strength,
  required int ac,
  required int agility,
  required int endurance,
}) => affinityOfConstitution(
  constitutionOf(
    key: key,
    strength: strength,
    ac: ac,
    agility: agility,
    endurance: endurance,
  ),
);
