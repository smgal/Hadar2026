import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/party.dart';
import 'package:hadar2026_app/domain/party/player.dart';

const _dagger = HDItemId(HDItemType.stab, index: 1);
const _longSword = HDItemId(HDItemType.wield, index: 6); // 장검
const _goldShield = HDItemId(HDItemType.shield, index: 5); // ac 5
const _leatherArmor = HDItemId(HDItemType.armor, index: 1); // ac 1
const _crown = HDItemId(HDItemType.head, index: 10);
const _wingedShoes = HDItemId(HDItemType.leg, index: 4);
const _belt = HDItemId(HDItemType.ornament, index: 1);

/// A save written before items existed. Pinned as a literal on purpose:
/// the v1 schema is no longer anywhere in the code, so this test is its
/// only remaining specification. Do not regenerate it from toJson().
const String _v1PlayerJson = '''
{
  "name": "슴갈", "order": 0, "gender": 0, "characterClass": 0,
  "strength": 18, "mentality": 20, "concentration": 20, "endurance": 15,
  "resistance": 0, "agility": 12, "luck": 0,
  "ac": 5,
  "hp": 150, "maxHp": 150, "sp": 100, "maxSp": 100, "esp": 100,
  "maxEsp": 100, "experience": 0,
  "accuracy": {"physical": 15, "magic": 15, "esp": 15},
  "level": {"physical": 1, "magic": 20, "esp": 20},
  "poison": 0, "unconscious": 0, "dead": 0,
  "weapon": 4, "shield": 0, "armor": 1,
  "powOfWeapon": 12, "powOfShield": 0, "powOfArmor": 5
}
''';

void main() {
  group('v2 round trip', () {
    test('all six equipment slots survive', () {
      final before = HDPlayer()
        ..baseAc = 4
        ..name = '슴갈';
      before.equipItem(HDEquipSlot.hand, _longSword);
      before.equipItem(HDEquipSlot.handSub, _goldShield);
      before.equipItem(HDEquipSlot.armor, _leatherArmor);
      before.equipItem(HDEquipSlot.head, _crown);
      before.equipItem(HDEquipSlot.leg, _wingedShoes);
      before.equipItem(HDEquipSlot.etc, _belt);

      final after = HDPlayer.fromJson(
        jsonDecode(jsonEncode(before.toJson())) as Map<String, dynamic>,
      );

      for (final slot in HDEquipSlot.values) {
        expect(after.equippedAt(slot), before.equippedAt(slot),
            reason: '$slot');
      }
      expect(after.baseAc, 4);
      expect(after.ac, before.ac);
      expect(after.powOfWeapon, before.powOfWeapon);
    });

    test('all twenty backpack slots survive, holes included', () {
      final before = HDParty();
      before.give(_dagger);
      before.give(_goldShield);
      before.give(_crown);
      before.take(_goldShield); // leave a hole at slot 1

      final after = HDParty()
        ..fromJson(
          jsonDecode(jsonEncode(before.toJson())) as Map<String, dynamic>,
        );

      expect(after.itemCapacity, 20);
      for (var i = 0; i < 20; i++) {
        expect(after.itemAt(i), before.itemAt(i), reason: 'slot $i');
      }
      expect(after.itemAt(0), _dagger);
      expect(after.itemAt(1), isNull);
      expect(after.itemAt(2), _crown);
      expect(after.itemCount, 2);
    });

    test('repeated save/load leaves ac and powOfWeapon fixed', () {
      var p = HDPlayer()..baseAc = 5;
      p.equipItem(HDEquipSlot.hand, _longSword);
      p.equipItem(HDEquipSlot.armor, _leatherArmor);
      for (var i = 0; i < 5; i++) {
        p = HDPlayer.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
        );
      }
      expect(p.baseAc, 5);
      expect(p.ac, 6);
      expect(p.powOfWeapon, 60);
    });

    test('a corrupt slot is dropped, not force-fitted', () {
      final json = (HDPlayer()..baseAc = 2).toJson();
      // A helmet id parked in the hand slot, and garbage in the leg slot.
      json['equip'] = [_crown.wire, -1, -1, -1, 9999999, -1];
      final p = HDPlayer.fromJson(json);
      expect(p.equippedAt(HDEquipSlot.hand), isNull);
      expect(p.equippedAt(HDEquipSlot.leg), isNull);
    });
  });

  group('v1 migration', () {
    Map<String, dynamic> v1() =>
        jsonDecode(_v1PlayerJson) as Map<String, dynamic>;

    test('the three integers become slots', () {
      final p = HDPlayer.fromJson(v1());
      expect(p.equippedAt(HDEquipSlot.hand), isNotNull);
      expect(p.getWeaponName(), '장검'); // weapon index 4
      expect(p.equippedAt(HDEquipSlot.handSub), isNull); // shield 0
      expect(p.getArmorName(), '가죽 갑옷'); // armor index 1
      expect(p.weapon, 4);
      expect(p.armor, 1);
    });

    test('the parts v1 never had come back empty', () {
      final p = HDPlayer.fromJson(v1());
      expect(p.equippedAt(HDEquipSlot.head), isNull);
      expect(p.equippedAt(HDEquipSlot.leg), isNull);
      expect(p.equippedAt(HDEquipSlot.etc), isNull);
    });

    test("v1's final ac is preserved, not inflated by the migration", () {
      final p = HDPlayer.fromJson(v1());
      // v1 said ac 5 with 가죽 갑옷 (ac 1) worn. Equipment now counts, so
      // baseAc absorbs the difference and the effective ac still reads 5.
      expect(p.equipmentAc, 1);
      expect(p.baseAc, 4);
      expect(p.ac, 5);
    });

    test('baseAc clamps at 0 rather than going negative', () {
      final json = v1()
        ..['ac'] = 0
        ..['armor'] = 5; // 금제 갑옷, ac 5
      final p = HDPlayer.fromJson(json);
      expect(p.baseAc, 0);
      expect(p.ac, 5);
    });

    test('an out-of-range integer falls back to index 0', () {
      final json = v1()..['weapon'] = 99;
      final p = HDPlayer.fromJson(json);
      expect(p.weapon, 0);
      expect(p.getWeaponName(), '맨손');
      expect(p.equippedAt(HDEquipSlot.hand), isNull);
    });

    test("v1's powOfWeapon is discarded in favour of the weapon", () {
      final p = HDPlayer.fromJson(v1());
      // v1 stored 12; 장검 is worth 60.
      expect(p.powOfWeapon, 60);
    });

    test('a v1 party payload gets an empty backpack', () {
      final party = HDParty()
        ..fromJson({
          'x': 1,
          'y': 2,
          'food': 50,
          'gold': 900,
          'players': [v1()],
        });
      expect(party.itemCapacity, 20);
      expect(party.itemCount, 0);
      expect(party.food, 50);
      expect(party.gold, 900);
    });
  });

  group('the v1 keys are still written', () {
    test('weapon/shield/armor carry the index derived from the slots', () {
      final p = HDPlayer();
      p.equipItem(HDEquipSlot.hand, _longSword);
      p.equipItem(HDEquipSlot.armor, _leatherArmor);
      final json = p.toJson();
      expect(json['weapon'], 4);
      expect(json['shield'], 0);
      expect(json['armor'], 1);
    });

    test('the added payload is well under a kilobyte per character', () {
      final bare = HDPlayer();
      final loaded = HDPlayer()
        ..equipItem(HDEquipSlot.hand, _longSword)
        ..equipItem(HDEquipSlot.etc, _belt);
      final added = jsonEncode(loaded.toJson()).length -
          jsonEncode(bare.toJson()).length;
      expect(added.abs(), lessThan(64));

      final party = HDParty();
      for (var i = 0; i < party.itemCapacity; i++) {
        party.give(_dagger);
      }
      final full = jsonEncode(party.toJson()).length;
      final empty = jsonEncode(HDParty().toJson()).length;
      expect(full - empty, lessThan(1024));
    });
  });
}
