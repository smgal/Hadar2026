import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/player.dart';

const _longSword = HDItemId(HDItemType.wield, index: 6); // attaPow 60
const _goldShield = HDItemId(HDItemType.shield, index: 5); // ac 5

void main() {
  // GROUND_TRUTH H-1's first edition called powOfWeapon/powOfShield/powOfArmor
  // all dead and was wrong: powOfWeapon is the player's attack power at
  // battle.dart:429. These tests pin which of the three actually does
  // anything, so the same mistake cannot come back.
  //
  // G1-05 wired equipment into powOfWeapon and ac, so powOfWeapon is now a
  // derived getter with no setter -- the "write it and read it back" shape
  // this issue originally described no longer exists.

  group('powOfWeapon is live', () {
    test('changing the weapon changes it, and getAttribute follows', () {
      final p = HDPlayer();
      expect(p.powOfWeapon, 1); // 맨손
      expect(p.getAttribute('pow_of_weapon'), 1);

      p.equipItem(HDEquipSlot.hand, _longSword);
      expect(p.powOfWeapon, 60);
      expect(p.getAttribute('pow_of_weapon'), 60);
    });

    test('it feeds the damage formula battle.dart:429 uses', () {
      final p = HDPlayer()..strength = 10;
      p.level.physical = 2;
      int base() => (p.strength * p.powOfWeapon * p.level.physical) ~/ 20;

      final bare = base();
      p.equipItem(HDEquipSlot.hand, _longSword);
      expect(base(), greaterThan(bare));
    });
  });

  group('powOfShield / powOfArmor are dead', () {
    test('writing them does not move ac', () {
      final p = HDPlayer()..baseAc = 4;
      final before = p.ac;

      p.powOfShield = 99;
      p.powOfArmor = 99;

      expect(p.ac, before);
      expect(p.ac, 4);
    });

    test('a real shield moves ac, the dead field does not', () {
      final p = HDPlayer()..baseAc = 4;
      p.powOfShield = 99;
      expect(p.ac, 4);

      p.equipItem(HDEquipSlot.handSub, _goldShield);
      expect(p.ac, 9); // 4 + the shield's own ac of 5
    });

    test('cm2 writes are refused out loud, not silently absorbed', () {
      final p = HDPlayer();
      p.changeAttribute('pow_of_shield', 7);
      p.changeAttribute('pow_of_armor', 7);
      expect(p.powOfShield, 0);
      expect(p.powOfArmor, 0);
      expect(p.getAttribute('pow_of_shield'), 0);
      expect(p.getAttribute('pow_of_armor'), 0);
    });
  });

  group('serialisation still carries all three', () {
    test('the keys survive a round trip', () {
      final p = HDPlayer()
        ..baseAc = 3
        ..weapon = 4
        ..powOfShield = 2
        ..powOfArmor = 6;

      final json = p.toJson();
      expect(json.containsKey('powOfWeapon'), isTrue);
      expect(json['powOfWeapon'], 60);
      expect(json['powOfShield'], 2);
      expect(json['powOfArmor'], 6);

      final back = HDPlayer.fromJson(json);
      expect(back.powOfShield, 2);
      expect(back.powOfArmor, 6);
      // powOfWeapon is not read back -- it is re-derived from `weapon`.
      expect(back.powOfWeapon, 60);
    });
  });
}
