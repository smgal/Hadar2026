import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/item/item_data.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/player.dart';

const _longSword = HDItemId(HDItemType.wield, index: 6); // 장검
const _goldShield = HDItemId(HDItemType.shield, index: 5); // 금제 방패
const _leatherArmor = HDItemId(HDItemType.armor, index: 1); // 가죽 갑옷
const _crown = HDItemId(HDItemType.head, index: 10); // 황금 왕관
const _wingedShoes = HDItemId(HDItemType.leg, index: 4); // 날개 신발
const _belt = HDItemId(HDItemType.ornament, index: 1); // 멋쟁이 혁띠
const _bareHand = HDItemId(HDItemType.wield, index: 0); // 맨손

void main() {
  group('HDEquipSlot', () {
    // Save files and G1-07's cursor both ride on these, so they are declared
    // rather than left to Enum.index — same rule as HDItemType.wire.
    test('wire order matches EQUIP in ObjTypes.cs:81-85', () {
      expect(HDEquipSlot.hand.wire, 0);
      expect(HDEquipSlot.handSub.wire, 1);
      expect(HDEquipSlot.armor.wire, 2);
      expect(HDEquipSlot.head.wire, 3);
      expect(HDEquipSlot.leg.wire, 4);
      expect(HDEquipSlot.etc.wire, 5);
      expect(HDEquipSlot.values.length, 6);
    });
  });

  group('HDPlayer.equipItem', () {
    test('starts with all six slots empty', () {
      final p = HDPlayer();
      expect(p.equip.length, 6);
      for (final slot in HDEquipSlot.values) {
        expect(p.equippedAt(slot), isNull, reason: '$slot');
      }
    });

    test('fills every one of the six body parts', () {
      final p = HDPlayer();
      expect(p.equipItem(HDEquipSlot.hand, _longSword), isTrue);
      expect(p.equipItem(HDEquipSlot.handSub, _goldShield), isTrue);
      expect(p.equipItem(HDEquipSlot.armor, _leatherArmor), isTrue);
      expect(p.equipItem(HDEquipSlot.head, _crown), isTrue);
      expect(p.equipItem(HDEquipSlot.leg, _wingedShoes), isTrue);
      expect(p.equipItem(HDEquipSlot.etc, _belt), isTrue);

      expect(p.equippedAt(HDEquipSlot.head), _crown);
      expect(p.getWeaponName(), '장검');
      expect(p.getShieldName(), '금제 방패');
      expect(p.getArmorName(), '가죽 갑옷');
    });

    test('refuses a mismatched part and leaves the slot untouched', () {
      final p = HDPlayer();
      p.equipItem(HDEquipSlot.head, _crown);

      expect(p.equipItem(HDEquipSlot.head, _leatherArmor), isFalse);
      expect(p.equipItem(HDEquipSlot.hand, _goldShield), isFalse);
      expect(p.equipItem(HDEquipSlot.armor, _longSword), isFalse);
      expect(p.equipItem(HDEquipSlot.etc, _wingedShoes), isFalse);

      expect(p.equippedAt(HDEquipSlot.head), _crown);
      expect(p.equippedAt(HDEquipSlot.hand), isNull);
      expect(p.equippedAt(HDEquipSlot.armor), isNull);
      expect(p.equippedAt(HDEquipSlot.etc), isNull);
    });

    test('every catalog row goes in exactly the slot its kind names', () {
      for (final item in itemTable) {
        final p = HDPlayer();
        final wanted = item.type.equipSlot;
        for (final slot in HDEquipSlot.values) {
          expect(
            p.equipItem(slot, item.id),
            slot == wanted,
            reason: '${item.name} into $slot',
          );
        }
      }
    });
  });

  group('HDPlayer.unequip', () {
    test('empties the slot and hands the item back', () {
      final p = HDPlayer();
      p.equipItem(HDEquipSlot.armor, _leatherArmor);
      expect(p.unequip(HDEquipSlot.armor), _leatherArmor);
      expect(p.equippedAt(HDEquipSlot.armor), isNull);
      expect(p.getArmorName(), '평상복');
    });

    test('an empty slot yields null', () {
      expect(HDPlayer().unequip(HDEquipSlot.leg), isNull);
    });

    // GameEventEquipment.cs:122 -- bare hands cannot be taken off.
    test('refuses to unequip bare hands', () {
      final p = HDPlayer();
      p.equipItem(HDEquipSlot.hand, _bareHand);
      expect(p.unequip(HDEquipSlot.hand), isNull);
      expect(p.equippedAt(HDEquipSlot.hand), _bareHand);
      // A real weapon in the same slot comes off fine.
      p.equipItem(HDEquipSlot.hand, _longSword);
      expect(p.unequip(HDEquipSlot.hand), _longSword);
    });
  });

  group('legacy integer attributes', () {
    // cm2 content reads and writes these (lore_ep1.cm2:386-389,
    // menace.cm2:46-52), so the derived getters/setters have to behave
    // exactly as the old int fields did.
    test('weapon/shield/armor round-trip through the slots', () {
      final p = HDPlayer();
      for (var i = 0; i < legacyWeaponNames.length; i++) {
        p.weapon = i;
        expect(p.weapon, i, reason: 'weapon $i');
        expect(p.getWeaponName(), legacyWeaponNames[i]);
      }
      for (var i = 0; i < legacyShieldNames.length; i++) {
        p.shield = i;
        expect(p.shield, i, reason: 'shield $i');
        expect(p.getShieldName(), legacyShieldNames[i]);
      }
      for (var i = 0; i < legacyArmorNames.length; i++) {
        p.armor = i;
        expect(p.armor, i, reason: 'armor $i');
        expect(p.getArmorName(), legacyArmorNames[i]);
      }
    });

    test('getAttribute reads the same values', () {
      final p = HDPlayer()
        ..weapon = 4
        ..shield = 2
        ..armor = 3;
      expect(p.getAttribute('weapon'), 4);
      expect(p.getAttribute('shield'), 2);
      expect(p.getAttribute('armor'), 3);
    });

    test('an out-of-range write leaves the slot as it was', () {
      final p = HDPlayer()..weapon = 4;
      p.changeAttribute('weapon', 10); // table holds 0..9
      expect(p.weapon, 4);
      expect(p.equippedAt(HDEquipSlot.hand), _longSword);

      p.changeAttribute('weapon', -1);
      expect(p.weapon, 4);
    });

    // menace.cm2:46-52 strips the party by writing 0 to each slot.
    test('writing 0 empties the slot, as menace.cm2 expects', () {
      final p = HDPlayer()
        ..weapon = 4
        ..shield = 5
        ..armor = 1;
      p.equipItem(HDEquipSlot.head, _crown);
      p.equipItem(HDEquipSlot.leg, _wingedShoes);
      p.equipItem(HDEquipSlot.etc, _belt);

      p.changeAttribute('weapon', 0);
      p.changeAttribute('shield', 0);
      p.changeAttribute('armor', 0);
      p.unequip(HDEquipSlot.head);
      p.unequip(HDEquipSlot.leg);
      p.unequip(HDEquipSlot.etc);

      for (final slot in HDEquipSlot.values) {
        expect(p.equippedAt(slot), isNull, reason: '$slot');
      }
      expect(p.weapon, 0);
      expect(p.shield, 0);
      expect(p.armor, 0);
      expect(p.getWeaponName(), '맨손');
    });

    test('an item outside the legacy 10 does not read back as "no weapon"', () {
      // 그라디우스 is in the catalog but not in the C++ ten, so cm2 must not
      // be told the hand is empty. The value does not round-trip; the
      // getter says so on the debug log.
      final p = HDPlayer();
      p.equipItem(HDEquipSlot.hand, const HDItemId(HDItemType.wield, index: 2));
      expect(p.weapon, isNot(0));
    });

    test('toJson still carries the three integers', () {
      final json = (HDPlayer()
            ..weapon = 3
            ..shield = 1
            ..armor = 2)
          .toJson();
      expect(json['weapon'], 3);
      expect(json['shield'], 1);
      expect(json['armor'], 2);

      final back = HDPlayer.fromJson(json);
      expect(back.weapon, 3);
      expect(back.getWeaponName(), '미늘창');
      expect(back.equippedAt(HDEquipSlot.armor), isNotNull);
    });
  });
}
