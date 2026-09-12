import 'package:hd_world/hd_world.dart';

/// 새 게임의 일행.
///
/// ## 직업 번호가 원작 것으로 바뀌었다
///
/// 이전 모델은 `characterClass` 를 0 = 에스퍼 · 1 = 싸이보그 · 2 = 초능력자로
/// 두었는데, **출하 스크립트는 이미 원작의 17직업 번호를 쓴다** — `class` 에
/// 5(전사) · 8(에스퍼) · 9(검사)를 쓰고 5와 비교한다(부록 Z-7). 그래서
/// 이전 모델에서는 cm2 가 직업을 정하면 화면에 "알 수 없음" 이 나왔다.
///
/// 두 사람 다 **에스퍼**(8)다. 초능력자는 원작 `CLASS` 에 없는 이름이고,
/// 유리는 초자연력에 치우친 에스퍼로 본다(BP-44 §7.2).
///
/// 수치는 이전 모델의 값을 그대로 옮겼다. `baseAc` 는 `baseDefence` 가 되고
/// 죽은 필드였던 `powOfArmor` 는 옮기지 않는다(부록 H-1 정정판).
const List<MemberTemplate> startingPartyTemplates = [
  MemberTemplate(
    ref: 'seumgal',
    nameKey: 'member.seumgal',
    clazz: CharacterClass.esper,
    stats: BaseStats(
      strength: 18,
      mentality: 20,
      concentration: 20,
      endurance: 15,
      agility: 12,
    ),
    levels: Levels(physical: 1, magic: 20, esp: 20),
    accuracy: Accuracy(physical: 15, magic: 15, esp: 15),
    maxHitPoints: 150,
    maxSpellPoints: 100,
    maxEspPoints: 100,
    baseDefence: 5,
    equipment: {
      EquipSlot.rightHand: 'weapon.knife',
      EquipSlot.body: 'bodyArmour.leather',
    },
  ),
  MemberTemplate(
    ref: 'yuri',
    nameKey: 'member.yuri',
    clazz: CharacterClass.esper,
    gender: 2,
    stats: BaseStats(strength: 10, endurance: 10, agility: 15),
    levels: Levels(physical: 1, esp: 1),
    accuracy: Accuracy(physical: 10),
    maxHitPoints: 100,
    maxSpellPoints: 100,
    maxEspPoints: 80,
    baseDefence: 3,
    equipment: {
      EquipSlot.rightHand: 'weapon.knife',
      EquipSlot.body: 'bodyArmour.leather',
    },
  ),
];

/// 새 게임의 가방.
///
/// 바를 것과 마실 것을 한 번씩은 써 볼 수 있는 양이다(B6-05). 세이브에서
/// 올라온 파티는 세이브의 가방을 따르므로 여기는 새 게임에만 닿는다.
const Map<String, int> startingPack = {
  'consumable.potion': 3,
  'consumable.antidote': 1,
  'consumable.sp_tonic': 1,
  'consumable.poison_vial': 2,
  'consumable.paralysis_vial': 1,
  'consumable.fire_vial': 1,
};

/// 파티 정원. 원작과 같은 여섯이다.
const int partyCapacity = 6;

/// 새 게임의 세계를 만든다.
///
/// **빈 자리까지 여섯을 만든다.** 출하 스크립트가 여섯째 자리를 미리 손보기
/// 때문이다 — `menace.cm2:45` 의 `Player::ChangeAttribute(6, "class", 8)` 은
/// 나중에 합류할 사람을 위한 것이고, 자리를 접으면 그 사람이 옮겨진다.
World buildStartingWorld() => World(
  members: [
    for (final t in startingPartyTemplates) t.build(),
    for (var i = startingPartyTemplates.length; i < partyCapacity; i++)
      emptySeat(i),
  ],
  pack: Pack(
    capacity: 24,
    counts: {
      for (final e in startingPack.entries) ItemRef(e.key): e.value,
    },
  ),
);

/// 빈 자리 하나.
///
/// 이름이 비어 있는 것이 「없음」의 표시다 — 원작의 `isValid()` 가 그것이고
/// `Member.isPresent` 가 같은 것을 본다.
Member emptySeat(int index) => Member(ref: MemberRef('seat$index'), name: '');
