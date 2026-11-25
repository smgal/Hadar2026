/// 닫힌 열거 모음.
///
/// 경계를 넘는 것(저장·스크립트)은 전부 명시적 정수 `wire` 를 갖는다.
/// `Enum.index` 는 줄 순서를 바꾸면 값이 바뀌므로 쓰지 않는다.
library;

/// 3부작의 편. 규칙은 전부 제3부 체계이고, 편은 **자료**(1탄 전용 계급·
/// 무기, 시작 달력, 동료 명부)만 가른다.
enum Episode {
  ep1(1),
  ep2(2),
  ep3(3);

  const Episode(this.number);

  final int number;

  static Episode? fromNumber(int n) {
    for (final e in values) {
      if (e.number == n) return e;
    }
    return null;
  }
}

enum Gender {
  male(0),
  female(1),

  /// 보조 일원(소환수·설득한 적).
  neutral(2);

  const Gender(this.wire);

  final int wire;

  static Gender fromWire(int w) =>
      values.firstWhere((g) => g.wire == w, orElse: () => Gender.neutral);
}

/// 계열(제7장 7.2).
///
/// 전투사·마법사만 명령을 받는다. 나머지 다섯은 보조 일원의 분류이고
/// 공격 방식(한 명/전체)을 정한다.
enum Family {
  fighter(0),
  mage(1),
  elemental(2),
  giant(3),
  golem(4),
  dragon(5),
  unknown(6);

  const Family(this.wire);

  final int wire;

  static Family fromWire(int w) =>
      values.firstWhere((f) => f.wire == w, orElse: () => Family.unknown);
}

/// 여덟 능력치(제7장 7.1). `index8` 은 저장 배열의 자리다.
enum Ability {
  strength(0),
  mentality(1),
  concentration(2),
  endurance(3),
  resistance(4),
  agility(5),
  accuracy(6),
  luck(7);

  const Ability(this.index8);

  final int index8;
}

/// 무기 계통. `special` 은 보조 일원의 타고난 무기다.
enum WeaponKind { bare, slash, chop, pierce, shoot, special }

/// 화면에 보이는 상태. 심각한 순으로 하나만 보인다(제7장 7.7).
enum Condition { good, poisoned, unconscious, dead }

/// 보조 일원의 자동 공격 방식(제8장 8.5).
enum AttackMode { single, all }

/// 장착 칸 셋.
enum EquipSlot { weapon, shield, armour }

/// 맵 유형(제11장 11.2). 시간 경과와 시야가 여기에 달렸다.
enum MapKind { town, field, cave, fortress }

/// 한 걸음이 들어서는 칸의 종류(부록 D.4).
enum Terrain {
  /// 일반 통행 칸.
  normal,

  /// 물. 물 위를 걷는 효과가 있을 때만 들어간다.
  water,
  swamp,
  lava,

  /// 특수 이벤트 칸. 시간도 조우도 없다.
  event,
}

/// 병원의 네 가지 치료(제10장 10.7).
enum Treatment { wounds, poison, consciousness, revival }

/// 훈련 시설. 군사 훈련소는 전투사, 마법 학교는 마법사.
enum TrainingFacility { military, magicSchool }

/// 상점. 물품마다 파는 곳이 정해져 있다.
enum ShopKind { herb, goods }

/// 필드 초능력(제9장 9.6).
enum FieldEsp {
  /// 투시.
  clairvoyance,

  /// 예언.
  prophecy,

  /// 독심.
  mindReading,

  /// 천리안.
  farSight,

  /// 염력 — 전투 전용이라 필드에서는 항상 거절된다.
  telekinesis,
}

/// 일행 공용 효과 셋(다음 휴식까지).
enum FieldBuff { levitation, waterWalk, swampWalk }

/// 지도가 있어야 끝낼 수 있는 일. 이 패키지는 **무엇을** 할지만 말하고,
/// 지도를 가진 쪽(앱)이 실제로 한다.
enum MapAction {
  /// 주시자의 눈 · 수정 구슬.
  showMap,

  /// 기화 이동 — 바라보는 쪽으로 2칸.
  etherealMove,

  /// 지형 변화 — 앞 1칸을 바닥으로.
  terraform,

  /// 대지형 변화 — 세로 5칸 · 가로 4칸.
  greatTerraform,

  /// 공간 이동 · 이동 구슬 — `distance` 칸.
  teleport,

  /// 투시 — 숨은 이벤트 칸을 드러낸다.
  revealHidden,

  /// 예언 — 다음 목표를 말해 준다.
  prophecy,

  /// 천리안 — `distance` 칸까지 내다본다.
  farSight,
}

/// 자리 번호. 0 이 주인공, 1~4 가 동료, 5 가 보조 일원이다.
abstract final class Seat {
  static const int protagonist = 0;
  static const int firstCompanion = 1;
  static const int lastCompanion = 4;
  static const int assistant = 5;
  static const int count = 6;

  static bool isValid(int seat) => seat >= 0 && seat < count;
  static bool isCompanion(int seat) =>
      seat >= firstCompanion && seat <= lastCompanion;
}
