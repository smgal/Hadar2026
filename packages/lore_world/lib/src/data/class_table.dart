import '../domain/enums.dart';

/// 계급 번호. 계열마다 1~7 이고, 8·9 는 제1부 전용이다.
abstract final class ClassId {
  // 전투사 계열
  static const int fighter = 1; // 투사
  static const int knight = 2; // 기사
  static const int swordsman = 3; // 검사
  static const int hunter = 4; // 사냥꾼
  static const int monk = 5; // 전투승
  static const int assassin = 6; // 암살자
  static const int paladin = 7; // 전사

  // 마법사 계열
  static const int mage = 1; // 메이지
  static const int conjurer = 2; // 컨져러
  static const int sorcerer = 3; // 주술사
  static const int wizard = 4; // 위저드
  static const int necromancer = 5; // 강령술사
  static const int archmage = 6; // 대마법사
  static const int timewalker = 7; // 타임워커

  // 제1부 전용
  static const int esper = 8; // 에스퍼 (마법사 계열로 둔다)
  static const int demigod = 9; // 반신반인 (계열은 그대로 남는다)

  /// 계급 없음 — 계열이 전투사·마법사가 아닌 보조 일원.
  static const int none = 0;
}

/// 기술치 자리(0~5). 전투사 계열.
abstract final class FighterSkill {
  static const int slash = 0; // 베는
  static const int chop = 1; // 찍는 — 전사는 이 자리가 치료 마법 능력치다
  static const int pierce = 2; // 찌르는
  static const int shoot = 3; // 쏘는
  static const int shield = 4; // 방패
  static const int bare = 5; // 맨손
}

/// 기술치 자리(0~5). 마법사 계열.
abstract final class MageSkill {
  static const int attack = 0; // 공격
  static const int change = 1; // 변화
  static const int cure = 2; // 치료
  static const int special = 3; // 특수
  static const int esp = 4; // 초자연
  static const int summon = 5; // 소환
}

const List<String> fighterSkillKeys = [
  'skill.slash',
  'skill.chop',
  'skill.pierce',
  'skill.shoot',
  'skill.shield',
  'skill.bare',
];

const List<String> mageSkillKeys = [
  'skill.attack',
  'skill.change',
  'skill.cure',
  'skill.special',
  'skill.esp',
  'skill.summon',
];

/// 그 자리의 기술치가 무엇인지. 전사의 둘째 자리만 예외다.
String skillKey(Family family, int classId, int index) {
  if (index < 0 || index > 5) return 'skill.unknown';
  if (family == Family.mage) return mageSkillKeys[index];
  if (family == Family.fighter &&
      classId == ClassId.paladin &&
      index == FighterSkill.chop) {
    return 'skill.cure';
  }
  return fighterSkillKeys[index];
}

/// 계급 하나의 정의(제7장 7.3).
///
/// 조건·상한·장비 제한이 **계급의 정의 전체**다. 분기가 아니라 줄이다.
final class ClassDef {
  const ClassDef({
    required this.key,
    required this.family,
    required this.id,
    required this.requirements,
    required this.caps,
    this.weapons = const {},
    this.shield = false,
    this.selectable = true,
    this.onlyIn,
    this.powerColumn = 0,
  });

  /// `class.fighter` 같은 안정된 이름.
  final String key;
  final Family family;
  final int id;

  /// 이 계급이 되기 위한 기술치 최소값 여섯.
  final List<int> requirements;

  /// 훈련으로 올릴 수 있는 최대값 여섯. 0 이면 그 분야는 수련 불가.
  final List<int> caps;

  /// 쓸 수 있는 무기 계통.
  final Set<WeaponKind> weapons;
  final bool shield;

  /// 생성·전직 때 고를 수 있는가. 1탄 전용 계급은 이야기로만 얻는다.
  final bool selectable;

  /// 이 편에만 있는 계급이면 그 편. null 이면 어디에나.
  final Episode? onlyIn;

  /// 무기 공격력 표에서 읽을 열(0~6).
  final int powerColumn;

  bool meets(List<int> skills) {
    for (var i = 0; i < 6; i++) {
      if (skills[i] < requirements[i]) return false;
    }
    return true;
  }

  /// 갑옷 제한. 전투사 계열은 전부, 마법사 계열은 가죽 갑옷뿐이다.
  bool canWearArmour(int armourLegacyId) =>
      family == Family.fighter || armourLegacyId == 1;

  bool get isPaladin => family == Family.fighter && id == ClassId.paladin;
  bool get isDemigod => id == ClassId.demigod;
  bool get isEsper => family == Family.mage && id == ClassId.esper;
}

const Set<WeaponKind> _all = {
  WeaponKind.slash,
  WeaponKind.chop,
  WeaponKind.pierce,
  WeaponKind.shoot,
};

/// 계급 표. 순서는 계열 → 번호.
const List<ClassDef> classTable = [
  // ── 전투사 계열 ─────────────────────────────────────────────
  ClassDef(
    key: 'class.fighter',
    family: Family.fighter,
    id: ClassId.fighter,
    requirements: [10, 10, 10, 10, 10, 0],
    caps: [50, 50, 50, 50, 50, 50],
    weapons: _all,
    shield: true,
    powerColumn: 0,
  ),
  ClassDef(
    key: 'class.knight',
    family: Family.fighter,
    id: ClassId.knight,
    requirements: [10, 10, 5, 0, 20, 0],
    caps: [60, 60, 50, 0, 60, 50],
    weapons: {WeaponKind.slash, WeaponKind.chop, WeaponKind.pierce},
    shield: true,
    powerColumn: 1,
  ),
  ClassDef(
    key: 'class.swordsman',
    family: Family.fighter,
    id: ClassId.swordsman,
    requirements: [40, 0, 0, 0, 0, 0],
    caps: [100, 0, 0, 0, 30, 30],
    weapons: {WeaponKind.slash},
    shield: true,
    powerColumn: 2,
  ),
  ClassDef(
    key: 'class.hunter',
    family: Family.fighter,
    id: ClassId.hunter,
    requirements: [0, 5, 5, 40, 0, 0],
    caps: [0, 50, 50, 100, 0, 60],
    weapons: {WeaponKind.chop, WeaponKind.pierce, WeaponKind.shoot},
    powerColumn: 3,
  ),
  ClassDef(
    key: 'class.monk',
    family: Family.fighter,
    id: ClassId.monk,
    requirements: [0, 0, 0, 0, 0, 40],
    caps: [0, 0, 0, 0, 0, 100],
    powerColumn: 4,
  ),
  ClassDef(
    key: 'class.assassin',
    family: Family.fighter,
    id: ClassId.assassin,
    requirements: [10, 0, 0, 10, 0, 20],
    caps: [80, 0, 60, 80, 0, 70],
    weapons: {WeaponKind.slash, WeaponKind.pierce, WeaponKind.shoot},
    powerColumn: 5,
  ),
  ClassDef(
    key: 'class.paladin',
    family: Family.fighter,
    id: ClassId.paladin,
    requirements: [25, 0, 5, 0, 20, 10],
    caps: [60, 50, 50, 30, 70, 50],
    weapons: {WeaponKind.slash, WeaponKind.pierce, WeaponKind.shoot},
    shield: true,
    powerColumn: 6,
  ),
  // ── 마법사 계열 ─────────────────────────────────────────────
  ClassDef(
    key: 'class.mage',
    family: Family.mage,
    id: ClassId.mage,
    requirements: [10, 10, 10, 0, 0, 0],
    caps: [50, 30, 30, 0, 50, 0],
  ),
  ClassDef(
    key: 'class.conjurer',
    family: Family.mage,
    id: ClassId.conjurer,
    requirements: [0, 10, 10, 0, 0, 10],
    caps: [20, 50, 30, 10, 50, 30],
  ),
  ClassDef(
    key: 'class.sorcerer',
    family: Family.mage,
    id: ClassId.sorcerer,
    requirements: [0, 0, 10, 0, 0, 10],
    caps: [20, 20, 50, 10, 50, 50],
  ),
  ClassDef(
    key: 'class.wizard',
    family: Family.mage,
    id: ClassId.wizard,
    requirements: [40, 25, 25, 0, 0, 0],
    caps: [100, 60, 60, 50, 100, 0],
  ),
  ClassDef(
    key: 'class.necromancer',
    family: Family.mage,
    id: ClassId.necromancer,
    requirements: [20, 20, 40, 0, 0, 40],
    caps: [60, 70, 100, 100, 100, 100],
  ),
  ClassDef(
    key: 'class.archmage',
    family: Family.mage,
    id: ClassId.archmage,
    requirements: [10, 40, 30, 0, 0, 20],
    caps: [60, 100, 70, 100, 100, 50],
  ),
  ClassDef(
    key: 'class.timewalker',
    family: Family.mage,
    id: ClassId.timewalker,
    requirements: [40, 40, 40, 20, 20, 20],
    caps: [70, 100, 70, 50, 100, 100],
  ),
  // ── 제1부 전용 ─────────────────────────────────────────────
  // 에스퍼: 초능력이 중심이고 마법은 그 절반이다(1st/07 7.2).
  // 소환은 제1부에 없으므로 0.
  ClassDef(
    key: 'class.esper',
    family: Family.mage,
    id: ClassId.esper,
    requirements: [0, 0, 0, 0, 0, 0],
    caps: [50, 50, 50, 50, 100, 0],
    selectable: false,
    onlyIn: Episode.ep1,
  ),
  // 반신반인: 계열은 그대로 두고 계급만 바뀐다. 모든 분야를 끝까지 익힌다.
  ClassDef(
    key: 'class.demigod',
    family: Family.fighter,
    id: ClassId.demigod,
    requirements: [0, 0, 0, 0, 0, 0],
    caps: [100, 100, 100, 100, 100, 100],
    weapons: _all,
    shield: true,
    selectable: false,
    onlyIn: Episode.ep1,
    powerColumn: 0,
  ),
  ClassDef(
    key: 'class.demigod',
    family: Family.mage,
    id: ClassId.demigod,
    requirements: [0, 0, 0, 0, 0, 0],
    caps: [100, 100, 100, 100, 100, 100],
    selectable: false,
    onlyIn: Episode.ep1,
  ),
];

/// 계열과 번호로 계급을 찾는다. 계급이 없는 보조 일원이면 null.
ClassDef? classOf(Family family, int classId) {
  for (final c in classTable) {
    if (c.family == family && c.id == classId) return c;
  }
  return null;
}

/// 그 계열에서 고를 수 있는 계급(1~7) 전부.
List<ClassDef> selectableClasses(Family family) => [
  for (final c in classTable)
    if (c.family == family && c.selectable) c,
];

/// 지금 기술치로 될 수 있는 계급. 생성과 전직이 같은 표를 쓴다.
List<ClassDef> eligibleClasses(Family family, List<int> skills) => [
  for (final c in selectableClasses(family))
    if (c.meets(skills)) c,
];
