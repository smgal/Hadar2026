import 'package:hd_battle/hd_battle.dart' as hb;

import '../../domain/item/item_data.dart';
import '../../domain/item/item_id.dart';
import '../../domain/item/item_type.dart';

/// RPG 아이템 → 전투 무기 표 (B3-03).
///
/// **두 세계가 무기를 나눠 갖는다** — RPG 는 `attaPow`(얼마나 센지), 전투는
/// `weaponKey`(어떻게 닿는지). 규격 v2 가 그렇게 정했고, 그래야 전투를
/// 조정할 때 아이템 데이터를 끌고 오지 않아도 된다.
///
/// 대응은 **이름으로** 한다. 원작 무기 10종의 이름이 그대로 남아 있고
/// (`item_data.dart`), 전투 무기 표도 같은 것들을 담고 있어서 이름이 가장
/// 곧은 다리다. 이름이 바뀌면 `HDItemType` 으로 떨어진다.
const Map<String, String> _byName = {
  '맨손': 'unarmed',
  '단도': 'dagger',
  '곤봉': 'club',
  '철퇴': 'mace',
  '지팡이': 'staff',
  '장검': 'long_sword',
  '화염검': 'flame_sword',
  '미늘창': 'halberd',
  '도끼창': 'poleaxe',
  '삼지창': 'trident',
  '기병창': 'lance',
  '대검': 'great_sword',
};

/// 이름이 표에 없을 때 종류에서 유도한다.
///
/// `HDItemType` 의 다섯 갈래가 공격 방식과 거의 그대로 맞는다 —
/// `wield` 베기 · `chop` 찍기(베기) · `stab` 찌르기 · `hit` 타격.
/// 이름 없는 새 무기가 들어와도 무언가는 들 수 있게 하는 안전망이다.
String _byType(HDItemType type) => switch (type) {
  HDItemType.wield => 'long_sword',
  HDItemType.chop => 'poleaxe',
  HDItemType.stab => 'dagger',
  HDItemType.hit => 'mace',
  // 쏘는 무기는 전투 표에 아직 없다. 사거리가 가장 긴 것으로 둔다 —
  // 활이 들어오면 표에 자리를 만들어야 한다.
  HDItemType.shoot => 'lance',
  _ => 'unarmed',
};

/// 손에 든 아이템의 전투 무기 키. 없으면 맨손.
String weaponKeyOf(HDItemId? id) {
  if (id == null) return 'unarmed';
  final item = itemById(id);
  if (item == null) return _byType(id.kind);
  return _byName[item.name] ?? _byType(id.kind);
}

/// 그 아이템의 표시 이름. 없으면 맨손.
String weaponNameOf(HDItemId? id) =>
    id == null ? '맨손' : (itemById(id)?.name ?? '맨손');

/// 전투 무기 표에 그 키가 실제로 있는지. 테스트가 대응표를 지킨다.
bool isKnownWeaponKey(String key) => hb.weaponTable.containsKey(key);
