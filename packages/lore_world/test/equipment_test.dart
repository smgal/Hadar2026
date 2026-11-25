import 'package:lore_world/lore_world.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('equip', () {
    test('takes one out of the backpack and the power is there at once', () {
      final w = worldWith(fighter())..give('weapon.long_sword', 2);
      final out = w.equip(0, 'weapon.long_sword');
      expect(out.ok, isTrue);
      expect(out.first<Equipped>()!.slot, EquipSlot.weapon);
      expect(w.countOf('weapon.long_sword'), 1);
      // 원작은 다시 계산하지 않아 전직 전까지 효과가 없었다(부록 A #1).
      expect(w.protagonist!.weaponPower, 60);
      expect(w.protagonist!.weaponKind, WeaponKind.slash);
    });

    test('an occupied slot must be cleared first', () {
      final w = worldWith(fighter(weapon: 'weapon.club'))..give('weapon.mace');
      expect(w.equip(0, 'weapon.mace').reason, RefusalReason.slotOccupied);
      expect(w.unequip(0, EquipSlot.weapon).ok, isTrue);
      expect(w.countOf('weapon.club'), 1);
      expect(w.equip(0, 'weapon.mace').ok, isTrue);
      expect(w.protagonist!.weaponPower, 60);
    });

    test('class limits refuse and leave the backpack alone', () {
      final w = worldWith(fighter(classId: ClassId.monk))
        ..give('weapon.club')
        ..give('shield.leather')
        ..give('armour.plate');
      expect(w.equip(0, 'weapon.club').reason, RefusalReason.classCannotUse);
      expect(w.equip(0, 'shield.leather').reason, RefusalReason.classCannotUse);
      expect(w.countOf('weapon.club'), 1);
      // 전투사 계열은 갑옷은 전부 입는다.
      expect(w.equip(0, 'armour.plate').ok, isTrue);
      expect(w.protagonist!.ac, 10);
    });

    test('a mage wears leather armour and nothing else', () {
      final w = worldWith(mage())
        ..give('armour.leather')
        ..give('armour.ring_mail')
        ..give('weapon.dagger')
        ..give('shield.leather');
      expect(w.checkEquip(0, 'armour.ring_mail'), RefusalReason.classCannotUse);
      expect(w.checkEquip(0, 'weapon.dagger'), RefusalReason.classCannotUse);
      expect(w.checkEquip(0, 'shield.leather'), RefusalReason.classCannotUse);
      expect(w.equip(0, 'armour.leather').ok, isTrue);
      expect(w.protagonist!.ac, 1);
    });

    test('other refusals are named', () {
      final w = worldWith(fighter());
      expect(w.equip(0, 'weapon.bow').reason, RefusalReason.notInBackpack);
      expect(w.equip(0, 'weapon.nope').reason, RefusalReason.unknownItem);
      expect(w.equip(0, 'item.hp_potion').reason, RefusalReason.unknownItem);
      expect(w.equip(4, 'weapon.bow').reason, RefusalReason.noSuchMember);
    });

    test('an assistant with no class cannot be dressed', () {
      final w = worldWith(fighter())..give('armour.leather');
      w.setAssistant(
        Member(family: Family.giant, abilities: List.filled(8, 10)),
      );
      expect(w.equip(5, 'armour.leather').reason, RefusalReason.classCannotUse);
    });
  });

  group('unequip and discard', () {
    test('unequip returns the piece to the backpack', () {
      final w = worldWith(fighter(armour: 'armour.chain_mail'));
      expect(w.protagonist!.ac, 5);
      final out = w.unequip(0, EquipSlot.armour);
      expect(out.first<Unequipped>()!.key, 'armour.chain_mail');
      expect(w.protagonist!.ac, 2);
      expect(w.countOf('armour.chain_mail'), 1);
      expect(
        w.unequip(0, EquipSlot.armour).reason,
        RefusalReason.nothingEquipped,
      );
    });

    test('a full stack refuses the unequip rather than losing the piece', () {
      final w = worldWith(fighter(weapon: 'weapon.club'))
        ..give('weapon.club', 255);
      expect(w.unequip(0, EquipSlot.weapon).reason, RefusalReason.backpackFull);
      expect(w.protagonist!.weapon, 'weapon.club');
    });

    test('discard destroys what is worn', () {
      final w = worldWith(fighter(shield: 'shield.platinum'));
      final out = w.discardEquipped(0, EquipSlot.shield);
      expect(out.first<EquipmentDiscarded>()!.key, 'shield.platinum');
      expect(w.protagonist!.shield, isNull);
      expect(w.countOf('shield.platinum'), 0);
      expect(
        w.discardEquipped(0, EquipSlot.shield).reason,
        RefusalReason.nothingEquipped,
      );
    });

    test('changing armour clears armour damage', () {
      final m = fighter(armour: 'armour.plate')..acPenalty = 4;
      final w = worldWith(m);
      expect(m.ac, 6);
      w.unequip(0, EquipSlot.armour);
      expect(m.acPenalty, 0);
      w.equip(0, 'armour.plate');
      expect(m.ac, 10);
    });
  });

  group('equipment tables', () {
    test('28 weapons in chapter order, plus the Part 1 flame sword', () {
      expect(weaponTable.length, 29);
      expect(
        [for (final w in weaponTable) w.legacyId],
        [for (var i = 1; i <= 29; i++) i],
      );
      expect(weaponByLegacyId(1)!.key, 'weapon.short_sword');
      expect(weaponByLegacyId(7)!.kind, WeaponKind.slash);
      expect(weaponByLegacyId(8)!.kind, WeaponKind.chop);
      expect(weaponByLegacyId(14)!.key, 'weapon.halberd');
      expect(weaponByLegacyId(15)!.kind, WeaponKind.pierce);
      expect(weaponByLegacyId(21)!.key, 'weapon.poleaxe');
      expect(weaponByLegacyId(22)!.kind, WeaponKind.shoot);
      expect(weaponByLegacyId(28)!.key, 'weapon.arbalest');
      final flame = weaponByKey('weapon.flame_sword')!;
      expect(flame.onlyIn, Episode.ep1);
      expect(flame.price, 100000);
    });

    test('seven of each kind', () {
      for (final kind in [
        WeaponKind.slash,
        WeaponKind.chop,
        WeaponKind.pierce,
        WeaponKind.shoot,
      ]) {
        expect(
          weaponTable.where((w) => w.kind == kind && w.onlyIn == null).length,
          7,
        );
      }
    });

    test('every weapon has seven class columns', () {
      for (final w in weaponTable) {
        expect(w.power.length, 7, reason: w.key);
      }
    });

    test('shields 1..5 and armours 1..11 carry their defence', () {
      expect([for (final s in shieldTable) s.defence], [1, 2, 3, 4, 5]);
      expect(
        [for (final s in shieldTable) s.price],
        [3000, 15000, 45000, 80000, 150000],
      );
      expect(
        [for (final a in armourTable) a.defence],
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20],
      );
      expect(armourByKey('armour.obsidian')!.price, isNull);
      expect(armourByLegacyId(10)!.price, 500000);
    });

    test('keys are unique and namespaced', () {
      final keys = allEquipmentKeys;
      expect(keys.toSet().length, keys.length);
      expect(keys.length, 29 + 5 + 11);
      for (final w in weaponTable) {
        expect(w.key, startsWith('weapon.'));
      }
      for (final s in shieldTable) {
        expect(s.key, startsWith('shield.'));
      }
      for (final a in armourTable) {
        expect(a.key, startsWith('armour.'));
      }
    });
  });

  group('blessWeapons (1편 리겔의 「신의 축복」)', () {
    test('행운 판정 두 번을 모두 통과하면 무기 공격력이 ×1.2', () {
      // 행운 10 — 난수 3·4 는 통과, 15 는 실패
      final w = worldWith(fighter(weapon: 'weapon.long_sword'));
      expect(w.protagonist!.weaponPower, 60);
      final out = w.blessWeapons(rng: ScriptedRandom([3, 4]));
      expect(out.ok, isTrue);
      expect(out.first<WeaponBlessed>()!.seat, 0);
      expect(w.protagonist!.weaponPower, 72);
    });

    test('한 번이라도 실패하면 축복이 없다', () {
      final w = worldWith(fighter(weapon: 'weapon.long_sword'));
      final out = w.blessWeapons(rng: ScriptedRandom([3, 15]));
      expect(out.first<WeaponBlessed>(), isNull);
      expect(w.protagonist!.weaponPower, 60);
    });

    test('맨손은 축복을 받지 않고 난수도 굴리지 않는다', () {
      final w = worldWith(fighter());
      final rng = ScriptedRandom([0, 0]);
      w.blessWeapons(rng: rng);
      expect(rng.draws, 0);
      expect(w.protagonist!.weaponBlessed, isFalse);
    });

    test('무기를 내려놓으면 축복이 끝나고, 같은 무기를 다시 들어도 돌아오지 않는다', () {
      final w = worldWith(fighter(weapon: 'weapon.long_sword'));
      w.blessWeapons(rng: ScriptedRandom([0, 0]));
      expect(w.protagonist!.weaponPower, 72);
      expect(w.unequip(0, EquipSlot.weapon).ok, isTrue);
      expect(w.equip(0, 'weapon.long_sword').ok, isTrue);
      expect(w.protagonist!.weaponPower, 60);
    });

    test('축복은 세이브에 실린다', () {
      final w = worldWith(fighter(weapon: 'weapon.long_sword'));
      w.blessWeapons(rng: ScriptedRandom([0, 0]));
      final back = Member.fromJson(w.protagonist!.toJson());
      expect(back.weaponBlessed, isTrue);
      expect(back.weaponPower, 72);
    });
  });
}
