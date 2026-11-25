/// 이름표 — 키 · 열거값 → 한국어.
///
/// 모르는 키는 **키를 그대로** 돌려준다. 빈 글자가 되면 빠진 이름을 화면에서
/// 찾을 수 없다.
library;

import 'package:lore_world/lore_world.dart';

import 'josa.dart';

// ── 사람 ────────────────────────────────────────────────────────

/// 동료 이름 — `RosterEntry.key` → 이름. 편마다 따로다(같은 키가 다른
/// 편에 다른 사람으로 나올 수 있다 — 제1·2부의 `algol` 과 제3부의 `algol`).
const Map<Episode, Map<String, String>> companionNames = {
  Episode.ep3: {
    'canopus': '카노푸스',
    'alcor': '알코르',
    'mizar': '미자르',
    'antares_jr': '안타레스 Jr.',
    'pollux': '폴록스',
    'altair': '알타이르',
    'vega': '베가',
    'algol': '알골',
    'proxima': '프록시마',
    'denebola': '데네볼라',
    'capella': '카펠라',
    'becrux': '베크룩스',
    'draco_prisoner': '드라코니안 수감자',
  },
  Episode.ep1: {
    'hercules': '헤라클레스',
    'titan': '타이탄',
    'merlin': '머린',
    'betelgeuse': '베텔규스',
    'genius_kie': '지니어스 기',
    'bellatrix': '베라트릭스',
    'regulus': '레굴루스',
    'procyon': '프로키온',
    'arcturus': '아크투루스',
    'algol': '알골',
    'polaris': '폴라리스',
    'rigel': '리겔',
    'lore_hunter': '로어 헌터',
    'red_antares': '레드 안타레스',
    'spica': '스피카',
    'mad_joe': '미친 조',
    'skeleton': '스켈레톤',
    'draconian': '드라코니안',
  },
  Episode.ep2: {
    'hercules': '헤라클레스',
    'titan': '타이탄',
    'merlin': '머린',
    'betelgeuse': '베텔규스',
    'mercury': '머큐리',
    'polaris': '폴라리스',
    'genius_kie': '지니어스 기',
    'regulus': '레굴루스',
    'mad_joe': '미친 조',
    'death_knight': '죽음의 기사',
  },
};

/// 소환되는 존재 — `summon.` 뒤의 키 → 이름 (제9장 9.7 · 9.8).
///
/// `packages/lore_battle_text` 의 같은 표와 **같은 철자**여야 한다 — 전투가
/// 불러낸 소환수가 전투가 끝난 뒤 상태 창에 같은 이름으로 남아야 하므로.
/// 두 패키지는 서로를 모르므로 앱의 시험이 두 표를 맞춰 본다.
const Map<String, String> summonNames = {
  'fire_spirit': '불의 정령',
  'salamander': '사라만다',
  'azer': '아저',
  'ifrit': '이프리트',
  'nymph': '님프',
  'dryads': '드리어드스',
  'nereids': '네레이드스',
  'naiads': '나이어드스',
  'napaeae': '나파이어스',
  'oreads': '오레이어드스',
  'alseids': '알세이드스',
  'marid': '마리드',
  'kelpie': '켈피',
  'air_spirit': '공기의 정령',
  'sylph': '실프',
  'sylphid': '실피드',
  'djinni': '디지니',
  'invisible_stalker': '인비저블 스토커',
  'earth_spirit': '땅의 정령',
  'gnome': '놈',
  'dao': '다오',
  'ancient_knight': '에인션트 나이트',
  'ancient_mage': '에인션트 메이지',
  'bandersnatch': '밴더스내치',
  'carrion_crawler': '캐리온 크롤러',
  'centaur': '켄타우루스',
  'demogorgon': '데모고르곤',
  'dullahan': '듈라한',
  'ettin': '에틴',
  'hellhound': '헬하운드',
  'minotaur': '미노타우루스',
  'cloud_giant': '클라우드 자이언트',
  'fire_giant': '파이어 자이언트',
  'frost_giant': '프로스트 자이언트',
  'hill_giant': '힐 자이언트',
  'stone_giant': '스톤 자이언트',
  'storm_giant': '스토엄 자이언트',
  'clay_golem': '글레이 고렘',
  'flesh_golem': '프레쉬 고렘',
  'iron_golem': '아이언 고렘',
  'stone_golem': '스톤 고렘',
  'black_dragon': '블랙 드래곤',
  'blue_dragon': '블루 드래곤',
  'brass_dragon': '블래스 드래곤',
  'bronze_dragon': '브론즈 드래곤',
  'chromatic_dragon': '크로매틱 드래곤',
  'copper_dragon': '코퍼 드래곤',
  'gold_dragon': '골드 드래곤',
  'green_dragon': '그린 드래곤',
  'platinum_dragon': '플래티움 드래곤',
  'red_dragon': '레드 드래곤',
  'silver_dragon': '실버 드래곤',
  'white_dragon': '화이트 드래곤',
  'werewolf': '늑대 인간',
  'dragon_newt': '드래곤 뉴트',
  'crystal_dragon': '크리스탈 드래곤',
  'crystal_golem': '크리스탈 고렘',
  'archangel': '대천사장',
};

/// 동료 표의 이름. 모르면 키.
String companionName(Episode episode, String key) =>
    companionNames[episode]?[key] ?? key;

/// 화면에 쓸 이름.
///
/// 플레이어가 지은 이름이 있으면 그것, 명부에서 온 인물이면 동료 이름,
/// 소환수면 소환수 이름. 명부 인물은 합류할 때 앱이 [Member.name] 을 채워
/// 두므로 보통은 첫 줄에서 끝난다.
String memberName(Member m, {Episode episode = Episode.ep3}) {
  if (m.name.isNotEmpty) return m.name;
  final key = m.nameKey;
  if (key == null) return m.rosterKey == null ? '' : companionName(episode, m.rosterKey!);
  if (key.startsWith('companion.')) {
    return companionName(episode, key.substring('companion.'.length));
  }
  if (key.startsWith('summon.')) {
    final k = key.substring('summon.'.length);
    return summonNames[k] ?? key;
  }
  return key;
}

/// 「그」 · 「그녀」. 중성은 「그것」.
String pronoun(Gender g) => switch (g) {
  Gender.male => '그',
  Gender.female => '그녀',
  Gender.neutral => '그것',
};

String genderName(Gender g) => switch (g) {
  Gender.male => '남성',
  Gender.female => '여성',
  Gender.neutral => '중성',
};

String familyName(Family f) => switch (f) {
  Family.fighter => '전투사 계열',
  Family.mage => '마법사 계열',
  Family.elemental => '정령계',
  Family.giant => '거인족',
  Family.golem => '고렘족',
  Family.dragon => '드래곤족',
  Family.unknown => '불명',
};

const Map<String, String> classNames = {
  'class.fighter': '투사',
  'class.knight': '기사',
  'class.swordsman': '검사',
  'class.hunter': '사냥꾼',
  'class.monk': '전투승',
  'class.assassin': '암살자',
  'class.paladin': '전사',
  'class.mage': '메이지',
  'class.conjurer': '컨져러',
  'class.sorcerer': '주술사',
  'class.wizard': '위저드',
  'class.necromancer': '강령술사',
  'class.archmage': '대마법사',
  'class.timewalker': '타임워커',
  'class.esper': '에스퍼',
  'class.demigod': '반신반인',
};

/// 계열과 번호로 계급 이름. 계급이 없는 계열(정령·거인…)은 계열 이름.
String classNameOf(Family family, int classId) {
  final def = classOf(family, classId);
  if (def == null) return familyName(family);
  return classNames[def.key] ?? def.key;
}

String className(Member m) => classNameOf(m.family, m.classId);

String abilityName(Ability a) => switch (a) {
  Ability.strength => '체력',
  Ability.mentality => '정신력',
  Ability.concentration => '집중력',
  Ability.endurance => '인내력',
  Ability.resistance => '저항력',
  Ability.agility => '민첩성',
  Ability.accuracy => '정확성',
  Ability.luck => '행운',
};

/// 기술치 이름 — 개인의 상황 화면의 긴 꼴 (제13장 13.4).
const Map<String, String> skillNames = {
  'skill.slash': '베는 무기 기술치',
  'skill.chop': '찍는 무기 기술치',
  'skill.pierce': '찌르는 무기 기술치',
  'skill.shoot': '쏘는 무기 기술치',
  'skill.shield': '방패 사용 기술치',
  'skill.bare': '맨손 사용 기술치',
  'skill.attack': '공격 마법 능력치',
  'skill.change': '변화 마법 능력치',
  'skill.cure': '치료 마법 능력치',
  'skill.special': '특수 마법 능력치',
  'skill.esp': '초자연력 능력치',
  'skill.summon': '소환 마법 능력치',
};

/// 짧은 꼴 — 훈련소 목록처럼 칸이 좁은 곳.
const Map<String, String> skillShortNames = {
  'skill.slash': '베는 무기',
  'skill.chop': '찍는 무기',
  'skill.pierce': '찌르는 무기',
  'skill.shoot': '쏘는 무기',
  'skill.shield': '방패',
  'skill.bare': '맨손',
  'skill.attack': '공격 마법',
  'skill.change': '변화 마법',
  'skill.cure': '치료 마법',
  'skill.special': '특수 마법',
  'skill.esp': '초자연력',
  'skill.summon': '소환 마법',
};

/// 그 계급의 [index] 번째 기술치 이름. 전사의 둘째 자리는 「치료 마법 능력치」.
String skillNameOf(Family family, int classId, int index, {bool short = false}) {
  final key = skillKey(family, classId, index);
  return (short ? skillShortNames : skillNames)[key] ?? key;
}

String skillName(Member m, int index, {bool short = false}) =>
    skillNameOf(m.family, m.classId, index, short: short);

String conditionName(Condition c) => switch (c) {
  Condition.good => '좋음',
  Condition.poisoned => '중독',
  Condition.unconscious => '의식 불명',
  Condition.dead => '죽은 상태',
};

String treatmentName(Treatment t) => switch (t) {
  Treatment.wounds => '상처를 치료',
  Treatment.poison => '독을 제거',
  Treatment.consciousness => '의식의 회복',
  Treatment.revival => '부활',
};

String equipSlotName(EquipSlot s) => switch (s) {
  EquipSlot.weapon => '무기',
  EquipSlot.shield => '방패',
  EquipSlot.armour => '갑옷',
};

String fieldBuffName(FieldBuff b) => switch (b) {
  FieldBuff.levitation => '공중 부상',
  FieldBuff.waterWalk => '물 위를 걸음',
  FieldBuff.swampWalk => '늪 위를 걸음',
};

// ── 물건 ────────────────────────────────────────────────────────

/// 무기 · 방패 · 갑옷 · 물품 · 크리스탈 · 공용 물자, 그리고 보조 일원의
/// 타고난 무기 (제10장, 제9장 9.7).
const Map<String, String> itemNames = {
  // 베는 무기
  'weapon.short_sword': '단검',
  'weapon.gladius': '그라디우스',
  'weapon.sabre': '샤벨',
  'weapon.scimitar': '신월도',
  'weapon.falchion': '인월도',
  'weapon.long_sword': '장검',
  'weapon.flamberge': '프렘버그',
  // 찍는 무기
  'weapon.club': '곤봉',
  'weapon.hand_axe': '소형 도끼',
  'weapon.flail': '프레일',
  'weapon.war_hammer': '전투용 망치',
  'weapon.mace': '철퇴',
  'weapon.battle_axe': '양날 전투 도끼',
  'weapon.halberd': '핼버드',
  // 찌르는 무기
  'weapon.dagger': '단도',
  'weapon.lance': '기병창',
  'weapon.short_spear': '단창',
  'weapon.rapier': '레이피어',
  'weapon.trident': '삼지창',
  'weapon.lancer': '랜서',
  'weapon.poleaxe': '도끼창',
  // 쏘는 무기
  'weapon.blowpipe': '블로우 파이프',
  'weapon.shuriken': '표창',
  'weapon.sling': '투석기',
  'weapon.javelin': '투창',
  'weapon.bow': '활',
  'weapon.crossbow': '석궁',
  'weapon.arbalest': '아르발레스트',
  // 제1부 전용
  'weapon.flame_sword': '화염검',
  // 소환수만 쓰는 이름표
  'weapon.spear': '창',
  // 방패
  'shield.leather': '가죽 방패',
  'shield.small_steel': '소형 강철 방패',
  'shield.large_steel': '대형 강철 방패',
  'shield.chromatic': '크로매틱 방패',
  'shield.platinum': '플래티움 방패',
  // 갑옷
  'armour.leather': '가죽 갑옷',
  'armour.ring_mail': '링 메일',
  'armour.chain_mail': '체인 메일',
  'armour.scale': '미늘 갑옷',
  'armour.brigandine': '브리간디',
  'armour.cuir_bouilli': '큐일보일',
  'armour.lamellar': '라멜라',
  'armour.plate': '철판 갑옷',
  'armour.chromatic': '크로매틱 갑옷',
  'armour.platinum': '플래티움 갑옷',
  'armour.obsidian': '흑요석 갑옷',
  // 물품
  'item.hp_potion': '체력 회복약',
  'item.mp_potion': '마법 회복약',
  'item.antidote_herb': '해독의 약초',
  'item.awakening_herb': '의식의 약초',
  'item.revival_herb': '부활의 약초',
  'item.summon_scroll': '소환 문서',
  'item.big_torch': '대형 횃불',
  'item.seeing_orb': '수정 구슬',
  'item.flying_boots': '비행 부츠',
  'item.warp_orb': '이동 구슬',
  // 크리스탈
  'crystal.flame': '화염의 크리스탈',
  'crystal.frost': '한파의 크리스탈',
  'crystal.dark': '다크 크리스탈',
  'crystal.ebony': '에보니 크리스탈',
  'crystal.spirit': '영혼의 크리스탈',
  'crystal.summon': '소환의 크리스탈',
  'crystal.energy': '에너지 크리스탈',
  'crystal.chromatic': '크로매틱 크리스탈',
  'crystal.ball': '크리스탈 볼',
  // 공용 물자
  'supply.gold': '금화',
  'supply.food': '식량',
  'supply.arrows': '화살',
  // 보조 일원의 타고난 무기
  'natural.flame': '화염',
  'natural.tidal_wave': '해일',
  'natural.storm': '폭풍',
  'natural.earthquake': '지진',
  'natural.fangs': '이빨',
  'natural.tentacles': '촉수',
  'natural.claws': '발톱',
  'natural.rock': '바위',
  'natural.bone': '동물의 뼈',
  'natural.lightning': '번개 마법',
  'natural.clay': '점토',
  'natural.bare_hands': '맨손',
  'natural.iron_fist': '강철 주먹',
  'natural.attack': '무기',
  'breath.acid': '산성 가스',
  'breath.lightning': '전광',
  'breath.poison': '독가스',
  'breath.fire': '불꽃',
  'breath.chlorine': '염소 가스',
  'breath.cold': '한기',
  'breath.frost': '냉동 가스',
};

String itemName(String key) => itemNames[key] ?? key;

/// 지금 휘두르는 것의 이름. 맨손이면 「맨손」.
String weaponNameOf(Member m) {
  final natural = m.naturalWeapon;
  if (natural != null) return itemName(natural);
  final w = m.weapon;
  return w == null ? '맨손' : itemName(w);
}

// ── 마법 ────────────────────────────────────────────────────────

/// 마법과 초능력 이름 (제9장).
const Map<String, String> spellNames = {
  // 공격 — 한 명
  'magic.magic_arrow': '마법 화살',
  'magic.fireball': '마법 화구',
  'magic.magic_spear': '마법 단창',
  'magic.poison_needle': '독 바늘',
  'magic.ignition': '마법 발화',
  'magic.freezing_ray': '냉동 광선',
  'magic.dancing_sword': '춤추는 검',
  'magic.pulse_ray': '맥동 광선',
  'magic.lightning_strike': '직격 뇌전',
  'magic.doom': '필멸 주문',
  // 공격 — 전체
  'magic.air_storm': '공기 폭풍',
  'magic.heat_wave': '열선 파동',
  'magic.ultrasound': '초음파',
  'magic.toxic_gas': '유독 가스',
  'magic.deep_freeze': '초냉기',
  'magic.flame_field': '화염 지대',
  'magic.blizzard': '브리자드',
  'magic.energy_curtain': '에너지 장막',
  'magic.earthquake': '인공 지진',
  'magic.dimension_shift': '차원 이탈',
  // 변화
  'magic.magic_torch': '마법의 횃불',
  'magic.beholder_eye': '주시자의 눈',
  'magic.levitation': '공중 부상',
  'magic.water_walk': '물 위를 걸음',
  'magic.swamp_walk': '늪 위를 걸음',
  'magic.ethereal_move': '기화 이동',
  'magic.terraform': '지형 변화',
  'magic.teleport': '공간 이동',
  'magic.create_food': '식량 제조',
  'magic.great_terraform': '대지형 변화',
  // 치료
  'magic.heal_one': '한 명 치료',
  'magic.antidote_one': '한 명 독 제거',
  'magic.awaken_one': '한 명 의식 돌림',
  'magic.revive_one': '한 명 부활',
  'magic.full_cure_one': '한 명 복합 치료',
  'magic.heal_all': '모두 치료',
  'magic.antidote_all': '모두 독 제거',
  'magic.awaken_all': '모두 의식 돌림',
  'magic.revive_all': '모두 부활',
  'magic.full_cure_all': '모두 복합 치료',
  // 특수
  'magic.disable_skill_one': '한 명 기술 무력화',
  'magic.disable_defence_one': '한 명 방어 무력화',
  'magic.weaken_one': '한 명 능력 저하',
  'magic.silence_one': '한 명 마법 불능',
  'magic.demote_one': '한 명 탈 초인화',
  'magic.disable_skill_all': '모두 기술 무력화',
  'magic.disable_defence_all': '모두 방어 무력화',
  'magic.weaken_all': '모두 능력 저하',
  'magic.silence_all': '모두 마법 불능',
  'magic.demote_all': '모두 탈 초인화',
  'magic.poison': '독',
  // 소환
  'magic.summon_fire': '불의 정령 소환',
  'magic.summon_water': '물의 정령 소환',
  'magic.summon_air': '공기의 정령 소환',
  'magic.summon_earth': '땅의 정령 소환',
  'magic.raise_dead': '죽은 자의 소생',
  'magic.summon_other_dimension': '다른 차원 생물 소환',
  'magic.summon_giant': '거인을 부름',
  'magic.summon_golem': '고렘을 부름',
  'magic.summon_dragon': '용을 부름',
  'magic.summon_lycanthrope': '라이칸스로프 소환',
  // 초자연력
  'esp.clairvoyance': '투시',
  'esp.prophecy': '예언',
  'esp.mind_reading': '독심',
  'esp.far_sight': '천리안',
  'esp.telekinesis': '염력',
  'esp.hydrogen_fusion': '수소 핵융합',
  'esp.fear': '공포 생성',
  'esp.illusion': '환상 생성',
  'esp.metabolism': '신진 대사 조절',
  'esp.astral_projection': '유체 이탈',
};

String spellName(String key) => spellNames[key] ?? key;

/// 키의 이름 — 사람이 아닌 모든 키를 한 문으로 (물건 · 마법 · 계급 · 기술치).
String nameOf(String key) =>
    itemNames[key] ??
    spellNames[key] ??
    classNames[key] ??
    skillNames[key] ??
    (key.startsWith('summon.')
        ? summonNames[key.substring('summon.'.length)] ?? key
        : key);

/// `nameOf` + 조사.
String nameWith(String key, String pair) => josa(nameOf(key), pair);
