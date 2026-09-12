import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

ItemDef def(String ref) => ItemCatalog.builtIn[ItemRef(ref)]!;

/// The hand-composition table, walked cell by cell.
void main() {
  test('nothing in the main hand is unarmed', () {
    expect(weaponKindFor(right: null, left: null), WeaponKind.unarmed);
    expect(
      weaponKindFor(right: null, left: def('shield.leather')),
      WeaponKind.unarmed,
    );
  });

  test('one weapon and a free hand is the light style', () {
    expect(
      weaponKindFor(right: def('weapon.sabre'), left: null),
      WeaponKind.oneHanded,
    );
  });

  test('a shield names the style, and a spear names it differently', () {
    expect(
      weaponKindFor(right: def('weapon.sabre'), left: def('shield.leather')),
      WeaponKind.swordAndShield,
    );
    expect(
      weaponKindFor(
        right: def('weapon.short_spear'),
        left: def('shield.leather'),
      ),
      WeaponKind.spearAndShield,
    );
  });

  test('two of the same class is dual wielding, whatever the class', () {
    expect(
      weaponKindFor(right: def('weapon.sabre'), left: def('weapon.dagger')),
      WeaponKind.dualWield,
    );
    expect(
      weaponKindFor(right: def('weapon.hand_axe'), left: def('weapon.flail')),
      WeaponKind.dualWield,
    );
    expect(
      weaponKindFor(right: def('weapon.club'), left: def('weapon.knuckle')),
      WeaponKind.dualWield,
    );
  });

  test('a light in the off hand makes a torchbearer', () {
    expect(
      weaponKindFor(right: def('weapon.sabre'), left: def('light.torch')),
      WeaponKind.torchbearer,
    );
  });

  test('two hands are named by shape', () {
    expect(
      weaponKindFor(right: def('weapon.long_sword')),
      WeaponKind.greatSword,
    );
    expect(
      weaponKindFor(right: def('weapon.war_hammer')),
      WeaponKind.warHammer,
    );
    expect(weaponKindFor(right: def('weapon.halberd')), WeaponKind.polearm);
    expect(weaponKindFor(right: def('weapon.poleaxe')), WeaponKind.polearm);
    expect(weaponKindFor(right: def('weapon.battle_axe')), WeaponKind.polearm);
  });

  test('some shapes are their own answer whatever the other hand holds', () {
    for (final ref in const [
      ('weapon.bow', WeaponKind.bow),
      ('weapon.crossbow', WeaponKind.crossbow),
      ('weapon.arbalest', WeaponKind.arbalest),
      ('weapon.lancer', WeaponKind.lance),
      ('weapon.cavalry_lance', WeaponKind.lance),
      ('weapon.long_staff', WeaponKind.longStaff),
      ('weapon.javelin', WeaponKind.thrown),
      ('weapon.blowpipe', WeaponKind.thrown),
    ]) {
      expect(weaponKindFor(right: def(ref.$1)), ref.$2, reason: ref.$1);
      expect(
        weaponKindFor(right: def(ref.$1), left: def('shield.leather')),
        ref.$2,
        reason: '${ref.$1} with a shield',
      );
    }
  });

  test('every weapon in the catalogue resolves to a named style', () {
    // The claim that the style is a total function of the hands: no
    // combination falls through to a default.
    for (final d in ItemCatalog.builtIn.all.where((d) => d.kind.isWeapon)) {
      final alone = weaponKindFor(right: d);
      expect(alone, isNot(WeaponKind.unarmed), reason: d.ref.value);
    }
  });

  test('only the styles with a free hand can carry a light', () {
    expect(WeaponKind.oneHanded.canCarryLight, isTrue);
    expect(WeaponKind.thrown.canCarryLight, isTrue);
    expect(WeaponKind.unarmed.canCarryLight, isTrue);
    expect(WeaponKind.greatSword.canCarryLight, isFalse);
    expect(WeaponKind.dualWield.canCarryLight, isFalse);
    expect(WeaponKind.swordAndShield.canCarryLight, isFalse);
  });
}
