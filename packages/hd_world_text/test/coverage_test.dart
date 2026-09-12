import 'package:hd_world/hd_world.dart';
import 'package:hd_world_text/hd_world_text.dart';
import 'package:test/test.dart';

/// 이름표에 빠진 것이 없어야 한다.
///
/// 모델에 값을 더하고 이름을 잊으면 화면에 영어 열거 이름이 그대로 나온다.
/// 그것을 조용히 넘기지 않게 하는 것이 이 파일의 전부다.
void main() {
  test('열거 전부에 이름이 있다', () {
    for (final v in EquipSlot.values) {
      expect(slotNames[v], isNotNull, reason: v.name);
    }
    for (final v in CharacterClass.values) {
      expect(classNames[v], isNotNull, reason: v.name);
    }
    for (final v in ClassType.values) {
      expect(classTypeNames[v], isNotNull, reason: v.name);
    }
    for (final v in SkillType.values) {
      expect(skillNames[v], isNotNull, reason: v.name);
    }
    for (final v in WeaponKind.values) {
      expect(weaponKindNames[v], isNotNull, reason: v.name);
    }
    for (final v in FightingStyle.values) {
      expect(styleNames[v], isNotNull, reason: v.name);
      expect(styleHints[v], isNotNull, reason: v.name);
    }
    for (final v in StatKey.values) {
      expect(statNames[v], isNotNull, reason: v.name);
    }
    for (final v in Capability.values) {
      expect(capabilityNames[v], isNotNull, reason: v.name);
    }
    for (final v in Ailment.values) {
      expect(ailmentNames[v], isNotNull, reason: v.name);
    }
    for (final v in RefusalReason.values) {
      expect(refusalMessages[v], isNotNull, reason: v.name);
    }
  });

  test('카탈로그 전량에 이름이 있다', () {
    for (final def in ItemCatalog.builtIn.all) {
      expect(itemNames[def.nameKey], isNotNull, reason: def.ref.value);
      if (def.annexKey.isNotEmpty) {
        expect(annexNames[def.annexKey], isNotNull, reason: def.annexKey);
      }
    }
  });

  test('실험용 파티 전원에 이름이 있다', () {
    for (final t in sampleParty) {
      expect(memberNames[t.nameKey], isNotNull, reason: t.ref);
    }
  });

  test('이름표에 모델이 모르는 키가 없다', () {
    final known = {for (final d in ItemCatalog.builtIn.all) d.nameKey};
    for (final key in itemNames.keys) {
      expect(known, contains(key), reason: '$key 는 카탈로그에 없다');
    }
  });
}
