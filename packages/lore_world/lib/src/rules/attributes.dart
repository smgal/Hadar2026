import '../domain/enums.dart';
import '../domain/member.dart';

/// 스크립트가 대원의 속성을 **이름으로** 읽고 쓰는 문.
///
/// 맵 스크립트는 `strength` · `hp` · `skill3` 같은 이름으로 대원을 만진다.
/// 그 이름들이 여기 한 곳에 있다 — 이름을 늘리면 [memberAttributeNames] 와
/// 두 함수가 같이 바뀌고, 시험이 셋이 어긋나지 않는지 본다.
///
/// | 이름 | 뜻 | 쓰기 |
/// |---|---|:-:|
/// | `strength` `mentality` `concentration` `endurance` `resistance` `agility` `accuracy` `luck` | 여덟 능력치 | ○ |
/// | `level` `hp` `mp` `exp` | 레벨 · 생명력 · 마법 지수 · 쓰지 않은 경험치 | ○ |
/// | `poison` `unconscious` `dead` | 상태 카운터 | ○ |
/// | `class` `family` `gender` | 계급 번호 · 계열 번호 · 성별 번호 | ○ |
/// | `ac` | 방어력(기본 방어 + 갑옷 − 갑옷 파괴) | ○ (기본 방어를 고친다) |
/// | `skill1` … `skill6` | 여섯 기술치 | ○ |
/// | `trainedexp` | 누적 수련치 | ○ |
/// | `maxhp` `maxmp` | 최대 생명력 · 최대 마법 지수 | ✕ (파생값) |
const List<String> memberAttributeNames = [
  'strength',
  'mentality',
  'concentration',
  'endurance',
  'resistance',
  'agility',
  'accuracy',
  'luck',
  'level',
  'hp',
  'mp',
  'exp',
  'poison',
  'unconscious',
  'dead',
  'class',
  'family',
  'gender',
  'ac',
  'skill1',
  'skill2',
  'skill3',
  'skill4',
  'skill5',
  'skill6',
  // 아래 셋은 기획서의 이름 목록에는 없지만 스크립트가 물을 만한 것이다.
  'trainedexp',
  'maxhp',
  'maxmp',
];

const Map<String, Ability> _abilityNames = {
  'strength': Ability.strength,
  'mentality': Ability.mentality,
  'concentration': Ability.concentration,
  'endurance': Ability.endurance,
  'resistance': Ability.resistance,
  'agility': Ability.agility,
  'accuracy': Ability.accuracy,
  'luck': Ability.luck,
};

/// `skill1` ~ `skill6` 이면 자리 번호(0~5), 아니면 null.
int? _skillIndex(String name) {
  if (name.length != 6 || !name.startsWith('skill')) return null;
  final n = name.codeUnitAt(5) - 0x30;
  return n >= 1 && n <= 6 ? n - 1 : null;
}

/// 대원의 속성 하나를 이름으로 읽는다. 모르는 이름이면 null.
///
/// 이름은 대소문자를 가리지 않는다. `class` 는 계급 번호, `family` 와
/// `gender` 는 저장 번호(`wire`), `ac` 는 **계산된** 방어력이다.
int? readAttribute(Member member, String name) {
  final key = name.toLowerCase();
  final ability = _abilityNames[key];
  if (ability != null) return member.ability(ability);
  final skill = _skillIndex(key);
  if (skill != null) return member.skills[skill];
  return switch (key) {
    'level' => member.level,
    'hp' => member.hp,
    'mp' => member.mp,
    'exp' => member.exp,
    'poison' => member.poison,
    'unconscious' => member.unconscious,
    'dead' => member.dead,
    'class' => member.classId,
    'family' => member.family.wire,
    'gender' => member.gender.wire,
    'ac' => member.ac,
    'trainedexp' => member.trainedExp,
    'maxhp' => member.maxHp,
    'maxmp' => member.maxMp,
    _ => null,
  };
}

/// 대원의 속성 하나를 이름으로 쓴다. 썼으면 true.
///
/// 모르는 이름, 읽기 전용 이름(`maxhp` · `maxmp`), 뜻이 없는 값(없는 계열·
/// 성별 번호)이면 **아무것도 바꾸지 않고** false. 던지지 않는다.
///
/// **한 칸만 쓴다.** 원작 스크립트는 속성을 여러 줄에 걸쳐 쓰고 마지막에
/// 한 번 「정리」한다. 그래서 여기서는 다른 칸을 따라 고치지 않는다 —
/// 인내력을 쓰기 전에 생명력을 먼저 써도 깎이지 않는다. 다 쓴 뒤
/// [reviseMember] 를 부르면 생명력·마법 지수가 최대치 안으로 들어온다.
///
/// * 음수는 0 으로 올린다(`level` 은 1).
/// * `skillN` 은 0~100.
/// * `ac` 는 파생값이다. 쓰면 **기본 방어**를 고쳐서 계산된 방어력이 그 값이
///   되게 한다(갑옷이 주는 몫과 갑옷 파괴로 깎인 몫은 그대로 둔다).
bool writeAttribute(Member member, String name, int value) {
  final key = name.toLowerCase();
  final floor = value < 0 ? 0 : value;

  final ability = _abilityNames[key];
  if (ability != null) {
    member.setAbility(ability, floor);
    return true;
  }
  final skill = _skillIndex(key);
  if (skill != null) {
    member.skills[skill] = floor > 100 ? 100 : floor;
    return true;
  }
  switch (key) {
    case 'level':
      member.level = value < 1 ? 1 : value;
    case 'hp':
      member.hp = floor;
    case 'mp':
      member.mp = floor;
    case 'exp':
      member.exp = floor;
    case 'trainedexp':
      member.trainedExp = floor;
    case 'poison':
      member.poison = floor;
    case 'unconscious':
      member.unconscious = floor;
    case 'dead':
      member.dead = floor;
    case 'class':
      member.classId = floor;
    case 'family':
      if (!Family.values.any((f) => f.wire == value)) return false;
      member.family = Family.fromWire(value);
    case 'gender':
      if (!Gender.values.any((g) => g.wire == value)) return false;
      member.gender = Gender.fromWire(value);
    case 'ac':
      final base = floor - member.armourPower + member.acPenalty;
      member.baseAc = base < 0 ? 0 : base;
    default:
      return false;
  }
  return true;
}

/// 속성을 여러 개 쓴 뒤의 「정리」. 생명력·마법 지수를 최대치 안으로 넣는다.
///
/// [fill] 이 참이면 둘 다 최대치로 채운다(적 데이터에서 막 만든 대원).
void reviseMember(Member member, {bool fill = false}) {
  if (fill || member.hp > member.maxHp) member.hp = member.maxHp;
  if (fill || member.mp > member.maxMp) member.mp = member.maxMp;
  if (member.hp < 0) member.hp = 0;
  if (member.mp < 0) member.mp = 0;
}
