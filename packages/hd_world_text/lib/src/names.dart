/// 모델이 키를 들고, 이 파일이 말로 바꾼다.
///
/// `hd_battle_text` 와 같은 자리다 — 한국어와 emoji 는 모델에 들어가지
/// 않고, 콘솔·웹·Flutter 가 **같은 이 표**를 본다. 한쪽에만 쓰면
/// 화면마다 이름이 갈린다.
library;

import 'package:hd_world/hd_world.dart';

/// 부위 이름. 저장 순서가 아니라 사람이 읽는 순서는
/// [EquipSlot.displayOrder] 가 정한다.
const Map<EquipSlot, String> slotNames = {
  EquipSlot.rightHand: '오른손',
  EquipSlot.leftHand: '왼손',
  EquipSlot.head: '머리',
  EquipSlot.body: '몸통',
  EquipSlot.legs: '다리',
  EquipSlot.commonAmulet: '공통 부적',
  EquipSlot.classAmulet1: '직업 부적 1',
  EquipSlot.classAmulet2: '직업 부적 2',
};

/// 직업 17종. 원작 `CLASS` 이름표 그대로다.
const Map<CharacterClass, String> classNames = {
  CharacterClass.unknown: '불확실함',
  CharacterClass.wanderer: '떠돌이',
  CharacterClass.knight: '기사',
  CharacterClass.hunter: '사냥꾼',
  CharacterClass.monk: '전투승',
  CharacterClass.paladin: '전사',
  CharacterClass.assassin: '암살자',
  CharacterClass.magician: '마법사',
  CharacterClass.esper: '에스퍼',
  CharacterClass.swordman: '검사',
  CharacterClass.mage: '메이지',
  CharacterClass.conjurer: '컨저러',
  CharacterClass.sorcerer: '주술사',
  CharacterClass.wizard: '위저드',
  CharacterClass.necromancer: '강령술사',
  CharacterClass.archimage: '대마법사',
  CharacterClass.timewalker: '타임워커',
};

const Map<ClassType, String> classTypeNames = {
  ClassType.physical: '물리',
  ClassType.caster: '마법',
  ClassType.hybridCure: '혼합 · 치료',
  ClassType.hybridSpecial: '혼합 · 특수',
  ClassType.hybridEsp: '혼합 · 초능력',
};

/// 기술 12종. 원작 `SKILL_TYPE` 이름표.
const Map<SkillType, String> skillNames = {
  SkillType.cutting: '베는 무기',
  SkillType.chopping: '찍는 무기',
  SkillType.thrusting: '찌르는 무기',
  SkillType.striking: '타격 무기',
  SkillType.shooting: '쏘는 무기',
  SkillType.shieldUse: '방패 사용',
  SkillType.attackMagic: '공격 마법',
  SkillType.changeMagic: '변화 마법',
  SkillType.cureMagic: '치료 마법',
  SkillType.summonMagic: '소환 마법',
  SkillType.specialMagic: '특수 마법',
  SkillType.esp: '초 자연력',
};

/// 손 구성이 만드는 무기 종류. 이름은 표준어와 원작 이름표에서 가져왔다.
const Map<WeaponKind, String> weaponKindNames = {
  WeaponKind.unarmed: '맨손',
  WeaponKind.oneHanded: '한손',
  WeaponKind.swordAndShield: '검과 방패',
  WeaponKind.spearAndShield: '창과 방패',
  WeaponKind.dualWield: '쌍수',
  WeaponKind.torchbearer: '횃불잡이',
  WeaponKind.greatSword: '대검',
  WeaponKind.warHammer: '전투 망치',
  WeaponKind.longStaff: '장봉',
  WeaponKind.polearm: '장병기',
  WeaponKind.lance: '기병창',
  WeaponKind.bow: '활',
  WeaponKind.crossbow: '석궁',
  WeaponKind.arbalest: '아르발레스트',
  WeaponKind.thrown: '투척',
};

/// 물건의 갈래 15종. `ITEM_TYPE` 0~12 는 원작 것이고 13·14 는 새것이다.
///
/// [skillNames] 와 앞의 다섯이 겹쳐 보이지만 같은 것이 아니다 —
/// 저쪽은 **사람이 가진 숙련**이고 이쪽은 **물건이 무엇인지**다.
/// 아이콘을 고르는 것은 이쪽이다.
const Map<ItemKind, String> itemKindNames = {
  ItemKind.slashWeapon: '베는 무기',
  ItemKind.chopWeapon: '찍는 무기',
  ItemKind.pierceWeapon: '찌르는 무기',
  ItemKind.bluntWeapon: '타격 무기',
  ItemKind.missileWeapon: '쏘는 무기',
  ItemKind.summonSingle: '소환수의 공격',
  ItemKind.summonMulti: '소환수의 다중 공격',
  ItemKind.shield: '방패',
  ItemKind.bodyArmour: '갑옷',
  ItemKind.helmet: '투구',
  ItemKind.boots: '신발',
  ItemKind.commonAmulet: '공통 부적',
  ItemKind.consumable: '소비품',
  ItemKind.light: '불',
  ItemKind.classAmulet: '직업 부적',
};

/// 무기의 생김새 13종.
///
/// 갈래가 **어떻게 닿는지**를 말하고 이것이 **무엇인지**를 말한다.
/// 둘이 다 있어야 무기 종류를 이름 지을 수 있다 — 양손으로 베는 *날*은
/// 대검이고 양손으로 치는 *철퇴*는 전투 망치다.
const Map<WeaponShape, String> weaponShapeNames = {
  WeaponShape.blade: '날',
  WeaponShape.axe: '도끼',
  WeaponShape.mace: '철퇴',
  WeaponShape.spear: '창',
  WeaponShape.polearm: '장병기',
  WeaponShape.lance: '기병창',
  WeaponShape.staff: '봉',
  WeaponShape.knuckle: '주먹',
  WeaponShape.bow: '활',
  WeaponShape.crossbow: '석궁',
  WeaponShape.arbalest: '아르발레스트',
  WeaponShape.thrown: '투척',
  WeaponShape.blowpipe: '불대롱',
};

/// 상시 지시 일곱.
const Map<FightingStyle, String> styleNames = {
  FightingStyle.bulwark: '방벽',
  FightingStyle.assault: '돌격',
  FightingStyle.skirmish: '유격',
  FightingStyle.volley: '사격',
  FightingStyle.firepower: '화력',
  FightingStyle.disrupt: '교란',
  FightingStyle.mend: '치유',
};

/// 그 지시가 무엇을 하는지 한 줄.
const Map<FightingStyle, String> styleHints = {
  FightingStyle.bulwark: '앞에 서서 맞는다',
  FightingStyle.assault: '붙어서 가까운 것을 친다',
  FightingStyle.skirmish: '2열에서 치고 물러난다',
  FightingStyle.volley: '3열에서 쏜다',
  FightingStyle.firepower: '공격 마법을 먼저 쓴다',
  FightingStyle.disrupt: '바르고, 깎고, 무력화한다',
  FightingStyle.mend: '쓰러지는 사람을 먼저 본다',
};

const Map<StatKey, String> statNames = {
  StatKey.maxHitPoints: '최대 체력',
  StatKey.maxSpellPoints: '최대 마법 지수',
  StatKey.maxEspPoints: '최대 초능력 지수',
  StatKey.defence: '방어',
  StatKey.accuracyPhysical: '물리 명중',
  StatKey.accuracyMagic: '마법 명중',
  StatKey.accuracyEsp: '초능력 명중',
  StatKey.evasion: '회피',
  StatKey.initiative: '선제',
  StatKey.strength: '힘',
  StatKey.mentality: '지력',
  StatKey.concentration: '집중',
  StatKey.endurance: '체력',
  StatKey.resistance: '저항',
  StatKey.agility: '민첩',
  StatKey.luck: '행운',
  StatKey.shieldBlock: '방패 차단',
  StatKey.coatingSlots: '도포 칸',
  StatKey.spellCostRelief: '마법 소모 경감',
  StatKey.espCostRelief: '초능력 소모 경감',
};

const Map<Capability, String> capabilityNames = {
  Capability.walkOnWater: '물위를 걸음',
  Capability.walkOnSwamp: '늪위를 걸음',
  Capability.levitate: '공중 부양',
  Capability.carryLight: '불을 든다',
  Capability.senseWeakness: '약점 간파',
};

const Map<Ailment, String> ailmentNames = {
  Ailment.poison: '독',
  Ailment.paralysis: '마비',
  Ailment.mind: '정신',
  Ailment.stun: '기절',
  Ailment.deathTouch: '즉사',
};

/// 거절 이유를 사람 말로. **자리가 틀린 것과 직업이 틀린 것은 다른
/// 문장이어야 한다** — 그것이 이유를 열거로 둔 까닭이다.
const Map<RefusalReason, String> refusalMessages = {
  RefusalReason.noSuchMember: '그런 사람이 없다.',
  RefusalReason.noSuchItem: '그런 물건이 없다.',
  RefusalReason.notCarried: '가방에 없다.',
  RefusalReason.wrongSlot: '그 부위에 채우는 것이 아니다.',
  RefusalReason.wrongClass: '이 사람의 직업이 찰 수 있는 것이 아니다.',
  RefusalReason.offHandLocked: '양손 무기를 들고 있어 왼손이 비지 않는다.',
  RefusalReason.mismatchedPair: '같은 갈래의 무기여야 짝이 된다.',
  RefusalReason.noMainHandToPairWith: '오른손에 짝이 될 무기가 없다.',
  RefusalReason.twoHandedInOffHand: '양손 무기는 왼손에 들 수 없다.',
  RefusalReason.slotEmpty: '이미 비어 있다.',
  RefusalReason.cannotRemoveBareHands: '맨손은 벗을 수 없다.',
  RefusalReason.packFull: '가방이 가득 찼다.',
  RefusalReason.duplicateAmulet: '같은 부적을 두 칸에 찰 수 없다.',
};

/// 원작이 문자열로 싣고 있던 보정 세 개.
const Map<String, String> annexNames = {
  'annex.att1_ac-1_str1': '공격+1 방어-1 힘+1',
  'annex.int-2': '지력-2',
  'annex.str100': '힘+100',
};

String itemKindName(ItemKind k) => itemKindNames[k] ?? k.name;
String weaponShapeName(WeaponShape s) => weaponShapeNames[s] ?? s.name;
String slotName(EquipSlot slot) => slotNames[slot] ?? slot.name;
String className(CharacterClass c) => classNames[c] ?? c.name;
String weaponKindName(WeaponKind k) => weaponKindNames[k] ?? k.name;
String styleName(FightingStyle s) => styleNames[s] ?? s.name;
String statName(StatKey s) => statNames[s] ?? s.name;
String capabilityName(Capability c) => capabilityNames[c] ?? c.name;
String refusalMessage(RefusalReason r) => refusalMessages[r] ?? r.name;
