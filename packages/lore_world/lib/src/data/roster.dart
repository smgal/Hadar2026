import '../domain/enums.dart';
import '../domain/member.dart';
import '../model/world.dart';
import 'class_table.dart';
import 'level_table.dart';

/// 명부의 인물이 들어가는 자리.
enum RosterSeat {
  /// 1~4번 — `LoreWorld.join`.
  companion,

  /// 5번 — `LoreWorld.setAssistant`.
  assistant,
}

/// 합류할 수 있는 인물 한 명.
///
/// [build] 는 부를 때마다 **새** 대원을 만든다. 이름은 [Member.nameKey]
/// (`companion.<key>`)로만 싣고, 한국어는 `lore_world_text` 가 붙인다.
/// 만들어진 대원은 [Member.rosterKey] 에 자기 열쇠를 기억한다.
final class RosterEntry {
  const RosterEntry(this.key, this.episode, this.seat, this._builder);

  /// 맵 스크립트가 부르는 이름(`canopus`). **바꾸지 않는다.**
  final String key;
  final Episode episode;
  final RosterSeat seat;
  final Member Function() _builder;

  String get nameKey => 'companion.$key';

  /// 합류할 준비가 된 새 대원.
  Member build() {
    final m = _builder();
    m.rosterKey = key;
    m.nameKey ??= nameKey;
    return m;
  }
}

const Gender _male = Gender.male;
const Gender _female = Gender.female;
const Family _f = Family.fighter;
const Family _m = Family.mage;

/// 합류하는 인물을 만든다.
///
/// HP 는 인내력 × 레벨 × 10, 마법 지수는 0(쉬면 찬다), 경험치 0,
/// 누적 수련치는 그 레벨의 필요치다(제4장 4.3).
Member _companion(
  String key,
  Gender gender,
  Family family,
  int classId,
  int level,
  List<int> abilities,
  List<int> skills, {
  String? weapon,
  String? shield,
  String? armour,
  int? baseAc,
  int? hp,
  int unconscious = 0,
  bool startingMp = false,
}) {
  final m = Member(
    nameKey: 'companion.$key',
    rosterKey: key,
    gender: gender,
    family: family,
    classId: classId,
    level: level,
    abilities: abilities,
    skills: skills,
    weapon: weapon,
    shield: shield,
    armour: armour,
    baseAc: baseAc ?? (family == Family.fighter ? 2 : 0),
    trainedExp: trainedExpForLevel(level),
    unconscious: unconscious,
  );
  m.hp = hp ?? m.maxHp;
  // 생성 직후의 시작 상태 규칙: 마법사만 정신력 × 10.
  m.mp = startingMp && family == Family.mage ? m.maxMp : 0;
  return m;
}

/// 5번 자리에 들어가는, 계급 없는 보조 일원.
Member _assistant(
  String key,
  int level,
  List<int> abilities, {
  Gender gender = Gender.neutral,
  List<int> skills = const [0, 0, 0, 0, 0, 0],
  int baseAc = 0,
  int? naturalPower,
  int? hp,
}) {
  final m = Member(
    nameKey: 'companion.$key',
    rosterKey: key,
    gender: gender,
    family: Family.unknown,
    level: level,
    abilities: abilities,
    skills: skills,
    baseAc: baseAc,
    naturalWeapon: naturalPower == null ? null : naturalWeaponUnknown,
    naturalPower: naturalPower,
    trainedExp: trainedExpForLevel(level),
  );
  m.hp = hp ?? m.maxHp;
  return m;
}

List<int> _req(Family family, int classId) =>
    classOf(family, classId)!.requirements;

RosterEntry _e(Episode ep, String key, Member Function() build) =>
    RosterEntry(key, ep, RosterSeat.companion, build);

RosterEntry _a(Episode ep, String key, Member Function() build) =>
    RosterEntry(key, ep, RosterSeat.assistant, build);

Map<String, RosterEntry> _index(List<RosterEntry> entries) => {
  for (final e in entries) e.key: e,
};

// ───────────────────────────────────────────────────────────────
// 제3부 (04_등장인물 4.3)
// 능력치: 체력/정신력/집중력/인내력/저항력/민첩성/정확성/행운
// ───────────────────────────────────────────────────────────────

/// 제3부의 동료 열둘과 드라코니안 수감자.
final Map<String, RosterEntry> rosterEp3 = _index([
  _e(
    Episode.ep3,
    'canopus',
    () => _companion(
      'canopus',
      _male,
      _f,
      ClassId.paladin,
      5,
      [19, 6, 4, 18, 17, 20, 17, 12],
      // 전사의 둘째 자리는 치료 마법 능력치다.
      [20, 10, 5, 0, 50, 10],
    ),
  ),
  _e(
    Episode.ep3,
    'alcor',
    () => _companion(
      'alcor',
      _male,
      _f,
      ClassId.swordsman,
      2,
      [15, 5, 6, 12, 15, 14, 16, 12],
      [40, 0, 0, 0, 0, 10],
      weapon: 'weapon.sabre',
      armour: 'armour.leather',
    ),
  ),
  _e(
    Episode.ep3,
    'mizar',
    () => _companion(
      'mizar',
      _male,
      _f,
      ClassId.knight,
      2,
      [13, 6, 8, 15, 16, 16, 15, 14],
      [20, 10, 5, 0, 10, 10],
      weapon: 'weapon.gladius',
      shield: 'shield.leather',
      armour: 'armour.ring_mail',
    ),
  ),
  // 원작 데이터 그대로 링 메일을 입고 온다. 마법사 계열이라 방어 효과는 없다.
  _e(
    Episode.ep3,
    'antares_jr',
    () => _companion(
      'antares_jr',
      _male,
      _m,
      ClassId.wizard,
      15,
      [10, 20, 20, 15, 17, 19, 17, 18],
      [60, 30, 30, 0, 0, 0],
      armour: 'armour.ring_mail',
    ),
  ),
  // 싸워 이긴 직후라 HP 1 로 들어온다.
  _e(
    Episode.ep3,
    'pollux',
    () => _companion(
      'pollux',
      _female,
      _f,
      ClassId.assassin,
      5,
      [15, 19, 20, 11, 18, 20, 17, 10],
      [10, 0, 35, 10, 0, 20],
      weapon: 'weapon.rapier',
      armour: 'armour.leather',
      hp: 1,
    ),
  ),
  _e(
    Episode.ep3,
    'altair',
    () => _companion(
      'altair',
      _male,
      _f,
      ClassId.fighter,
      3,
      [19, 4, 3, 18, 10, 16, 15, 14],
      [10, 30, 10, 10, 10, 10],
      weapon: 'weapon.hand_axe',
      shield: 'shield.small_steel',
      armour: 'armour.ring_mail',
    ),
  ),
  _e(
    Episode.ep3,
    'vega',
    () => _companion(
      'vega',
      _female,
      _m,
      ClassId.conjurer,
      4,
      [6, 16, 19, 10, 17, 9, 15, 18],
      [10, 40, 10, 10, 10, 10],
      armour: 'armour.leather',
    ),
  ),
  _e(
    Episode.ep3,
    'algol',
    () => _companion(
      'algol',
      _male,
      _m,
      ClassId.sorcerer,
      3,
      [10, 17, 15, 8, 12, 11, 14, 20],
      [10, 20, 20, 0, 0, 35],
      armour: 'armour.leather',
    ),
  ),
  _e(
    Episode.ep3,
    'proxima',
    () => _companion(
      'proxima',
      _male,
      _f,
      ClassId.hunter,
      4,
      [15, 5, 6, 16, 11, 16, 19, 10],
      [0, 0, 10, 40, 0, 10],
      weapon: 'weapon.bow',
      armour: 'armour.ring_mail',
      baseAc: 1,
    ),
  ),
  _e(
    Episode.ep3,
    'denebola',
    () => _companion(
      'denebola',
      _male,
      _f,
      ClassId.monk,
      10,
      [20, 5, 6, 18, 12, 15, 17, 10],
      [0, 0, 0, 0, 0, 60],
      armour: 'armour.chain_mail',
      baseAc: 3,
    ),
  ),
  _e(
    Episode.ep3,
    'capella',
    () => _companion(
      'capella',
      _female,
      _m,
      ClassId.mage,
      2,
      [5, 15, 20, 10, 19, 11, 17, 15],
      [10, 10, 10, 10, 10, 0],
    ),
  ),
  _e(
    Episode.ep3,
    'becrux',
    () => _companion(
      'becrux',
      _male,
      _m,
      ClassId.mage,
      9,
      [10, 17, 18, 12, 15, 14, 16, 12],
      [40, 40, 40, 0, 30, 20],
      armour: 'armour.leather',
      baseAc: 1,
    ),
  ),
  // 적 「드라코니안」(제12장 No.48)을 변환 규칙으로 옮긴 보조 일원.
  _a(
    Episode.ep3,
    'draco_prisoner',
    () => assistantFromEnemy(
      const EnemyStatBlock(
        nameKey: 'companion.draco_prisoner',
        level: 12,
        strength: 30,
        mentality: 20,
        endurance: 30,
        agility: 18,
        physicalResist: 40,
        physicalAccuracy: 18,
        defence: 4,
      ),
    ),
  ),
]);

// ───────────────────────────────────────────────────────────────
// 제1부 (1st/04_등장인물 4.2~4.4, 1st/07 7.3)
// ───────────────────────────────────────────────────────────────

/// 초기 동료: 원작 능력치 여덟을 그대로 쓰고, 기술치는 그 계급의 조건을
/// 만족하는 최소값, 레벨 1, 장비 없음. 시작 상태 규칙(HP = 인내력 × 10,
/// MP = 마법사만 정신력 × 10)을 쓴다.
Member _initial(
  String key,
  Gender gender,
  Family family,
  int classId,
  List<int> abilities,
) => _companion(
  key,
  gender,
  family,
  classId,
  1,
  abilities,
  _req(family, classId),
  startingMp: true,
);

/// 생성 마지막 단계에서 넷을 고르는 초기 동료 열 명의 열쇠(원작 순서).
const List<String> initialCompanionsEp1 = [
  'hercules',
  'titan',
  'merlin',
  'betelgeuse',
  'genius_kie',
  'bellatrix',
  'regulus',
  'procyon',
  'arcturus',
  'algol',
];

/// 제1부의 초기 동료 열, 합류 인물 다섯, 보조 일원 셋.
final Map<String, RosterEntry> rosterEp1 = _index([
  _e(
    Episode.ep1,
    'hercules',
    () => _initial('hercules', _male, _f, ClassId.knight, [
      17,
      5,
      5,
      17,
      11,
      15,
      15,
      10,
    ]),
  ),
  _e(
    Episode.ep1,
    'titan',
    () => _initial('titan', _male, _f, ClassId.knight, [
      14,
      5,
      7,
      14,
      14,
      16,
      17,
      7,
    ]),
  ),
  _e(
    Episode.ep1,
    'merlin',
    () => _initial('merlin', _male, _m, ClassId.mage, [
      11,
      19,
      14,
      5,
      5,
      7,
      18,
      15,
    ]),
  ),
  _e(
    Episode.ep1,
    'betelgeuse',
    () => _initial('betelgeuse', _female, _m, ClassId.mage, [
      14,
      17,
      5,
      7,
      7,
      11,
      15,
      14,
    ]),
  ),
  _e(
    Episode.ep1,
    'genius_kie',
    () => _initial('genius_kie', _male, _f, ClassId.paladin, [
      14,
      11,
      7,
      11,
      11,
      11,
      20,
      9,
    ]),
  ),
  _e(
    Episode.ep1,
    'bellatrix',
    () => _initial('bellatrix', _female, _f, ClassId.paladin, [
      14,
      11,
      5,
      11,
      14,
      14,
      15,
      11,
    ]),
  ),
  _e(
    Episode.ep1,
    'regulus',
    () => _initial('regulus', _male, _f, ClassId.monk, [
      19,
      5,
      5,
      17,
      7,
      15,
      13,
      11,
    ]),
  ),
  _e(
    Episode.ep1,
    'procyon',
    () => _initial('procyon', _male, _f, ClassId.monk, [
      17,
      5,
      5,
      17,
      11,
      17,
      14,
      9,
    ]),
  ),
  // 원작의 닌자 → 암살자.
  _e(
    Episode.ep1,
    'arcturus',
    () => _initial('arcturus', _male, _f, ClassId.assassin, [
      7,
      5,
      11,
      11,
      19,
      18,
      7,
      15,
    ]),
  ),
  _e(
    Episode.ep1,
    'algol',
    () => _initial('algol', _female, _f, ClassId.assassin, [
      11,
      5,
      7,
      14,
      17,
      17,
      9,
      16,
    ]),
  ),

  // ── 합류 인물: 원작 능력치와 레벨·장비를 제3부 규칙으로 옮긴 것 ──
  // 정확성은 그 계급이 주로 쓰는 것(전투사는 무기, 마법사는 마법,
  // 에스퍼는 초능력)의 원작 값을 쓴다.
  _e(
    Episode.ep1,
    'polaris',
    () => _companion(
      'polaris',
      _male,
      _f,
      ClassId.paladin,
      3,
      [8, 8, 0, 10, 10, 18, 18, 10],
      _req(_f, ClassId.paladin),
      weapon: 'weapon.long_sword',
      shield: 'shield.leather',
      armour: 'armour.leather',
    ),
  ),
  // 심한 부상 — HP 1 로 들어온다. 원작 장비(장검·가죽 방패)는 사냥꾼이
  // 쓸 수 없어 효과가 없다.
  _e(
    Episode.ep1,
    'rigel',
    () => _companion(
      'rigel',
      _male,
      _f,
      ClassId.hunter,
      4,
      [10, 0, 0, 10, 0, 20, 20, 10],
      _req(_f, ClassId.hunter),
      weapon: 'weapon.long_sword',
      shield: 'shield.leather',
      armour: 'armour.leather',
      hp: 1,
    ),
  ),
  _e(
    Episode.ep1,
    'lore_hunter',
    () => _companion(
      'lore_hunter',
      _male,
      _f,
      ClassId.hunter,
      10,
      [20, 0, 0, 19, 0, 19, 19, 10],
      _req(_f, ClassId.hunter),
      weapon: 'weapon.mace',
      shield: 'shield.small_steel',
      armour: 'armour.leather',
    ),
  ),
  // 혼령 → 대마법사. 육체가 없어 HP 0 · 의식불명으로 들어오고, 한 번 쉬면
  // HP 1 로 깨어난다.
  _e(
    Episode.ep1,
    'red_antares',
    () => _companion(
      'red_antares',
      _male,
      _m,
      ClassId.archmage,
      15,
      [0, 20, 0, 10, 15, 0, 20, 10],
      _req(_m, ClassId.archmage),
      hp: 0,
      unconscious: 1,
    ),
  ),
  // 에스퍼(제1부 전용). 원작의 초능력 레벨 11 · 마법 레벨 6 을 레벨 × 5 로
  // 옮겼다: 초자연 55, 공격·변화·치료 30.
  _e(
    Episode.ep1,
    'spica',
    () => _companion(
      'spica',
      _female,
      _m,
      ClassId.esper,
      11,
      [10, 17, 20, 9, 15, 7, 20, 10],
      [30, 30, 30, 0, 55, 0],
      weapon: 'weapon.dagger',
      shield: 'shield.leather',
      armour: 'armour.leather',
    ),
  ),

  // ── 보조 일원 ──
  _a(
    Episode.ep1,
    'mad_joe',
    () => _assistant('mad_joe', 1, [8, 0, 0, 8, 0, 8, 8, 10], gender: _male),
  ),
  _a(
    Episode.ep1,
    'skeleton',
    () => _assistant(
      'skeleton',
      5,
      [10, 0, 0, 19, 0, 12, 12, 10],
      baseAc: 3,
      naturalPower: 20,
    ),
  ),
  // 적 데이터는 레벨 19 지만 합류할 때는 레벨 17 로 계산한다.
  _a(
    Episode.ep1,
    'draconian',
    () => _assistant(
      'draconian',
      17,
      [30, 20, 0, 30, 30, 18, 18, 10],
      baseAc: 7,
      naturalPower: 44,
    ),
  ),
]);

// ───────────────────────────────────────────────────────────────
// 제2부 (2nd/04_등장인물 4.2~4.3) — 제3부 체계와 같아 그대로 쓴다.
// ───────────────────────────────────────────────────────────────

/// 제2부의 동료 여덟과 보조 일원 둘.
final Map<String, RosterEntry> rosterEp2 = _index([
  _e(
    Episode.ep2,
    'hercules',
    () => _companion(
      'hercules',
      _male,
      _f,
      ClassId.knight,
      2,
      [18, 5, 6, 15, 12, 14, 14, 12],
      [10, 10, 5, 0, 20, 5],
      weapon: 'weapon.sabre',
      shield: 'shield.leather',
      armour: 'armour.leather',
    ),
  ),
  _e(
    Episode.ep2,
    'titan',
    () => _companion(
      'titan',
      _male,
      _f,
      ClassId.fighter,
      2,
      [19, 3, 4, 17, 10, 13, 11, 14],
      [10, 10, 10, 10, 10, 10],
      weapon: 'weapon.gladius',
      armour: 'armour.ring_mail',
    ),
  ),
  _e(
    Episode.ep2,
    'merlin',
    () => _companion(
      'merlin',
      _male,
      _m,
      ClassId.mage,
      2,
      [5, 15, 16, 10, 14, 8, 13, 17],
      [20, 10, 10, 0, 10, 0],
      armour: 'armour.leather',
    ),
  ),
  // 원작 데이터는 남성이지만 오류로 본다(원작자 결정).
  _e(
    Episode.ep2,
    'betelgeuse',
    () => _companion(
      'betelgeuse',
      _female,
      _m,
      ClassId.conjurer,
      2,
      [7, 17, 15, 8, 12, 10, 15, 10],
      [10, 20, 10, 0, 0, 10],
      armour: 'armour.leather',
    ),
  ),
  _e(
    Episode.ep2,
    'mercury',
    () => _companion(
      'mercury',
      _male,
      _f,
      ClassId.assassin,
      2,
      [12, 5, 6, 11, 18, 19, 16, 19],
      [10, 0, 0, 20, 0, 20],
    ),
  ),
  _e(
    Episode.ep2,
    'polaris',
    () => _companion(
      'polaris',
      _male,
      _f,
      ClassId.paladin,
      4,
      [18, 10, 6, 12, 16, 14, 17, 12],
      [25, 10, 5, 0, 25, 10],
      weapon: 'weapon.scimitar',
      shield: 'shield.large_steel',
      armour: 'armour.scale',
    ),
  ),
  _e(
    Episode.ep2,
    'genius_kie',
    () => _companion(
      'genius_kie',
      _male,
      _f,
      ClassId.paladin,
      10,
      [19, 15, 10, 14, 18, 16, 18, 17],
      [25, 30, 30, 10, 40, 15],
      weapon: 'weapon.trident',
      shield: 'shield.chromatic',
      armour: 'armour.cuir_bouilli',
      baseAc: 3,
    ),
  ),
  _e(
    Episode.ep2,
    'regulus',
    () => _companion(
      'regulus',
      _male,
      _f,
      ClassId.monk,
      4,
      [19, 5, 6, 15, 10, 10, 17, 7],
      [0, 0, 0, 0, 0, 50],
      armour: 'armour.ring_mail',
    ),
  ),

  // ── 보조 일원 ──
  _a(
    Episode.ep2,
    'mad_joe',
    () => _assistant(
      'mad_joe',
      2,
      [10, 5, 6, 9, 5, 7, 5, 20],
      gender: _male,
      skills: const [5, 5, 0, 0, 0, 20],
      baseAc: 1,
    ),
  ),
  // 산적 두목. 연전 끝에 쓰러뜨린 직후라 HP 1 로 들어온다.
  _a(
    Episode.ep2,
    'death_knight',
    () => _assistant(
      'death_knight',
      19,
      [35, 0, 0, 35, 25, 20, 20, 10],
      baseAc: 6,
      naturalPower: 48,
      hp: 1,
    ),
  ),
]);

/// 그 편의 명부.
Map<String, RosterEntry> rosterOf(Episode episode) => switch (episode) {
  Episode.ep1 => rosterEp1,
  Episode.ep2 => rosterEp2,
  Episode.ep3 => rosterEp3,
};
