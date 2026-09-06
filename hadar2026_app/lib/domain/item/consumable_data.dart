import 'item.dart';
import 'item_id.dart';
import 'item_type.dart';

/// 소비 아이템 카탈로그 (B6-05).
///
/// **손으로 쓴 파일이다.** `item_data.dart` 는 `tools/convert_item.py` 가
/// 원작 Unity 포트에서 만드는 생성 파일이고, 소비품은 원작에 없다 — 원작
/// 전투 메뉴에는 물건 항목이 없었다(부록 R). 그래서 생성 파일을 건드리지
/// 않고 따로 둔다. 두 표를 합쳐 찾는 것은 `item_lookup.dart` 의 `lookupItem`.
///
/// `battleKey` 가 전투(`packages/hd_battle` 의 `battleItems`)와 이어지는
/// 이름이다. 전투는 물건을 키로만 알고, RPG 가 가방을 훑어 `{키: 개수}` 를
/// 넘긴 뒤 `consumedItems` 만큼 뺀다.
class HDConsumable {
  const HDConsumable({
    required this.index,
    required this.name,
    required this.battleKey,
  });

  final int index;
  final String name;

  /// `hd_battle` 의 `battleItems` 키.
  final String battleKey;

  HDItemId get id => HDItemId(HDItemType.consumable, index: index);

  HDItem get item => HDItem(
    id: id,
    name: name,
    param: const HDItemParam(attaPow: 0, ac: 0, type: HDItemType.consumable),
  );
}

/// 순서가 곧 `index` 다 — 세이브·cm2 에 들어가므로 **끼워 넣지 않는다**.
const List<HDConsumable> consumableTable = [
  HDConsumable(index: 0, name: '치료약', battleKey: 'potion'),
  HDConsumable(index: 1, name: '해독제', battleKey: 'antidote'),
  HDConsumable(index: 2, name: '만능약', battleKey: 'elixir'),
  HDConsumable(index: 3, name: '소생의 부적', battleKey: 'revive_charm'),
  HDConsumable(index: 4, name: '기력의 약', battleKey: 'sp_tonic'),
  HDConsumable(index: 5, name: '독병', battleKey: 'poison_vial'),
  HDConsumable(index: 6, name: '마비병', battleKey: 'paralysis_vial'),
  HDConsumable(index: 7, name: '화염병', battleKey: 'fire_vial'),
  HDConsumable(index: 8, name: '화염 결정', battleKey: 'fire_crystal'),
  HDConsumable(index: 9, name: '폭풍 결정', battleKey: 'storm_crystal'),
];

final Map<int, HDConsumable> _byIndex = {
  for (final c in consumableTable) c.index: c,
};
final Map<String, HDConsumable> _byBattleKey = {
  for (final c in consumableTable) c.battleKey: c,
};

/// 소비품 id → 항. 소비품이 아니거나 표에 없으면 null.
HDConsumable? consumableById(HDItemId id) =>
    id.kind == HDItemType.consumable ? _byIndex[id.index] : null;

/// 전투 키 → 항. 전투가 보고한 `consumedItems` 를 가방에서 뺄 때 쓴다.
HDConsumable? consumableByBattleKey(String key) => _byBattleKey[key];

/// 새 게임의 가방 (B6-05).
///
/// 바를 것과 마실 것을 **한 번씩은 써 볼 수 있는** 양이다. 세이브에서 올라온
/// 파티는 세이브의 가방을 따르므로 여기는 새 게임에만 닿는다. 원작 난이도를
/// 깨뜨리면 개수를 줄인다 — 숫자 하나다(9차 판정).
List<HDItemId> startingBackpack() => [
  for (var i = 0; i < 3; i++) consumableTable[0].id, // 치료약 ×3
  consumableTable[1].id, // 해독제
  consumableTable[4].id, // 기력의 약
  consumableTable[5].id, consumableTable[5].id, // 독병 ×2
  consumableTable[6].id, // 마비병
  consumableTable[7].id, // 화염병
];
