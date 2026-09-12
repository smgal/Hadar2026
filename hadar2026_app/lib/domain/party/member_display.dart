import 'package:hd_world/hd_world.dart';
import 'package:hd_world_text/hd_world_text.dart' as tx;

import '../text/noun.dart';

/// 사람을 화면에 쓰기 위한 것.
///
/// ## 왜 확장인가
///
/// `Member` 는 순수 Dart 이고 한국어를 들지 않는다. 조사·직업 이름·장비 이름은
/// 전부 표시이므로 모델에 넣을 수 없고, 그렇다고 감싸는 클래스를 만들면 신원이
/// 둘이 된다 — 이전 모델이 그랬고 `HDPlayer` 와 세이브가 갈렸다.
///
/// 확장이면 신원은 하나이고 표시만 앱 쪽에 붙는다.
extension MemberDisplay on Member {
  /// 조사를 붙일 수 있는 이름.
  HDNoun get noun => HDNoun(displayName);

  /// 사람에게 보일 이름. 템플릿의 키가 남아 있으면 이름표에서 찾는다.
  String get displayName =>
      name.startsWith('member.') ? tx.memberName(name) : name;

  /// 이전 모델의 `isValid()` — 이름이 있으면 그 자리에 사람이 있다.
  bool isValid() => isPresent;

  /// 이전 모델의 `isAvailable()`·`isConscious()`.
  bool isAvailable() => isConscious;

  String getClassName() => tx.className(clazz);

  String getGenderName() => switch (gender) {
    1 => '남성',
    2 => '여성',
    _ => '불명',
  };

  /// 그 자리에 든 것의 이름. 비어 있으면 [empty].
  String slotName(EquipSlot slot, {String empty = '없음'}) {
    final ref = at(slot);
    if (ref == null) return empty;
    final def = ItemCatalog.builtIn[ref];
    // 카탈로그에 없는 참조는 **조용히 맨손이 되지 않는다** — 세이브가 이 빌드에
    // 없는 물건을 들고 올라온 것이고, 그것이 보여야 한다(부록 F-1 과 같은 종류).
    if (def == null) return '불확실한 물건';
    return tx.itemName(def.nameKey);
  }

  String getWeaponName() =>
      slotName(EquipSlot.rightHand, empty: tx.itemName('item.weapon.fist_cut'));
  String getShieldName() => slotName(EquipSlot.leftHand);
  String getArmorName() =>
      slotName(EquipSlot.body, empty: tx.itemName('item.bodyArmour.plain_clothes'));

  /// 손 구성이 만든 무기 종류의 이름.
  String get weaponKindName => tx.weaponKindName(
    resolveStats(member: this, catalog: ItemCatalog.builtIn).weaponKind,
  );

  /// 상태 한 글자짜리 이름.
  String get conditionName => switch (condition) {
    MemberCondition.dead => '사망',
    MemberCondition.unconscious => '기절',
    MemberCondition.poisoned => '중독',
    MemberCondition.well => '정상',
  };

  /// 최종 수치 한 벌. 화면이 매번 다시 계산하지 않게 한 번에 준다.
  ResolvedStats get resolved =>
      resolveStats(member: this, catalog: ItemCatalog.builtIn);

  int get maxHitPoints => resolved[StatKey.maxHitPoints];
  int get maxSpellPoints => resolved[StatKey.maxSpellPoints];
  int get maxEspPoints => resolved[StatKey.maxEspPoints];
  int get defence => resolved[StatKey.defence];

  /// 피해를 입는다 — 이전 모델의 `damaged()`.
  ///
  /// 체력이 0 아래로 가면 쓰러진다. 죽는 판정은 전투가 갖는다(2단 붕괴).
  void damaged(int damage) {
    hitPoints -= damage;
    if (hitPoints <= 0) {
      hitPoints = 0;
      if (unconscious == 0) unconscious = 1;
    }
  }
}
