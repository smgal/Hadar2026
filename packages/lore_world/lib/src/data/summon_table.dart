import 'dart:math';

import '../domain/enums.dart';
import '../domain/member.dart';
import 'class_table.dart';
import 'level_table.dart';
import 'spell_table.dart';

/// `base ± spread` 를 굴리는 값. spread 가 0 이면 고정이다.
final class Roll {
  const Roll(this.base, [this.spread = 0]);

  final int base;
  final int spread;

  int roll(Random rng) {
    if (spread <= 0) return base;
    final v = base - spread + rng.nextInt(spread * 2 + 1);
    return v < 0 ? 0 : v;
  }
}

/// 따로 적지 않은 능력치는 10±5 다(제9장 9.7). 민첩성은 0.
const Roll _common = Roll(10, 5);

/// 소환되는 존재 하나의 틀.
///
/// 능력치는 부를 때마다 굴린다. 공격력은 소환 능력치 S 에 비례한다
/// (`powerTenths` = 배율 × 10).
final class SummonDef {
  const SummonDef(
    this.key,
    this.family, {
    this.mode,
    this.strength = _common,
    this.mentality = _common,
    this.concentration = _common,
    this.endurance = _common,
    this.resistance = _common,
    this.agility = const Roll(0),
    this.accuracy = _common,
    this.luck = _common,
    this.weapon,
    this.powerTenths = 0,
    this.powerTenthsMax,
    this.fixedPower,
    this.ac = const Roll(0),
    this.classId = ClassId.none,
    this.equipWeapon,
    this.equipShield,
    this.skillsFromSummon = const [],
    this.fixedLevel,
    this.startMpPerLevel,
    this.mindControlImmune = false,
  });

  /// `summon.bandersnatch` 같은 이름표.
  final String key;
  final Family family;

  /// 계열이 정하는 공격 방식과 다를 때만(불의 정령).
  final AttackMode? mode;

  final Roll strength;
  final Roll mentality;
  final Roll concentration;
  final Roll endurance;
  final Roll resistance;
  final Roll agility;
  final Roll accuracy;
  final Roll luck;

  /// 타고난 무기의 이름표(`natural.fang`). null 이면 장비를 든다.
  final String? weapon;

  /// 공격력 = S × powerTenths ÷ 10.
  final int powerTenths;

  /// 있으면 배율을 powerTenths ~ powerTenthsMax 사이에서 굴린다(용의 브레스).
  final int? powerTenthsMax;

  /// S 와 무관한 고정 공격력.
  final Roll? fixedPower;

  /// 방어력.
  final Roll ac;

  final int classId;
  final String? equipWeapon;
  final String? equipShield;

  /// 이 자리들의 기술치는 S 가 된다(에인션트 나이트의 베는·방패).
  final List<int> skillsFromSummon;

  /// S 와 무관하게 정해진 레벨(크리스탈 소환수 30).
  final int? fixedLevel;

  /// 나타날 때의 MP = 정신력 × 레벨 × 이 값. null 이면 최대치로 온다.
  /// 에인션트 메이지만 1 이다(제9장 9.7 "MP = 정신×레벨").
  final int? startMpPerLevel;
  final bool mindControlImmune;
}

const Family _elem = Family.elemental;

SummonDef _fire(String key) => SummonDef(
  key,
  _elem,
  mode: AttackMode.single,
  weapon: 'natural.flame',
  powerTenths: 30,
);

SummonDef _water(String key) => SummonDef(
  key,
  _elem,
  endurance: const Roll(8, 5),
  resistance: const Roll(12, 5),
  weapon: 'natural.tidal_wave',
  powerTenths: 20,
  ac: const Roll(1),
);

SummonDef _air(String key) => SummonDef(
  key,
  _elem,
  endurance: const Roll(6, 5),
  resistance: const Roll(14, 5),
  accuracy: const Roll(13, 5),
  weapon: 'natural.storm',
  powerTenths: 10,
  ac: const Roll(1),
);

SummonDef _earth(String key) => SummonDef(
  key,
  _elem,
  endurance: const Roll(14, 5),
  accuracy: const Roll(6, 5),
  weapon: 'natural.earthquake',
  powerTenths: 40,
  ac: const Roll(3),
);

SummonDef _dragon(String key, String breath) => SummonDef(
  key,
  Family.dragon,
  endurance: const Roll(30, 10),
  resistance: const Roll(10, 10),
  accuracy: const Roll(15, 5),
  weapon: breath,
  powerTenths: 10,
  powerTenthsMax: 50,
  ac: const Roll(3),
);

/// 소환 마법 열 단계가 부르는 존재들(제9장 9.7). `summonPools[단계 - 1]`.
final List<List<SummonDef>> summonPools = [
  // 1 불의 정령 소환 — 정령인데 한 명만 친다.
  [
    _fire('summon.fire_spirit'),
    _fire('summon.salamander'),
    _fire('summon.azer'),
    _fire('summon.ifrit'),
  ],
  // 2 물의 정령 소환
  [
    _water('summon.nymph'),
    _water('summon.dryads'),
    _water('summon.nereids'),
    _water('summon.naiads'),
    _water('summon.napaeae'),
    _water('summon.oreads'),
    _water('summon.alseids'),
    _water('summon.marid'),
    _water('summon.kelpie'),
  ],
  // 3 공기의 정령 소환
  [
    _air('summon.air_spirit'),
    _air('summon.sylph'),
    _air('summon.sylphid'),
    _air('summon.djinni'),
    _air('summon.invisible_stalker'),
  ],
  // 4 땅의 정령 소환
  [_earth('summon.earth_spirit'), _earth('summon.gnome'), _earth('summon.dao')],
  // 5 죽은 자의 소생 — 반반.
  const [
    SummonDef(
      'summon.ancient_knight',
      Family.fighter,
      strength: Roll(12, 5),
      mentality: Roll(6, 5),
      endurance: Roll(15, 5),
      resistance: Roll(10, 5),
      accuracy: Roll(13, 5),
      fixedPower: Roll(60, 10),
      ac: Roll(3, 1),
      classId: ClassId.knight,
      equipWeapon: 'weapon.long_sword',
      equipShield: 'shield.small_steel',
      skillsFromSummon: [FighterSkill.slash, FighterSkill.shield],
    ),
    SummonDef(
      'summon.ancient_mage',
      Family.mage,
      strength: Roll(7, 5),
      mentality: Roll(12, 5),
      endurance: Roll(7, 5),
      resistance: Roll(10, 5),
      accuracy: Roll(13, 5),
      weapon: 'natural.flame',
      fixedPower: Roll(2),
      startMpPerLevel: 1,
    ),
  ],
  // 6 다른 차원 생물 소환 — 소환 문서도 이 표를 쓴다.
  otherDimensionCreatures,
  // 7 거인을 부름
  const [
    SummonDef(
      'summon.cloud_giant',
      Family.giant,
      endurance: Roll(20, 5),
      resistance: Roll(15, 5),
      accuracy: Roll(10, 5),
      weapon: 'natural.rock',
      powerTenths: 25,
      ac: Roll(2),
    ),
    SummonDef(
      'summon.fire_giant',
      Family.giant,
      endurance: Roll(25, 5),
      resistance: Roll(5, 5),
      accuracy: Roll(12, 5),
      weapon: 'weapon.flame_sword',
      powerTenths: 40,
      ac: Roll(2),
    ),
    SummonDef(
      'summon.frost_giant',
      Family.giant,
      endurance: Roll(30, 5),
      resistance: Roll(8, 5),
      accuracy: Roll(8, 2),
      weapon: 'weapon.gladius',
      powerTenths: 20,
      ac: Roll(2),
    ),
    SummonDef(
      'summon.hill_giant',
      Family.giant,
      endurance: Roll(40, 5),
      resistance: Roll(5, 5),
      accuracy: Roll(7, 3),
      weapon: 'natural.bone',
      powerTenths: 15,
      ac: Roll(2),
    ),
    SummonDef(
      'summon.stone_giant',
      Family.giant,
      endurance: Roll(20, 5),
      resistance: Roll(10, 5),
      accuracy: Roll(11, 5),
      weapon: 'natural.rock',
      powerTenths: 25,
      ac: Roll(4),
    ),
    SummonDef(
      'summon.storm_giant',
      Family.giant,
      endurance: Roll(20, 5),
      resistance: Roll(10, 5),
      accuracy: Roll(15, 9),
      weapon: 'natural.lightning',
      powerTenths: 60,
      ac: Roll(1),
    ),
  ],
  // 8 고렘을 부름 — 전체 공격.
  const [
    SummonDef(
      'summon.clay_golem',
      Family.golem,
      endurance: Roll(30, 5),
      resistance: Roll(15, 5),
      accuracy: Roll(13, 5),
      weapon: 'natural.clay',
      powerTenths: 5,
      ac: Roll(3),
    ),
    SummonDef(
      'summon.flesh_golem',
      Family.golem,
      endurance: Roll(20, 5),
      resistance: Roll(10, 5),
      accuracy: Roll(12, 5),
      weapon: 'natural.bare_hands',
      powerTenths: 10,
      ac: Roll(1),
    ),
    SummonDef(
      'summon.iron_golem',
      Family.golem,
      endurance: Roll(20, 5),
      resistance: Roll(5, 5),
      accuracy: Roll(10, 2),
      weapon: 'natural.iron_fist',
      powerTenths: 40,
      ac: Roll(5),
    ),
    SummonDef(
      'summon.stone_golem',
      Family.golem,
      endurance: Roll(25, 5),
      resistance: Roll(10, 5),
      accuracy: Roll(13, 3),
      weapon: 'natural.bare_hands',
      powerTenths: 20,
      ac: Roll(4),
    ),
  ],
  // 9 용을 부름 — 브레스 S × (1~5).
  [
    _dragon('summon.black_dragon', 'breath.acid'),
    _dragon('summon.blue_dragon', 'breath.lightning'),
    _dragon('summon.brass_dragon', 'breath.poison'),
    _dragon('summon.bronze_dragon', 'breath.lightning'),
    _dragon('summon.chromatic_dragon', 'breath.fire'),
    _dragon('summon.copper_dragon', 'breath.acid'),
    _dragon('summon.gold_dragon', 'breath.fire'),
    _dragon('summon.green_dragon', 'breath.chlorine'),
    _dragon('summon.platinum_dragon', 'breath.cold'),
    _dragon('summon.red_dragon', 'breath.fire'),
    _dragon('summon.silver_dragon', 'breath.frost'),
    _dragon('summon.white_dragon', 'breath.frost'),
  ],
  // 10 라이칸스로프 소환
  const [
    SummonDef(
      'summon.werewolf',
      Family.unknown,
      endurance: Roll(25),
      resistance: Roll(15),
      accuracy: Roll(18),
      weapon: 'natural.claws',
      powerTenths: 30,
      ac: Roll(2),
    ),
    SummonDef(
      'summon.dragon_newt',
      Family.dragon,
      endurance: Roll(30),
      resistance: Roll(18),
      accuracy: Roll(19),
      weapon: 'weapon.long_sword',
      powerTenths: 45,
      ac: Roll(4),
    ),
  ],
];

/// 다른 차원 생물 여덟(소환 6단계 · 소환 문서).
const List<SummonDef> otherDimensionCreatures = [
  SummonDef(
    'summon.bandersnatch',
    Family.unknown,
    endurance: Roll(15, 5),
    resistance: Roll(8, 5),
    accuracy: Roll(12, 5),
    weapon: 'natural.fangs',
    powerTenths: 30,
    ac: Roll(3),
  ),
  SummonDef(
    'summon.carrion_crawler',
    Family.unknown,
    endurance: Roll(20, 5),
    resistance: Roll(14, 5),
    accuracy: Roll(13, 5),
    weapon: 'natural.tentacles',
    powerTenths: 10,
    ac: Roll(3),
  ),
  SummonDef(
    'summon.centaur',
    Family.unknown,
    endurance: Roll(17, 5),
    resistance: Roll(12, 5),
    accuracy: Roll(18, 2),
    weapon: 'weapon.spear',
    powerTenths: 15,
    ac: Roll(2),
  ),
  SummonDef(
    'summon.demogorgon',
    Family.unknown,
    endurance: Roll(18, 5),
    resistance: Roll(5, 5),
    accuracy: Roll(17, 3),
    weapon: 'natural.claws',
    powerTenths: 40,
    ac: Roll(4),
  ),
  SummonDef(
    'summon.dullahan',
    Family.unknown,
    endurance: Roll(10, 5),
    resistance: Roll(20),
    accuracy: Roll(17),
    weapon: 'weapon.lance',
    powerTenths: 10,
    ac: Roll(3),
  ),
  SummonDef(
    'summon.ettin',
    Family.unknown,
    endurance: Roll(10, 5),
    resistance: Roll(10),
    accuracy: Roll(10, 9),
    weapon: 'weapon.club',
    powerTenths: 8,
    ac: Roll(1),
  ),
  SummonDef(
    'summon.hellhound',
    Family.unknown,
    endurance: Roll(14, 5),
    resistance: Roll(9, 5),
    accuracy: Roll(11, 5),
    weapon: 'natural.fangs',
    powerTenths: 30,
    ac: Roll(2),
  ),
  SummonDef(
    'summon.minotaur',
    Family.unknown,
    endurance: Roll(13, 5),
    resistance: Roll(11, 5),
    accuracy: Roll(14, 5),
    weapon: 'weapon.hand_axe',
    powerTenths: 30,
    ac: Roll(2),
  ),
];

/// 소환의 크리스탈이 부르는 셋(제9장 9.8). 레벨 30, 정신 지배 면역.
const SummonDef crystalDragon = SummonDef(
  'summon.crystal_dragon',
  Family.dragon,
  strength: Roll(25),
  mentality: Roll(20),
  concentration: Roll(20),
  endurance: Roll(30),
  resistance: Roll(20),
  accuracy: Roll(20),
  luck: Roll(20),
  weapon: 'breath.frost',
  fixedPower: Roll(255),
  ac: Roll(4),
  fixedLevel: 30,
  mindControlImmune: true,
);

const SummonDef crystalGolem = SummonDef(
  'summon.crystal_golem',
  Family.golem,
  strength: Roll(20),
  mentality: Roll(0),
  concentration: Roll(0),
  endurance: Roll(40),
  resistance: Roll(25),
  accuracy: Roll(13),
  luck: Roll(0),
  weapon: 'natural.bare_hands',
  fixedPower: Roll(150),
  ac: Roll(5),
  fixedLevel: 30,
  mindControlImmune: true,
);

const SummonDef archangel = SummonDef(
  'summon.archangel',
  Family.mage,
  strength: Roll(20),
  mentality: Roll(20),
  concentration: Roll(20),
  endurance: Roll(30),
  resistance: Roll(19),
  agility: Roll(20),
  accuracy: Roll(20),
  luck: Roll(20),
  weapon: 'natural.lightning',
  fixedPower: Roll(200),
  ac: Roll(5),
  fixedLevel: 30,
  mindControlImmune: true,
);

/// 필드에서 소환의 크리스탈을 쓰면: 드래곤 40% · 고렘 40% · 대천사장 20%.
SummonDef rollCrystalSummonOnField(Random rng) {
  final r = rng.nextInt(10);
  if (r < 4) return crystalDragon;
  if (r < 8) return crystalGolem;
  return archangel;
}

/// 전투에서 쓰면: 드래곤 1/3 · 고렘 2/3.
SummonDef rollCrystalSummonInBattle(Random rng) =>
    rng.nextInt(3) == 0 ? crystalDragon : crystalGolem;

/// 틀에서 보조 일원 한 명을 만든다.
///
/// [skill] 은 소환 마법 능력치 S(소환 문서는 일행 평균 레벨 × 5).
/// 레벨은 S ÷ 5, HP 는 인내력 × 레벨 × 10 으로 가득 찬다.
Member buildSummon(SummonDef def, {required int skill, required Random rng}) {
  final level = def.fixedLevel ?? summonLevel(skill);

  int power;
  final fixed = def.fixedPower;
  if (fixed != null) {
    power = fixed.roll(rng);
  } else {
    var tenths = def.powerTenths;
    final max = def.powerTenthsMax;
    if (max != null && max > tenths) {
      // 용의 브레스: 배율 1~5 를 정수로 굴린다.
      final steps = (max - tenths) ~/ 10 + 1;
      tenths += rng.nextInt(steps) * 10;
    }
    power = skill * tenths ~/ 10;
  }

  final skills = List<int>.filled(6, 0);
  for (final i in def.skillsFromSummon) {
    skills[i] = skill > 100 ? 100 : skill;
  }

  final m = Member(
    nameKey: def.key,
    gender: Gender.neutral,
    family: def.family,
    classId: def.classId,
    level: level,
    abilities: [
      def.strength.roll(rng),
      def.mentality.roll(rng),
      def.concentration.roll(rng),
      def.endurance.roll(rng),
      def.resistance.roll(rng),
      def.agility.roll(rng),
      def.accuracy.roll(rng),
      def.luck.roll(rng),
    ],
    skills: skills,
    weapon: def.equipWeapon,
    shield: def.equipShield,
    baseAc: def.ac.roll(rng),
    naturalWeapon: def.weapon,
    naturalPower: power,
    attackModeOverride: def.mode,
    mindControlImmune: def.mindControlImmune,
    trainedExp: trainedExpForLevel(level),
  );
  m.hp = m.maxHp;
  final perLevel = def.startMpPerLevel;
  m.mp = perLevel == null ? m.maxMp : m.mentality * level * perLevel;
  if (m.mp > m.maxMp) m.mp = m.maxMp;
  return m;
}

/// 소환 마법 n 단계(1~10)로 한 명을 부른다. 단계가 틀리면 null.
///
/// 전투가 「n 단계 소환이 일어났다」고 알리면, 다리 쪽이 이것으로 보조
/// 일원을 만들어 `setAssistant` 에 넘긴다.
Member? summonByTier(int tier, {required int skill, required Random rng}) {
  if (tier < 1 || tier > summonPools.length) return null;
  final pool = summonPools[tier - 1];
  return buildSummon(pool[rng.nextInt(pool.length)], skill: skill, rng: rng);
}
