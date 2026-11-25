/// 기술 이름표 — 공격 마법 · 특수 마법 · 치료 마법 · 초능력 · 소환, 그리고
/// 적이 쓰는 마법 11종.
///
/// 기획서 제9장의 표를 옮긴 것이다. 이름은 **표시용**이므로 view 가 갖는다 —
/// `lore_battle` 은 기술을 id 로만 다룬다(`분류 × 100 + 단계`).
library;

import 'package:lore_battle/lore_battle.dart';

/// 한 명 공격 1~10단계 (9.2).
const List<String> singleAttackNames = [
  '마법 화살',
  '마법 화구',
  '마법 단창',
  '독 바늘',
  '마법 발화',
  '냉동 광선',
  '춤추는 검',
  '맥동 광선',
  '직격 뇌전',
  '필멸 주문',
];

/// 전체 공격 1~10단계 (9.2).
const List<String> areaAttackNames = [
  '공기 폭풍',
  '열선 파동',
  '초음파',
  '유독 가스',
  '초냉기',
  '화염 지대',
  '브리자드',
  '에너지 장막',
  '인공 지진',
  '차원 이탈',
];

/// 특수 마법 다섯 가지. 1~5단계는 "한명", 6~10단계는 "모두" 가 앞에 붙는다
/// (9.5).
const List<String> specialMagicNames = [
  '기술 무력화',
  '방어 무력화',
  '능력 저하',
  '마법 불능',
  '탈 초인화',
];

/// 제1부 전용 특수 마법 (1st/07 7.5).
const String partOnePoisonName = '독';

/// 치료 마법 다섯 가지. 특수 마법과 같은 방식으로 "한명"/"모두" 가 붙는다
/// (9.4).
const List<String> cureMagicNames = ['치료', '독 제거', '의식 돌림', '부활', '복합 치료'];

/// 전투 초능력 여섯 가지, `espSpecs` 순서 (9.6).
const Map<EspAbility, String> espNames = {
  EspAbility.persuade: '독심',
  EspAbility.fusion: '수소 핵융합',
  EspAbility.fear: '공포 생성',
  EspAbility.illusion: '환상 생성',
  EspAbility.metabolism: '신진 대사 조절',
  EspAbility.astral: '유체 이탈',
};

/// 소환 마법 1~10단계 (9.7).
const List<String> summonMagicNames = [
  '불의 정령 소환',
  '물의 정령 소환',
  '공기의 정령 소환',
  '땅의 정령 소환',
  '죽은 자의 소생',
  '다른 차원 생물 소환',
  '거인을 부름',
  '고렘을 부름',
  '용을 부름',
  '라이칸스로프 소환',
];

/// 적이 쓰는 마법 (8.6).
const Map<EnemySpellKind, String> enemySpellNames = {
  EnemySpellKind.shock: '충격',
  EnemySpellKind.chill: '냉기',
  EnemySpellKind.pain: '고통',
  EnemySpellKind.freeze: '혹한',
  EnemySpellKind.flame: '화염',
  EnemySpellKind.lightning: '번개',
  EnemySpellKind.heatWave: '열파',
  EnemySpellKind.energy: '에너지',
  EnemySpellKind.ultrasonic: '초음파',
  EnemySpellKind.coldSnap: '혹한기',
  EnemySpellKind.fireStorm: '화염폭풍',
};

String enemySpellName(EnemySpellKind kind) => enemySpellNames[kind] ?? '마법';

/// 기술 id 의 이름. 모르는 id 는 '알 수 없는 마법'.
///
/// `hd_battle_text` 의 `magicName` 과 같은 자리다. id 체계만 다르다 —
/// 101~110 한 명 공격, 201~210 전체 공격, 300 독(제1부), 301~310 특수,
/// 401~410 치료, 501~506 초능력, 601~610 소환.
String magicName(int id) {
  final tier = tierOfSkill(id);
  String oneOrAll(List<String> names) =>
      '${tier <= 5 ? "한명" : "모두"} ${names[(tier - 1) % 5]}';
  return switch (categoryOfSkill(id)) {
    SkillCategory.attackOne => singleAttackNames[tier - 1],
    SkillCategory.attackAll => areaAttackNames[tier - 1],
    SkillCategory.special =>
      id == partOnePoisonSkillId
          ? partOnePoisonName
          : oneOrAll(specialMagicNames),
    SkillCategory.cure => oneOrAll(cureMagicNames),
    SkillCategory.esp => espNames[espAbilityOfSkill(id)] ?? '초능력',
    SkillCategory.summon => summonMagicNames[tier - 1],
    null => '알 수 없는 마법',
  };
}
