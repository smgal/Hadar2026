/// 전투 중 쓰는 물품·크리스탈, 소환되는 존재, 보조 일원의 무기 이름표.
///
/// 표시용이므로 view 가 갖는다 — model 은 전부 키로만 다룬다. 물품과
/// 크리스탈은 기획서 10.5 · 9.8, 소환되는 존재와 그 무기는 9.7 의 표다.
library;

import 'package:lore_battle/lore_battle.dart';

/// 약초·약물 1~5번과 크리스탈 1~7번.
const Map<String, String> itemNames = {
  ItemKey.hpPotion: '체력 회복약',
  ItemKey.mpPotion: '마법 회복약',
  ItemKey.antidoteHerb: '해독의 약초',
  ItemKey.awakeningHerb: '의식의 약초',
  ItemKey.revivalHerb: '부활의 약초',
  ItemKey.flameCrystal: '화염의 크리스탈',
  ItemKey.frostCrystal: '한파의 크리스탈',
  ItemKey.darkCrystal: '다크 크리스탈',
  ItemKey.ebonyCrystal: '에보니 크리스탈',
  ItemKey.spiritCrystal: '영혼의 크리스탈',
  ItemKey.summonCrystal: '소환의 크리스탈',
  ItemKey.energyCrystal: '에너지 크리스탈',
};

String itemName(String key) => itemNames[key] ?? key;

/// 물품 앞에 붙는 글자. 무엇을 마시고 무엇을 던지는지 한눈에.
String itemGlyph(String key) {
  final item = battleItems[key];
  if (item == null) return '';
  if (item.kind == BattleItemKind.medicine) {
    return key == ItemKey.mpPotion ? '💙' : '💚';
  }
  return switch (item.target) {
    ItemTarget.enemy => '🎯',
    ItemTarget.allEnemies => '💥',
    _ => '💎',
  };
}

/// 소환 마법과 소환의 크리스탈이 불러내는 존재 (9.7 · 9.8).
/// 키는 `CombatantSnapshot.nameKey` 의 `summon.` 뒤쪽이다.
const Map<String, String> summonNames = {
  // 1 불의 정령 소환
  'fire_spirit': '불의 정령',
  'salamander': '사라만다',
  'azer': '아저',
  'ifrit': '이프리트',
  // 2 물의 정령 소환
  'nymph': '님프',
  'dryads': '드리어드스',
  'nereids': '네레이드스',
  'naiads': '나이어드스',
  'napaeae': '나파이어스',
  'oreads': '오레이어드스',
  'alseids': '알세이드스',
  'marid': '마리드',
  'kelpie': '켈피',
  // 3 공기의 정령 소환
  'air_spirit': '공기의 정령',
  'sylph': '실프',
  'sylphid': '실피드',
  'djinni': '디지니',
  'invisible_stalker': '인비저블 스토커',
  // 4 땅의 정령 소환
  'earth_spirit': '땅의 정령',
  'gnome': '놈',
  'dao': '다오',
  // 5 죽은 자의 소생
  'ancient_knight': '에인션트 나이트',
  'ancient_mage': '에인션트 메이지',
  // 6 다른 차원 생물 소환
  'bandersnatch': '밴더스내치',
  'carrion_crawler': '캐리온 크롤러',
  'centaur': '켄타우루스',
  'demogorgon': '데모고르곤',
  'dullahan': '듈라한',
  'ettin': '에틴',
  'hellhound': '헬하운드',
  'minotaur': '미노타우루스',
  // 7 거인을 부름
  'cloud_giant': '클라우드 자이언트',
  'fire_giant': '파이어 자이언트',
  'frost_giant': '프로스트 자이언트',
  'hill_giant': '힐 자이언트',
  'stone_giant': '스톤 자이언트',
  'storm_giant': '스토엄 자이언트',
  // 8 고렘을 부름
  'clay_golem': '글레이 고렘',
  'flesh_golem': '프레쉬 고렘',
  'iron_golem': '아이언 고렘',
  'stone_golem': '스톤 고렘',
  // 9 용을 부름
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
  // 10 라이칸스로프 소환
  'werewolf': '늑대 인간',
  'dragon_newt': '드래곤 뉴트',
  // 소환의 크리스탈
  'crystal_dragon': '크리스탈 드래곤',
  'crystal_golem': '크리스탈 고렘',
  'archangel': '대천사장',
};

/// 보조 일원이 쓰는 무기의 이름 — `CombatantSnapshot.weaponNameKey`.
const Map<String, String> weaponNameKeys = {
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
  // 설득되어 넘어온 적. 원작은 무기 이름을 따로 주지 않는다.
  'natural.attack': '무기',
  'weapon.long_sword': '장검',
  'weapon.spear': '창',
  'weapon.lance': '기병창',
  'weapon.club': '곤봉',
  'weapon.hand_axe': '소형 도끼',
  'weapon.flame_sword': '화염검',
  'weapon.gladius': '그라디우스',
  'breath.acid': '산성 가스',
  'breath.lightning': '전광',
  'breath.poison': '독가스',
  'breath.fire': '불꽃',
  'breath.chlorine': '염소 가스',
  'breath.cold': '한기',
  'breath.frost': '냉동 가스',
};
