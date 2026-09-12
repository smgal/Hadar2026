/// 아이템 이름표.
///
/// 키는 `ItemDef.nameKey` 다. 무기 31종은 원작 `WEAPON_LIST` 이름 그대로고,
/// 방패·갑옷·투구·신발·장식은 원작 이름표 그대로다. 새로 만든 것은
/// 부적 아홉 개와 횃불뿐이다.
library;

const Map<String, String> itemNames = {
  // 맨손 — 갈래마다 하나씩. 벗을 수 없다.
  'item.weapon.fist_cut': '맨손',
  'item.weapon.fist_chop': '맨손',
  'item.weapon.fist_thrust': '맨손',
  'item.weapon.fist_strike': '맨손',
  'item.weapon.fist_shoot': '맨손',

  // 베는 무기 7
  'item.weapon.dagger': '단검',
  'item.weapon.gladius': '그라디우스',
  'item.weapon.sabre': '샤벨',
  'item.weapon.new_moon_blade': '신월도',
  'item.weapon.full_moon_blade': '인월도',
  'item.weapon.long_sword': '장검',
  'item.weapon.flamberge': '프렘버그',

  // 찍는 무기 7
  'item.weapon.small_hammer': '소형 해머',
  'item.weapon.hand_axe': '소형 도끼',
  'item.weapon.flail': '프레일',
  'item.weapon.war_hammer': '전투용 망치',
  'item.weapon.mace': '철퇴',
  'item.weapon.battle_axe': '양날 전투 도끼',
  'item.weapon.halberd': '핼버드',

  // 찌르는 무기 7
  'item.weapon.knife': '단도',
  'item.weapon.cavalry_lance': '기병창',
  'item.weapon.short_spear': '단창',
  'item.weapon.rapier': '레이피어',
  'item.weapon.trident': '삼지창',
  'item.weapon.lancer': '랜서',
  'item.weapon.poleaxe': '도끼창',

  // 타격 무기 3
  'item.weapon.knuckle': '너클',
  'item.weapon.long_staff': '장대',
  'item.weapon.club': '곤봉',

  // 쏘는 무기 7
  'item.weapon.blowpipe': '블로우 파이프',
  'item.weapon.shuriken': '표창',
  'item.weapon.sling': '투석기',
  'item.weapon.javelin': '투창',
  'item.weapon.bow': '활',
  'item.weapon.crossbow': '석궁',
  'item.weapon.arbalest': '아르발레스트',

  // 방패
  'item.shield.none': '없음',
  'item.shield.leather': '가죽 방패',
  'item.shield.small_steel': '소형 강철 방패',
  'item.shield.large_steel': '대형 강철 방패',
  'item.shield.chromatic': '크로매틱 방패',
  'item.shield.platinum': '플래티움 방패',

  // 갑옷
  'item.bodyArmour.plain_clothes': '평상복',
  'item.bodyArmour.leather': '가죽 갑옷',
  'item.bodyArmour.bronze': '청동 갑옷',
  'item.bodyArmour.steel': '강철 갑옷',
  'item.bodyArmour.silver': '은제 갑옷',
  'item.bodyArmour.gold': '금제 갑옷',

  // 투구
  'item.helmet.none': '없음',
  'item.helmet.hood': '두건',
  'item.helmet.hunting_cap': '사냥 모자',
  'item.helmet.half_mask': '반쪽 가면',
  'item.helmet.fedora': '중절모',
  'item.helmet.leather_cap': '가죽캡',
  'item.helmet.leather_helm': '가죽 투구',
  'item.helmet.dandy_hat': '멋쟁이 모자',
  'item.helmet.bronze_helm': '청동 투구',
  'item.helmet.plate_helm': '판금 투구',
  'item.helmet.gold_crown': '황금 왕관',

  // 신발 — 원작이 이름을 안 붙인 다섯은 그대로 둔다
  'item.boots.none': '없음',
  'item.boots.cloth_shoes': '헝겊 신발',
  'item.boots.leather_shoes': '가죽 신발',
  'item.boots.mesh_stockings': '망사 스타킹',
  'item.boots.winged_shoes': '날개 신발',
  'item.boots.scale_boots': '미늘 부츠',
  'item.boots.legs6': '다리6',
  'item.boots.legs7': '다리7',
  'item.boots.legs8': '다리8',
  'item.boots.legs9': '다리9',
  'item.boots.legsA': '다리A',

  // 공통 부적 — 원작 장식 11종
  'item.commonAmulet.none': '없음',
  'item.commonAmulet.dandy_belt': '멋쟁이 혁띠',
  'item.commonAmulet.plain_ring': '민무늬 반지',
  'item.commonAmulet.silver_ring': '은 가락지',
  'item.commonAmulet.ruby_necklace': '루비 목걸이',
  'item.commonAmulet.fake_medal': '가짜 훈장',
  'item.commonAmulet.trinket6': '장식6',
  'item.commonAmulet.trinket7': '장식7',
  'item.commonAmulet.trinket8': '장식8',
  'item.commonAmulet.trinket9': '장식9',
  'item.commonAmulet.trinketA': '장식A',

  // 공통 부적 — 새로 만든 것. 숫자를 올리거나 상태를 막는다
  'item.commonAmulet.ward': '수호의 부적',
  'item.commonAmulet.hawk': '매의 부적',
  'item.commonAmulet.wind': '바람의 부적',
  'item.commonAmulet.antidote': '해독의 부적',
  'item.commonAmulet.waking': '각성의 부적',
  'item.commonAmulet.life': '생명의 부적',

  // 지형을 여는 셋. 파티 전체에 듣는다
  'item.commonAmulet.water': '물의 부적',
  'item.commonAmulet.marsh': '늪의 부적',
  'item.commonAmulet.levitation': '부양의 부적',

  // 소비품 — 원작 전투 메뉴에 물건 항목이 없었으므로 이 열은 우리 것이다
  'item.consumable.potion': '치료약',
  'item.consumable.antidote': '해독제',
  'item.consumable.elixir': '만능약',
  'item.consumable.revive_charm': '소생의 부적',
  'item.consumable.sp_tonic': '기력의 약',
  'item.consumable.poison_vial': '독병',
  'item.consumable.paralysis_vial': '마비병',
  'item.consumable.fire_vial': '화염병',
  'item.consumable.fire_crystal': '화염 결정',
  'item.consumable.storm_crystal': '폭풍 결정',

  // 손에 드는 불
  'item.light.torch': '횃불',

  // 직업 부적 — 숫자가 아니라 그 직업의 규칙을 바꾼다
  'item.classAmulet.oath_crest': '서약의 문장',
  'item.classAmulet.quiver': '화살통',
  'item.classAmulet.prayer_beads': '염주',
  'item.classAmulet.vow_seal': '맹세의 인장',
  'item.classAmulet.venom_pouch': '독주머니',
  'item.classAmulet.casting_seal': '시전의 인장',
  'item.classAmulet.attunement_ring': '감응의 고리',
};

/// 실험용 파티의 이름. 원작 Unity 포트가 쓰던 이름을 가져왔다.
const Map<String, String> memberNames = {
  'member.knight': '아트리아',
  'member.paladin': '안카라',
  'member.swordman': '머큐리',
  'member.magician': '수하일',
  'member.hunter': '유리',
};

String itemName(String nameKey) => itemNames[nameKey] ?? nameKey;
String memberName(String nameKey) => memberNames[nameKey] ?? nameKey;
