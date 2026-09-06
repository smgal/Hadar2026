/// Elemental affinity (B2-09).
///
/// ## This is a decision, not a port
///
/// Neither tree has elements. `item.dart`'s `param` carries `attaPow`,
/// `ac` and `itemType`; the 75-row enemy table carries eleven numbers
/// and none of them is an element. The word does not appear.
///
/// So this is designed, and deliberately kept **thin**: one element per
/// attack, a short list of resistances and weaknesses per enemy, and one
/// multiplier. Thin because it has to cross into the RPG — B3-03 has to
/// give items and enemies an element on that side, and the wider this
/// is, the more of that there is to do.
enum Element {
  /// No element. Weapons and most spells.
  none,
  fire,
  ice,
  lightning,

  /// Wind, quakes, raw force.
  force,

  /// Mind and ESP.
  mind,
  poison,

  // Physical elements (B5-02 introduces them, B5-06 gives them a
  // table). One axis, not two: a player should not have to learn two
  // separate charts.
  slash,
  pierce,
  blunt,
}

/// Which element an attack spell carries.
///
/// Read off the spell list by name, and only where the name is
/// unambiguous — `마법 화살` is an arrow of nothing in particular, while
/// `초냉기` plainly is not. Anything not listed is [Element.none], which
/// keeps the table honest about how much of this is invented.
const Map<int, Element> spellElements = {
  2: Element.fire, // 마법 화구
  4: Element.poison, // 독 바늘
  5: Element.lightning, // 맥동 광선
  6: Element.lightning, // 직격 뇌전
  7: Element.force, // 공기 폭풍
  8: Element.fire, // 열선 파동
  9: Element.force, // 초음파
  10: Element.ice, // 초냉기
  11: Element.force, // 인공 지진
  13: Element.poison, // 독
  45: Element.mind, // 염력
};

Element spellElement(int magicId) => spellElements[magicId] ?? Element.none;

/// What an enemy resists and what it cannot stand.
class Affinity {
  const Affinity({this.resists = const {}, this.weakTo = const {}});

  final Set<Element> resists;
  final Set<Element> weakTo;

  static const Affinity none = Affinity();
}

/// Per-enemy affinity, by table key.
///
/// Hand-written and short. Assigned from what the creature is, not from
/// its numbers: the undead shrug off poison, things made of fire do not
/// mind fire and hate cold, and the mindless cannot be reached by mind
/// magic.
///
/// Enemies not listed have no affinity at all, which is most of them.
/// A full pass belongs with the RPG-side data in B3-03.
const Map<String, Affinity> enemyAffinities = {
  'skeleton': Affinity(resists: {Element.poison, Element.mind}),
  'mummy': Affinity(
    resists: {Element.poison, Element.mind},
    weakTo: {Element.fire},
  ),
  'ghost': Affinity(resists: {Element.poison, Element.force}),
  'phantom': Affinity(resists: {Element.poison, Element.force}),
  'rotten_corpse': Affinity(resists: {Element.poison}),
  'death_knight': Affinity(resists: {Element.poison, Element.mind}),
  'salamander': Affinity(resists: {Element.fire}, weakTo: {Element.ice}),
  'hell_fire': Affinity(resists: {Element.fire}, weakTo: {Element.ice}),
  'frost_dragon': Affinity(resists: {Element.ice}, weakTo: {Element.fire}),
  'insects': Affinity(weakTo: {Element.fire}),
  'buzz_bug': Affinity(weakTo: {Element.fire}),
  'giant_spider': Affinity(weakTo: {Element.fire}),
  'slime': Affinity(resists: {Element.force}, weakTo: {Element.ice}),
  'astral_mud': Affinity(resists: {Element.force}),
  'wisp': Affinity(resists: {Element.force}, weakTo: {Element.ice}),
  'python': Affinity(resists: {Element.poison}),
  'serpent': Affinity(resists: {Element.poison}),
  'basilisk': Affinity(resists: {Element.poison}),
  'dragon': Affinity(resists: {Element.fire}),
  'archi_mage': Affinity(resists: {Element.mind}),
  'neo_necromancer': Affinity(resists: {Element.poison, Element.mind}),
};

Affinity affinityOf(String enemyKey) =>
    enemyAffinities[enemyKey] ?? Affinity.none;

/// How affinity moves damage.
///
/// Doubling and halving — big enough to change what you cast, small
/// enough that a wrong choice is not a wasted turn. Integer arithmetic
/// throughout, like every other formula here.
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

// --- B5-06: physical elements ---------------------------------------

/// What a creature is made of, for the purpose of assigning affinities.
///
/// 75 rows times 9 elements is 675 cells, and nobody is filling that in
/// by hand — `enemyAffinities` above only ever covered 21 rows for the
/// same reason. So the bulk is derived from what the creature *is* and
/// only the ones worth naming are named.
enum Constitution {
  /// Flesh and bone. No strong opinion about anything.
  ordinary,

  /// Bone, rot and old malice. Cutting them accomplishes little;
  /// breaking them accomplishes a great deal.
  undead,

  /// Held together by nothing in particular. A blade passes through.
  formless,

  /// Plated or shelled. Edges skid; weight goes through.
  armoured,

  /// Small, fast and fragile. Everything works, especially fire.
  vermin,

  /// Made of its own element.
  elemental,
}

/// Reads a creature's make-up off its own numbers and name.
///
/// Deliberately crude — the point is a defensible default for the whole
/// table, not a bestiary. Anything that matters gets named in
/// [physicalAffinities].
Constitution constitutionOf({
  required String key,
  required int strength,
  required int ac,
  required int agility,
  required int endurance,
}) {
  const undead = {
    'skeleton', 'zombie', 'mummy', 'ghost', 'phantom', 'rotten_corpse',
    'death_knight', 'wraith', 'death_skull', 'dark_soul', 'evil_soul',
    'neo_necromancer', 'ancient_evil', 'lich', //
  };
  const formless = {
    'slime', 'astral_mud', 'wisp', 'sprite', 'gas_cloud', 'shadow', //
  };
  const vermin = {
    'insects', 'buzz_bug', 'giant_spider', 'killer_bee', 'scorpion', //
  };
  const elemental = {
    'salamander', 'hell_fire', 'frost_dragon', 'ice_golem', 'fire_dragon', //
  };
  if (undead.contains(key)) return Constitution.undead;
  if (formless.contains(key)) return Constitution.formless;
  if (vermin.contains(key)) return Constitution.vermin;
  if (elemental.contains(key)) return Constitution.elemental;
  // Something with no strength at all is not a body in the usual sense.
  if (strength <= 0) return Constitution.formless;
  if (ac >= 8) return Constitution.armoured;
  if (endurance <= 6 && agility >= 12) return Constitution.vermin;
  return Constitution.ordinary;
}

/// The physical half of the affinity chart, by make-up.
///
/// Three elements, and every make-up has at least one weakness — a
/// creature nothing works on would just be a wall.
Affinity physicalAffinityOf(Constitution constitution) =>
    switch (constitution) {
      // Flesh and bone: a blade opens it, a club is absorbed by muscle.
      // This is the common case — 43 of the 75 rows — which is what
      // makes a sword the sensible default, and meeting something
      // armoured or undead a reason to carry a second answer.
      Constitution.ordinary => const Affinity(
        resists: {Element.blunt},
        weakTo: {Element.slash},
      ),
      Constitution.undead => const Affinity(
        resists: {Element.slash, Element.pierce},
        weakTo: {Element.blunt},
      ),
      Constitution.formless => const Affinity(
        resists: {Element.slash, Element.blunt},
        weakTo: {Element.pierce},
      ),
      Constitution.armoured => const Affinity(
        resists: {Element.slash},
        weakTo: {Element.blunt},
      ),
      Constitution.vermin => const Affinity(
        resists: {Element.blunt},
        weakTo: {Element.pierce},
      ),
      Constitution.elemental => const Affinity(
        resists: {Element.slash},
        weakTo: {Element.pierce},
      ),
    };

/// Hand-written physical affinities that override the derived ones.
const Map<String, Affinity> physicalAffinities = {
  // A thing made of stone does not care what shape the metal is.
  'stone_golem': Affinity(resists: {Element.slash, Element.pierce}),
  // Armour that thick has to be broken rather than cut or punctured.
  'black_knight': Affinity(
    resists: {Element.slash, Element.pierce},
    weakTo: {Element.blunt},
  ),
};

/// The whole chart for one enemy: magical affinities merged with
/// physical ones.
///
/// **One chart, not two.** The player should not have to learn a
/// separate table for weapons — that was the point of putting the
/// physical elements on the same axis in B5-02.
Affinity fullAffinityOf({
  required String key,
  required int strength,
  required int ac,
  required int agility,
  required int endurance,
}) {
  final magical = affinityOf(key);
  final physical =
      physicalAffinities[key] ??
      physicalAffinityOf(
        constitutionOf(
          key: key,
          strength: strength,
          ac: ac,
          agility: agility,
          endurance: endurance,
        ),
      );
  return Affinity(
    resists: {...magical.resists, ...physical.resists},
    weakTo: {...magical.weakTo, ...physical.weakTo},
  );
}
