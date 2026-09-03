import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/domain/item/item.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';

void main() {
  group('HDItemType.wire', () {
    // These are the integer values of ITEM_TYPE in the original
    // (REF_UNITY_LoreEp1/src_as_cs/ObjTypes.cs:32-49). They ride into
    // cm2 arguments and save files packed inside HDItemId.wire, so they
    // are pinned as literals: reordering the enum must fail here rather
    // than silently rewrite every saved item.
    test('matches ITEM_TYPE in ObjTypes.cs', () {
      expect(HDItemType.none.wire, -1);
      expect(HDItemType.wield.wire, 0);
      expect(HDItemType.chop.wire, 1);
      expect(HDItemType.stab.wire, 2);
      expect(HDItemType.hit.wire, 3);
      expect(HDItemType.shoot.wire, 4);
      expect(HDItemType.summonSingle.wire, 5);
      expect(HDItemType.summonMulti.wire, 6);
      expect(HDItemType.shield.wire, 7);
      expect(HDItemType.armor.wire, 8);
      expect(HDItemType.head.wire, 9);
      expect(HDItemType.leg.wire, 10);
      expect(HDItemType.ornament.wire, 11);
    });

    test('covers 13 members with no duplicate wire value', () {
      expect(HDItemType.values.length, 13);
      final wires = HDItemType.values.map((t) => t.wire).toList();
      expect(wires.toSet().length, wires.length);
    });

    test('fromWire round-trips every member and rejects the rest', () {
      for (final type in HDItemType.values) {
        expect(HDItemType.fromWire(type.wire), type);
      }
      expect(HDItemType.fromWire(12), isNull);
      expect(HDItemType.fromWire(-2), isNull);
    });
  });

  group('HDItemType group predicates', () {
    // The original expressed these as `*_MIN <= x < *_MAX` ranges built
    // from aliased enum members; Dart cannot alias, so the ranges live
    // in the getters and the membership is pinned here instead.
    test('reproduce the original *_MIN / *_MAX ranges', () {
      expect(HDItemType.values.where((t) => t.isWeapon).toSet(), {
        HDItemType.wield,
        HDItemType.chop,
        HDItemType.stab,
        HDItemType.hit,
        HDItemType.shoot,
        HDItemType.summonSingle,
        HDItemType.summonMulti,
      });
      expect(HDItemType.values.where((t) => t.isShield).toSet(), {
        HDItemType.shield,
      });
      expect(HDItemType.values.where((t) => t.isArmorGroup).toSet(), {
        HDItemType.armor,
        HDItemType.head,
        HDItemType.leg,
      });
      expect(HDItemType.values.where((t) => t.isEtc).toSet(), {
        HDItemType.ornament,
      });
    });

    test('are mutually exclusive', () {
      for (final type in HDItemType.values) {
        final hits = [
          type.isWeapon,
          type.isShield,
          type.isArmorGroup,
          type.isEtc,
        ].where((b) => b).length;
        expect(hits, lessThanOrEqualTo(1), reason: '$type is in two groups');
      }
    });

    test('together cover every member except none', () {
      final grouped = HDItemType.values
          .where((t) => t.isWeapon || t.isShield || t.isArmorGroup || t.isEtc)
          .toSet();
      expect(grouped, HDItemType.values.toSet()..remove(HDItemType.none));
      expect(grouped.length, 12);
    });
  });

  group('HDItemType.equipSlot', () {
    test('maps all 12 real kinds onto the six EQUIP slots', () {
      expect(HDItemType.wield.equipSlot, HDEquipSlot.hand);
      expect(HDItemType.chop.equipSlot, HDEquipSlot.hand);
      expect(HDItemType.stab.equipSlot, HDEquipSlot.hand);
      expect(HDItemType.hit.equipSlot, HDEquipSlot.hand);
      expect(HDItemType.shoot.equipSlot, HDEquipSlot.hand);
      // ObjParty.cs:1651,1677 equip a summon's attack in its hand.
      expect(HDItemType.summonSingle.equipSlot, HDEquipSlot.hand);
      expect(HDItemType.summonMulti.equipSlot, HDEquipSlot.hand);
      expect(HDItemType.shield.equipSlot, HDEquipSlot.handSub);
      expect(HDItemType.armor.equipSlot, HDEquipSlot.armor);
      expect(HDItemType.head.equipSlot, HDEquipSlot.head);
      expect(HDItemType.leg.equipSlot, HDEquipSlot.leg);
      expect(HDItemType.ornament.equipSlot, HDEquipSlot.etc);
    });

    test('is null only for none', () {
      final unslotted = HDItemType.values
          .where((t) => t.equipSlot == null)
          .toSet();
      expect(unslotted, {HDItemType.none});
    });

    test('slot order matches EQUIP in ObjTypes.cs:81-85', () {
      expect(HDEquipSlot.hand.wire, 0);
      expect(HDEquipSlot.handSub.wire, 1);
      expect(HDEquipSlot.armor.wire, 2);
      expect(HDEquipSlot.head.wire, 3);
      expect(HDEquipSlot.leg.wire, 4);
      expect(HDEquipSlot.etc.wire, 5);
      expect(HDEquipSlot.values.length, 6);
      for (final slot in HDEquipSlot.values) {
        expect(HDEquipSlot.fromWire(slot.wire), slot);
      }
      expect(HDEquipSlot.fromWire(6), isNull);
    });
  });

  group('HDItemId.wire', () {
    // Same byte layout as ResId's low 24 bits (ObjItem.cs:93-106):
    // [ kind ][ detail ][ index ].
    test('packs kind / detail / index into three bytes', () {
      expect(const HDItemId(HDItemType.wield, index: 1).wire, 0x000001);
      expect(
        const HDItemId(HDItemType.armor, detail: 1, index: 3).wire,
        0x080103,
      );
      expect(
        const HDItemId(HDItemType.ornament, detail: 0xFF, index: 0xFF).wire,
        0x0BFFFF,
      );
    });

    test('round-trips through fromWire for every kind', () {
      for (final kind
          in HDItemType.values.where((t) => t != HDItemType.none)) {
        final id = HDItemId(kind, detail: 2, index: 7);
        final back = HDItemId.fromWire(id.wire);
        expect(back.kind, kind);
        expect(back.detail, 2);
        expect(back.index, 7);
        expect(back, id);
        expect(back.hashCode, id.hashCode);
      }
    });

    test('rejects wires that do not name an item', () {
      // 12 is past ORNAMENT, so 0x0C0000 has no kind.
      expect(HDItemId.tryFromWire(0x0C0000), isNull);
      expect(HDItemId.tryFromWire(-1), isNull);
      expect(HDItemId.tryFromWire(0x1000000), isNull);
      expect(() => HDItemId.fromWire(0x0C0000), throwsArgumentError);
    });

    test('none is not a usable kind', () {
      expect(() => HDItemId(HDItemType.none), throwsA(isA<AssertionError>()));
    });

    test('detail and index must fit in a byte', () {
      expect(
        () => HDItemId(HDItemType.wield, detail: 256),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HDItemId(HDItemType.wield, index: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('HDItem', () {
    test('keeps param.type and id.kind in step', () {
      expect(
        () => HDItem(
          id: const HDItemId(HDItemType.shield, index: 1),
          name: '나무 방패',
          param: const HDItemParam(ac: 2, type: HDItemType.armor),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('exposes its kind and defaults annex to empty', () {
      final item = HDItem(
        id: const HDItemId(HDItemType.wield, index: 1),
        name: '단검',
        param: const HDItemParam(attaPow: 3, type: HDItemType.wield),
      );
      expect(item.type, HDItemType.wield);
      expect(item.annex, '');
      expect(item.param.ac, 0);
    });

    test('ItemSub.GetDefault() is an empty slot', () {
      expect(HDItemParam.defaults.attaPow, 0);
      expect(HDItemParam.defaults.ac, 0);
      expect(HDItemParam.defaults.type, HDItemType.none);
    });
  });
}
