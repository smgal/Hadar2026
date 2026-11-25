import '../contract/vocabulary.dart';

/// `base ± spread`. A spread of zero is a fixed value and draws nothing.
class StatRoll {
  const StatRoll(this.base, [this.spread = 0]);

  final int base;
  final int spread;
}

/// "공통 기본 능력치 = 10±5" — what every stat a row does not name
/// falls back to (ch.9.7).
const StatRoll commonStat = StatRoll(10, 5);

/// How a summoned creature's attack power comes out.
class PowerRule {
  /// `summon skill × tenths ÷ 10` — the table's "S×3", "S×1.5", "S×0.8".
  const PowerRule.timesSkill(this.tenths) : fixed = null, randomUpTo = 0;

  /// A number of its own, whatever the caster's skill.
  const PowerRule.fixed(StatRoll this.fixed) : tenths = 0, randomUpTo = 0;

  /// `summon skill × (1..n)`, drawn — the dragons' breath.
  const PowerRule.timesSkillRandom(this.randomUpTo) : tenths = 0, fixed = null;

  final int tenths;
  final StatRoll? fixed;
  final int randomUpTo;
}

/// One shape a summon can come out in. Rows that differ only in what
/// they are called (the four fire spirits) share one stat block and
/// list their names here.
class SummonForm {
  const SummonForm(this.nameKey, {this.weaponNameKey, this.weaponKey});

  /// The name, as a key the text package resolves.
  final String nameKey;

  /// Overrides the row's weapon name and reach — the twelve dragons
  /// differ in what they breathe.
  final String? weaponNameKey;
  final String? weaponKey;
}

/// One row of ch.9.7's tables.
class SummonSpec {
  const SummonSpec({
    required this.forms,
    required this.family,
    required this.attacksAll,
    required this.ac,
    required this.power,
    required this.weaponKey,
    required this.weaponNameKey,
    this.classId = 0,
    this.strength = commonStat,
    this.mentality = commonStat,
    this.concentration = commonStat,
    this.endurance = commonStat,
    this.resistance = commonStat,
    this.accuracy = commonStat,
    this.luck = commonStat,
    this.weaponKind = WeaponKind.special,
    this.shieldPower = 0,
    this.skillSlotsAtSummonSkill = const <int>[],
    this.rank = 2,
    this.fixedLevel,
    this.holdsMagic = false,
    this.immuneToMindControl = false,
  });

  final List<SummonForm> forms;
  final Family family;

  /// Whether its automatic attack sweeps every enemy (ch.8.5).
  final bool attacksAll;

  final int classId;

  final StatRoll strength;
  final StatRoll mentality;
  final StatRoll concentration;
  final StatRoll endurance;
  final StatRoll resistance;
  final StatRoll accuracy;
  final StatRoll luck;
  final StatRoll ac;

  final PowerRule power;
  final WeaponKind weaponKind;
  final String weaponKey;
  final String weaponNameKey;
  final int shieldPower;

  /// Skill slots that take the caster's summon skill as their value —
  /// the Ancient Knight's 베는 and 방패.
  final List<int> skillSlotsAtSummonSkill;

  /// Where it stands. Brutes go to the front; anything that breathes or
  /// throws stays in the middle.
  final int rank;

  /// Crystal creatures arrive at level 30 whoever calls them.
  final int? fixedLevel;

  /// The Ancient Mage alone carries magic points: `mentality × level`.
  final bool holdsMagic;

  final bool immuneToMindControl;
}

// --- 1..4: the elementals ---------------------------------------------

const SummonSpec _fire = SummonSpec(
  forms: [
    SummonForm('summon.fire_spirit'),
    SummonForm('summon.salamander'),
    SummonForm('summon.azer'),
    SummonForm('summon.ifrit'),
  ],
  family: Family.elemental,
  // The one elemental that strikes a single enemy.
  attacksAll: false,
  ac: StatRoll(0),
  power: PowerRule.timesSkill(30),
  weaponKey: 'natural_fire',
  weaponNameKey: 'natural.flame',
);

const SummonSpec _water = SummonSpec(
  forms: [
    SummonForm('summon.nymph'),
    SummonForm('summon.dryads'),
    SummonForm('summon.nereids'),
    SummonForm('summon.naiads'),
    SummonForm('summon.napaeae'),
    SummonForm('summon.oreads'),
    SummonForm('summon.alseids'),
    SummonForm('summon.marid'),
    SummonForm('summon.kelpie'),
  ],
  family: Family.elemental,
  attacksAll: true,
  endurance: StatRoll(8, 5),
  resistance: StatRoll(12, 5),
  ac: StatRoll(1),
  power: PowerRule.timesSkill(20),
  weaponKey: 'natural_force',
  weaponNameKey: 'natural.tidal_wave',
);

const SummonSpec _air = SummonSpec(
  forms: [
    SummonForm('summon.air_spirit'),
    SummonForm('summon.sylph'),
    SummonForm('summon.sylphid'),
    SummonForm('summon.djinni'),
    SummonForm('summon.invisible_stalker'),
  ],
  family: Family.elemental,
  attacksAll: true,
  endurance: StatRoll(6, 5),
  resistance: StatRoll(14, 5),
  accuracy: StatRoll(13, 5),
  ac: StatRoll(1),
  power: PowerRule.timesSkill(10),
  weaponKey: 'natural_force',
  weaponNameKey: 'natural.storm',
);

const SummonSpec _earth = SummonSpec(
  forms: [
    SummonForm('summon.earth_spirit'),
    SummonForm('summon.gnome'),
    SummonForm('summon.dao'),
  ],
  family: Family.elemental,
  attacksAll: true,
  endurance: StatRoll(14, 5),
  accuracy: StatRoll(6, 5),
  ac: StatRoll(3),
  power: PowerRule.timesSkill(40),
  weaponKey: 'natural_force',
  weaponNameKey: 'natural.earthquake',
);

// --- 5: the dead ------------------------------------------------------

const SummonSpec _ancientKnight = SummonSpec(
  forms: [SummonForm('summon.ancient_knight')],
  family: Family.fighter,
  classId: ClassId.knight,
  attacksAll: false,
  strength: StatRoll(12, 5),
  mentality: StatRoll(6, 5),
  endurance: StatRoll(15, 5),
  resistance: StatRoll(10, 5),
  accuracy: StatRoll(13, 5),
  // "갑옷 3±1" — read as the armour class it arrives with.
  ac: StatRoll(3, 1),
  power: PowerRule.fixed(StatRoll(60, 10)),
  weaponKind: WeaponKind.slash,
  weaponKey: 'one_hand_slash',
  weaponNameKey: 'weapon.long_sword',
  // 소형 강철 방패.
  shieldPower: 2,
  skillSlotsAtSummonSkill: [SkillIndex.slash, SkillIndex.shield],
  rank: 1,
);

const SummonSpec _ancientMage = SummonSpec(
  forms: [SummonForm('summon.ancient_mage')],
  family: Family.mage,
  classId: ClassId.mage,
  attacksAll: true,
  strength: StatRoll(7, 5),
  mentality: StatRoll(12, 5),
  endurance: StatRoll(7, 5),
  resistance: StatRoll(10, 5),
  accuracy: StatRoll(13, 5),
  ac: StatRoll(0),
  power: PowerRule.fixed(StatRoll(2)),
  weaponKey: 'natural_fire',
  weaponNameKey: 'natural.flame',
  rank: 3,
  holdsMagic: true,
);

// --- 6: creatures of another dimension --------------------------------

const List<SummonSpec> _otherDimension = [
  SummonSpec(
    forms: [SummonForm('summon.bandersnatch')],
    family: Family.unknown,
    attacksAll: false,
    endurance: StatRoll(15, 5),
    resistance: StatRoll(8, 5),
    accuracy: StatRoll(12, 5),
    ac: StatRoll(3),
    power: PowerRule.timesSkill(30),
    weaponKey: 'natural_pierce',
    weaponNameKey: 'natural.fangs',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.carrion_crawler')],
    family: Family.unknown,
    attacksAll: false,
    endurance: StatRoll(20, 5),
    resistance: StatRoll(14, 5),
    accuracy: StatRoll(13, 5),
    ac: StatRoll(3),
    power: PowerRule.timesSkill(10),
    weaponKey: 'natural_blunt',
    weaponNameKey: 'natural.tentacles',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.centaur')],
    family: Family.unknown,
    attacksAll: false,
    endurance: StatRoll(17, 5),
    resistance: StatRoll(12, 5),
    accuracy: StatRoll(18, 2),
    ac: StatRoll(2),
    power: PowerRule.timesSkill(15),
    weaponKey: 'natural_pierce',
    weaponNameKey: 'weapon.spear',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.demogorgon')],
    family: Family.unknown,
    attacksAll: false,
    endurance: StatRoll(18, 5),
    resistance: StatRoll(5, 5),
    accuracy: StatRoll(17, 3),
    ac: StatRoll(4),
    power: PowerRule.timesSkill(40),
    weaponKey: 'natural_slash',
    weaponNameKey: 'natural.claws',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.dullahan')],
    family: Family.unknown,
    attacksAll: false,
    endurance: StatRoll(10, 5),
    resistance: StatRoll(20),
    accuracy: StatRoll(17),
    ac: StatRoll(3),
    power: PowerRule.timesSkill(10),
    weaponKey: 'natural_pierce',
    weaponNameKey: 'weapon.lance',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.ettin')],
    family: Family.unknown,
    attacksAll: false,
    endurance: StatRoll(10, 5),
    resistance: StatRoll(10),
    accuracy: StatRoll(10, 9),
    ac: StatRoll(1),
    power: PowerRule.timesSkill(8),
    weaponKey: 'natural_blunt',
    weaponNameKey: 'weapon.club',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.hellhound')],
    family: Family.unknown,
    attacksAll: false,
    endurance: StatRoll(14, 5),
    resistance: StatRoll(9, 5),
    accuracy: StatRoll(11, 5),
    ac: StatRoll(2),
    power: PowerRule.timesSkill(30),
    weaponKey: 'natural_pierce',
    weaponNameKey: 'natural.fangs',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.minotaur')],
    family: Family.unknown,
    attacksAll: false,
    endurance: StatRoll(13, 5),
    resistance: StatRoll(11, 5),
    accuracy: StatRoll(14, 5),
    ac: StatRoll(2),
    power: PowerRule.timesSkill(30),
    weaponKey: 'natural_slash',
    weaponNameKey: 'weapon.hand_axe',
    rank: 1,
  ),
];

// --- 7: giants --------------------------------------------------------

const List<SummonSpec> _giants = [
  SummonSpec(
    forms: [SummonForm('summon.cloud_giant')],
    family: Family.giant,
    attacksAll: false,
    endurance: StatRoll(20, 5),
    resistance: StatRoll(15, 5),
    accuracy: StatRoll(10, 5),
    ac: StatRoll(2),
    power: PowerRule.timesSkill(25),
    weaponKey: 'natural_hurl',
    weaponNameKey: 'natural.rock',
  ),
  SummonSpec(
    forms: [SummonForm('summon.fire_giant')],
    family: Family.giant,
    attacksAll: false,
    endurance: StatRoll(25, 5),
    resistance: StatRoll(5, 5),
    accuracy: StatRoll(12, 5),
    ac: StatRoll(2),
    power: PowerRule.timesSkill(40),
    weaponKey: 'natural_fire',
    weaponNameKey: 'weapon.flame_sword',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.frost_giant')],
    family: Family.giant,
    attacksAll: false,
    endurance: StatRoll(30, 5),
    resistance: StatRoll(8, 5),
    accuracy: StatRoll(8, 2),
    ac: StatRoll(2),
    power: PowerRule.timesSkill(20),
    weaponKey: 'natural_slash',
    weaponNameKey: 'weapon.gladius',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.hill_giant')],
    family: Family.giant,
    attacksAll: false,
    endurance: StatRoll(40, 5),
    resistance: StatRoll(5, 5),
    accuracy: StatRoll(7, 3),
    ac: StatRoll(2),
    power: PowerRule.timesSkill(15),
    weaponKey: 'natural_blunt',
    weaponNameKey: 'natural.bone',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.stone_giant')],
    family: Family.giant,
    attacksAll: false,
    endurance: StatRoll(20, 5),
    resistance: StatRoll(10, 5),
    accuracy: StatRoll(11, 5),
    ac: StatRoll(4),
    power: PowerRule.timesSkill(25),
    weaponKey: 'natural_hurl',
    weaponNameKey: 'natural.rock',
  ),
  SummonSpec(
    forms: [SummonForm('summon.storm_giant')],
    family: Family.giant,
    attacksAll: false,
    endurance: StatRoll(20, 5),
    resistance: StatRoll(10, 5),
    accuracy: StatRoll(15, 9),
    ac: StatRoll(1),
    power: PowerRule.timesSkill(60),
    weaponKey: 'natural_lightning',
    weaponNameKey: 'natural.lightning',
  ),
];

// --- 8: golems --------------------------------------------------------

const List<SummonSpec> _golems = [
  SummonSpec(
    forms: [SummonForm('summon.clay_golem')],
    family: Family.golem,
    attacksAll: true,
    endurance: StatRoll(30, 5),
    resistance: StatRoll(15, 5),
    accuracy: StatRoll(13, 5),
    ac: StatRoll(3),
    power: PowerRule.timesSkill(5),
    weaponKey: 'natural_blunt',
    weaponNameKey: 'natural.clay',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.flesh_golem')],
    family: Family.golem,
    attacksAll: true,
    endurance: StatRoll(20, 5),
    resistance: StatRoll(10, 5),
    accuracy: StatRoll(12, 5),
    ac: StatRoll(1),
    power: PowerRule.timesSkill(10),
    weaponKey: 'natural_blunt',
    weaponNameKey: 'natural.bare_hands',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.iron_golem')],
    family: Family.golem,
    attacksAll: true,
    endurance: StatRoll(20, 5),
    resistance: StatRoll(5, 5),
    accuracy: StatRoll(10, 2),
    ac: StatRoll(5),
    power: PowerRule.timesSkill(40),
    weaponKey: 'natural_blunt',
    weaponNameKey: 'natural.iron_fist',
    rank: 1,
  ),
  SummonSpec(
    forms: [SummonForm('summon.stone_golem')],
    family: Family.golem,
    attacksAll: true,
    endurance: StatRoll(25, 5),
    resistance: StatRoll(10, 5),
    accuracy: StatRoll(13, 3),
    ac: StatRoll(4),
    power: PowerRule.timesSkill(20),
    weaponKey: 'natural_blunt',
    weaponNameKey: 'natural.bare_hands',
    rank: 1,
  ),
];

// --- 9: dragons -------------------------------------------------------

const SummonSpec _dragon = SummonSpec(
  forms: [
    SummonForm(
      'summon.black_dragon',
      weaponNameKey: 'breath.acid',
      weaponKey: 'natural_poison',
    ),
    SummonForm(
      'summon.blue_dragon',
      weaponNameKey: 'breath.lightning',
      weaponKey: 'natural_lightning',
    ),
    SummonForm(
      'summon.brass_dragon',
      weaponNameKey: 'breath.poison',
      weaponKey: 'natural_poison',
    ),
    SummonForm(
      'summon.bronze_dragon',
      weaponNameKey: 'breath.lightning',
      weaponKey: 'natural_lightning',
    ),
    SummonForm('summon.chromatic_dragon'),
    SummonForm(
      'summon.copper_dragon',
      weaponNameKey: 'breath.acid',
      weaponKey: 'natural_poison',
    ),
    SummonForm('summon.gold_dragon'),
    SummonForm(
      'summon.green_dragon',
      weaponNameKey: 'breath.chlorine',
      weaponKey: 'natural_poison',
    ),
    SummonForm(
      'summon.platinum_dragon',
      weaponNameKey: 'breath.cold',
      weaponKey: 'natural_ice',
    ),
    SummonForm('summon.red_dragon'),
    SummonForm(
      'summon.silver_dragon',
      weaponNameKey: 'breath.frost',
      weaponKey: 'natural_ice',
    ),
    SummonForm(
      'summon.white_dragon',
      weaponNameKey: 'breath.frost',
      weaponKey: 'natural_ice',
    ),
  ],
  family: Family.dragon,
  attacksAll: false,
  endurance: StatRoll(30, 10),
  resistance: StatRoll(10, 10),
  accuracy: StatRoll(15, 5),
  ac: StatRoll(3),
  power: PowerRule.timesSkillRandom(5),
  // The default breath, for the three that breathe fire.
  weaponKey: 'natural_fire',
  weaponNameKey: 'breath.fire',
);

// --- 10: lycanthropes -------------------------------------------------

const SummonSpec _werewolf = SummonSpec(
  forms: [SummonForm('summon.werewolf')],
  family: Family.unknown,
  attacksAll: false,
  endurance: StatRoll(25),
  resistance: StatRoll(15),
  accuracy: StatRoll(18),
  ac: StatRoll(2),
  power: PowerRule.timesSkill(30),
  weaponKey: 'natural_slash',
  weaponNameKey: 'natural.claws',
  rank: 1,
);

const SummonSpec _dragonNewt = SummonSpec(
  forms: [SummonForm('summon.dragon_newt')],
  family: Family.dragon,
  attacksAll: false,
  endurance: StatRoll(30),
  resistance: StatRoll(18),
  accuracy: StatRoll(19),
  ac: StatRoll(4),
  power: PowerRule.timesSkill(45),
  weaponKey: 'natural_slash',
  weaponNameKey: 'weapon.long_sword',
  rank: 1,
);

/// Summon tier (1..10) to the rows it can produce. One is drawn
/// uniformly over every *form* in the tier.
const Map<int, List<SummonSpec>> summonTiers = {
  1: [_fire],
  2: [_water],
  3: [_air],
  4: [_earth],
  5: [_ancientKnight, _ancientMage],
  6: _otherDimension,
  7: _giants,
  8: _golems,
  9: [_dragon],
  10: [_werewolf, _dragonNewt],
};

// --- the summoning crystal (ch.9.8) -----------------------------------

/// 크리스탈 드래곤. Level 30, immune to 정신 지배.
const SummonSpec crystalDragon = SummonSpec(
  forms: [SummonForm('summon.crystal_dragon')],
  family: Family.dragon,
  attacksAll: false,
  strength: StatRoll(25),
  mentality: StatRoll(20),
  concentration: StatRoll(20),
  endurance: StatRoll(30),
  resistance: StatRoll(20),
  accuracy: StatRoll(20),
  luck: StatRoll(20),
  ac: StatRoll(4),
  power: PowerRule.fixed(StatRoll(255)),
  weaponKey: 'natural_ice',
  weaponNameKey: 'breath.frost',
  fixedLevel: 30,
  immuneToMindControl: true,
);

/// 크리스탈 고렘. Level 30, immune to 정신 지배.
const SummonSpec crystalGolem = SummonSpec(
  forms: [SummonForm('summon.crystal_golem')],
  family: Family.golem,
  attacksAll: true,
  strength: StatRoll(20),
  mentality: StatRoll(0),
  concentration: StatRoll(0),
  endurance: StatRoll(40),
  resistance: StatRoll(25),
  accuracy: StatRoll(13),
  luck: StatRoll(0),
  ac: StatRoll(5),
  power: PowerRule.fixed(StatRoll(150)),
  weaponKey: 'natural_blunt',
  weaponNameKey: 'natural.bare_hands',
  rank: 1,
  fixedLevel: 30,
  immuneToMindControl: true,
);
