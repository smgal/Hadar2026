import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

/// Every number that crosses a boundary, spelled out.
///
/// Three readers depend on these: the HTTP surface, a save file, and the
/// legacy scripts. If a member is inserted and the values shift, this
/// test says so before anything else notices.
void main() {
  test('slots keep the numbers the previous model shipped', () {
    expect(
      {for (final s in EquipSlot.values) s.name: s.wire},
      // 0..5 are the old six body parts; the two class-amulet slots are
      // new and sit after them, so an older save simply lacks them.
      {
        'rightHand': 0,
        'leftHand': 1,
        'body': 2,
        'head': 3,
        'legs': 4,
        'commonAmulet': 5,
        'classAmulet1': 6,
        'classAmulet2': 7,
      },
    );
  });

  test('item kinds keep the original ITEM_TYPE numbering', () {
    expect(ItemKind.slashWeapon.wire, 0);
    expect(ItemKind.chopWeapon.wire, 1);
    expect(ItemKind.pierceWeapon.wire, 2);
    expect(ItemKind.bluntWeapon.wire, 3);
    expect(ItemKind.missileWeapon.wire, 4);
    expect(ItemKind.shield.wire, 7);
    expect(ItemKind.bodyArmour.wire, 8);
    expect(ItemKind.helmet.wire, 9);
    expect(ItemKind.boots.wire, 10);
    expect(ItemKind.commonAmulet.wire, 11);
    expect(ItemKind.consumable.wire, 12);
    // Past the original's exclusive upper bound of 12.
    expect(ItemKind.light.wire, 13);
    expect(ItemKind.classAmulet.wire, 14);
  });

  test('classes keep the numbering the original forbade reordering', () {
    expect(CharacterClass.unknown.wire, 0);
    expect(CharacterClass.knight.wire, 2);
    expect(CharacterClass.esper.wire, 8);
    expect(CharacterClass.timewalker.wire, 16);
    expect(CharacterClass.values.length, 17);
  });

  test('only 1..8 can be made at character creation', () {
    expect(
      [for (final c in CharacterClass.values) if (c.isStarting) c.wire],
      [1, 2, 3, 4, 5, 6, 7, 8],
    );
  });

  test('every wired enum has distinct values and resolves back', () {
    void check<T extends Wired>(List<T> values) {
      final wires = [for (final v in values) v.wire];
      expect(wires.toSet().length, wires.length, reason: '$T');
      for (final v in values) {
        expect(byWire(values, v.wire), same(v), reason: '$T ${v.wire}');
      }
      expect(byWire(values, -999), isNull, reason: '$T out of range');
    }

    check(EquipSlot.values);
    check(ItemKind.values);
    check(Hands.values);
    check(WeaponShape.values);
    check(CharacterClass.values);
    check(ClassType.values);
    check(SkillType.values);
    check(StatKey.values);
    check(ModifierOp.values);
    check(Ailment.values);
    check(Capability.values);
    check(WeaponKind.values);
    check(FightingStyle.values);
    check(RefusalReason.values);
  });

  test('the display order shows every slot exactly once', () {
    expect(EquipSlot.displayOrder.toSet(), EquipSlot.values.toSet());
    expect(EquipSlot.displayOrder.length, EquipSlot.values.length);
  });
}
