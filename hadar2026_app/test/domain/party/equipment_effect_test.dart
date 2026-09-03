import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/item/item_data.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/party.dart';
import 'package:hadar2026_app/domain/party/player.dart';

const _dagger = HDItemId(HDItemType.stab, index: 1); // 단도, attaPow 10
const _longSword = HDItemId(HDItemType.wield, index: 6); // 장검, attaPow 60
const _goldShield = HDItemId(HDItemType.shield, index: 5); // ac 5
const _leatherArmor = HDItemId(HDItemType.armor, index: 1); // ac 1
const _crown = HDItemId(HDItemType.head, index: 10); // ac 0

int _attaPowOf(HDItemId id) => itemById(id)!.param.attaPow;
int _acOf(HDItemId id) => itemById(id)!.param.ac;

void main() {
  group('powOfWeapon', () {
    test('bare hands read as the original 맨손 row', () {
      final p = HDPlayer();
      expect(p.equippedAt(HDEquipSlot.hand), isNull);
      expect(p.powOfWeapon, _attaPowOf(const HDItemId(HDItemType.wield)));
      expect(p.powOfWeapon, 1);
    });

    test('follows whatever is in the hand slot', () {
      final p = HDPlayer();
      p.equipItem(HDEquipSlot.hand, _dagger);
      expect(p.powOfWeapon, _attaPowOf(_dagger));
      expect(p.powOfWeapon, 10);

      p.equipItem(HDEquipSlot.hand, _longSword);
      expect(p.powOfWeapon, _attaPowOf(_longSword));
      expect(p.powOfWeapon, 60);

      p.unequip(HDEquipSlot.hand);
      expect(p.powOfWeapon, 1);
    });

    test('getAttribute reports the derived value', () {
      final p = HDPlayer()..weapon = 4; // 장검
      expect(p.getAttribute('pow_of_weapon'), 60);
    });

    // menace.cm2:49 and L1_ep1d0.cm2:169 both write pow_of_weapon directly.
    // Equipment owns the value now, so the write is refused out loud rather
    // than leaving two sources of truth (GROUND_TRUTH H-5).
    test('a script write is ignored, not silently half-applied', () {
      final p = HDPlayer()..weapon = 4;
      p.changeAttribute('pow_of_weapon', 100);
      expect(p.powOfWeapon, 60);
      p.changeAttribute('pow_of_shield', 9);
      p.changeAttribute('pow_of_armor', 9);
      expect(p.powOfShield, 0);
      expect(p.powOfArmor, 0);
    });
  });

  group('ac', () {
    test('is baseAc plus every worn slot', () {
      final p = HDPlayer()..baseAc = 3;
      expect(p.ac, 3);

      p.equipItem(HDEquipSlot.handSub, _goldShield);
      expect(p.ac, 3 + _acOf(_goldShield));

      p.equipItem(HDEquipSlot.armor, _leatherArmor);
      expect(p.ac, 3 + _acOf(_goldShield) + _acOf(_leatherArmor));
      expect(p.ac, 9);
      expect(p.equipmentAc, 6);
    });

    test('unequipping returns it to baseAc', () {
      final p = HDPlayer()..baseAc = 3;
      p.equipItem(HDEquipSlot.handSub, _goldShield);
      p.equipItem(HDEquipSlot.armor, _leatherArmor);
      p.unequip(HDEquipSlot.handSub);
      p.unequip(HDEquipSlot.armor);
      expect(p.ac, 3);
      expect(p.equipmentAc, 0);
    });

    // The trap this issue names: folding equipment into `ac` would wipe the
    // race/class value that party.dart:192,214 sets.
    test('baseAc survives every equip and unequip', () {
      final p = HDPlayer()..baseAc = 5;
      for (var round = 0; round < 3; round++) {
        p.equipItem(HDEquipSlot.armor, _leatherArmor);
        p.equipItem(HDEquipSlot.head, _crown);
        p.equipItem(HDEquipSlot.handSub, _goldShield);
        p.unequip(HDEquipSlot.armor);
        p.unequip(HDEquipSlot.head);
        p.unequip(HDEquipSlot.handSub);
        expect(p.baseAc, 5, reason: 'round $round');
        expect(p.ac, 5, reason: 'round $round');
      }
    });

    test('the ac setter and cm2 both move baseAc, not the total', () {
      final p = HDPlayer();
      p.equipItem(HDEquipSlot.armor, _leatherArmor); // ac 1
      p.ac = 4;
      expect(p.baseAc, 4);
      expect(p.ac, 5);

      p.changeAttribute('ac', 7);
      expect(p.baseAc, 7);
      expect(p.ac, 8);
      expect(p.getAttribute('ac'), 8);
    });

    test('the starting party keeps its own defence', () {
      final party = HDParty();
      // party.dart:192,214 -- baseAc 5 and 3, plus 가죽 갑옷 (ac 1).
      expect(party.players[0].baseAc, 5);
      expect(party.players[0].ac, 6);
      expect(party.players[1].baseAc, 3);
      expect(party.players[1].ac, 4);
    });
  });

  group('damage actually moves with the weapon', () {
    // battle.dart:429 is `strength * powOfWeapon * level.physical ~/ 20`,
    // then two unseeded Random() attenuations (P0-11) that cannot be pinned.
    // Fix the deterministic part only.
    int baseDamage(HDPlayer p) =>
        (p.strength * p.powOfWeapon * p.level.physical) ~/ 20;

    test('단도 vs 장검 on the same character', () {
      final p = HDPlayer()..strength = 18;
      p.level.physical = 1;

      p.equipItem(HDEquipSlot.hand, _dagger);
      expect(baseDamage(p), (18 * 10 * 1) ~/ 20); // 9

      p.equipItem(HDEquipSlot.hand, _longSword);
      expect(baseDamage(p), (18 * 60 * 1) ~/ 20); // 54

      p.unequip(HDEquipSlot.hand);
      expect(baseDamage(p), (18 * 1 * 1) ~/ 20); // 0 — 맨손
    });
  });

  group('save round-trip', () {
    test('v1 json restores the derived values through weapon/armor', () {
      final before = HDPlayer()
        ..baseAc = 5
        ..weapon = 4 // 장검
        ..armor = 1; // 가죽 갑옷
      expect(before.powOfWeapon, 60);
      expect(before.ac, 6);

      final json = before.toJson();
      expect(json['powOfWeapon'], 60, reason: 'save format unchanged');
      // 'ac' keeps its v1 meaning (the effective total); v2 readers take
      // 'baseAc'.
      expect(json['ac'], 6);
      expect(json['baseAc'], 5);

      final after = HDPlayer.fromJson(json);
      expect(after.weapon, 4);
      expect(after.powOfWeapon, 60);
      expect(after.baseAc, 5);
      expect(after.ac, 6);
    });

    test('repeated save/load does not inflate ac', () {
      var p = HDPlayer()
        ..baseAc = 5
        ..armor = 1;
      for (var i = 0; i < 5; i++) {
        p = HDPlayer.fromJson(p.toJson());
      }
      expect(p.baseAc, 5);
      expect(p.ac, 6);
    });
  });
}
