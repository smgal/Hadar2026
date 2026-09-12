import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

void main() {
  final catalog = ItemCatalog.builtIn;

  test('the original list is all thirty-one weapons, plus five fists', () {
    final weapons = catalog.all.where((d) => d.kind.isWeapon).toList();
    expect(weapons.length, 36);
    expect(weapons.where((d) => !d.removable).length, 5);
    // Seven, seven, seven, three, seven — the original's own split.
    int real(ItemKind kind) =>
        catalog.ofKind(kind).where((d) => d.removable).length;
    expect(real(ItemKind.slashWeapon), 7);
    expect(real(ItemKind.chopWeapon), 7);
    expect(real(ItemKind.pierceWeapon), 7);
    expect(real(ItemKind.bluntWeapon), 3);
    expect(real(ItemKind.missileWeapon), 7);
  });

  test('attack powers are the original numbers', () {
    int power(String ref) => catalog[ItemRef(ref)]!.attackPower;
    expect(power('weapon.knife'), 10);
    expect(power('weapon.dagger'), 15);
    expect(power('weapon.club'), 25);
    expect(power('weapon.long_sword'), 60);
    expect(power('weapon.flamberge'), 70);
    expect(power('weapon.halberd'), 80);
    expect(power('weapon.poleaxe'), 90);
    expect(power('weapon.arbalest'), 70);
  });

  test('no two rows share a ref', () {
    final refs = [for (final d in catalog.all) d.ref.value];
    expect(refs.toSet().length, refs.length);
  });

  test('a missing ref answers null rather than a default', () {
    // Silently falling back to bare hands is how a save that names an
    // item this build lacks would go unnoticed.
    expect(catalog[const ItemRef('weapon.nonesuch')], isNull);
    expect(catalog.contains(const ItemRef('weapon.dagger')), isTrue);
  });

  test('everything worn has a place, and only what is drunk has none', () {
    // A consumable is carried, never worn. It is the only kind with no
    // slot at all, and saying so here keeps a future kind from quietly
    // becoming unequippable.
    final slotless = {
      for (final d in catalog.all)
        if (d.allowedSlots.isEmpty) d.kind,
    };
    expect(slotless, {ItemKind.consumable});
    for (final d in catalog.all) {
      expect(d.allowedSlots, d.kind.allowedSlots, reason: d.ref.value);
    }
  });

  test('the ten consumables carry the numbers the previous model used', () {
    final rows = catalog.ofKind(ItemKind.consumable).toList();
    expect(rows.length, 10);
    expect(
      [for (final r in rows) r.ref.value],
      [
        'consumable.potion',
        'consumable.antidote',
        'consumable.elixir',
        'consumable.revive_charm',
        'consumable.sp_tonic',
        'consumable.poison_vial',
        'consumable.paralysis_vial',
        'consumable.fire_vial',
        'consumable.fire_crystal',
        'consumable.storm_crystal',
      ],
    );
    // Order is identity here — the index reaches saves and scripts.
    for (final (i, r) in rows.indexed) {
      expect(r.legacyIndex, i, reason: r.ref.value);
    }
  });

  test('only a two-handed weapon claims two hands', () {
    for (final d in catalog.all) {
      if (d.isTwoHanded) expect(d.kind.isWeapon, isTrue, reason: d.ref.value);
    }
    expect(catalog[const ItemRef('weapon.long_sword')]!.isTwoHanded, isTrue);
    expect(catalog[const ItemRef('weapon.dagger')]!.isTwoHanded, isFalse);
  });

  test('only a class amulet is restricted to a class', () {
    for (final d in catalog.all) {
      if (d.kind == ItemKind.classAmulet) {
        expect(d.classMask.isAny, isFalse, reason: d.ref.value);
      } else {
        // A common amulet carries no class mask at all. Not carrying one
        // is what "common" means.
        expect(d.classMask.isAny, isTrue, reason: d.ref.value);
      }
    }
  });

  test('a common amulet is worn by every class', () {
    final ward = catalog[const ItemRef('commonAmulet.ward')]!;
    for (final c in CharacterClass.values) {
      expect(ward.classMask.admits(c), isTrue, reason: c.name);
    }
  });

  test('a caster seal admits every caster and nobody else', () {
    final seal = catalog[const ItemRef('classAmulet.casting_seal')]!;
    for (final c in CharacterClass.values) {
      expect(
        seal.classMask.admits(c),
        classTypeOf(c) == ClassType.caster,
        reason: c.name,
      );
    }
  });

  test('the three that open ground grant a party-wide capability', () {
    for (final ref in const [
      'commonAmulet.water',
      'commonAmulet.marsh',
      'commonAmulet.levitation',
    ]) {
      final def = catalog[ItemRef(ref)]!;
      expect(def.kind, ItemKind.commonAmulet, reason: ref);
      expect(def.grants.length, 1, reason: ref);
      expect(def.grants.single.isPartyWide, isTrue, reason: ref);
    }
  });

  test('a torch goes in a hand and nothing else does but weapons and shields', () {
    final torch = catalog[const ItemRef('light.torch')]!;
    expect(torch.allowedSlots, {EquipSlot.leftHand});
    expect(torch.grants, {Capability.carryLight});
    expect(Capability.carryLight.stacksAcrossMembers, isTrue);
  });

  test('a shield turns its defence into a block chance as well', () {
    final shield = catalog[const ItemRef('shield.large_steel')]!;
    final byStat = {
      for (final m in shield.modifiers) m.stat: m.value,
    };
    expect(byStat[StatKey.defence], 3);
    expect(byStat[StatKey.shieldBlock], 15);
  });

  test('the three riders the original shipped are kept verbatim', () {
    final annexed = {
      for (final d in catalog.all)
        if (d.annexKey.isNotEmpty) d.ref.value: d.annexKey,
    };
    expect(annexed, {
      'helmet.hood': 'annex.att1_ac-1_str1',
      'boots.cloth_shoes': 'annex.int-2',
      'commonAmulet.dandy_belt': 'annex.str100',
    });
  });

  test('a catalogue can be extended and replaced without touching a rule', () {
    // The extensibility claim: a new amulet is a row.
    final extended = catalog.extend([
      ItemDef(
        ref: const ItemRef('commonAmulet.test'),
        nameKey: 'item.commonAmulet.test',
        kind: ItemKind.commonAmulet,
        modifiers: const [Modifier.percent(StatKey.defence, 50)],
      ),
    ]);
    expect(extended.length, catalog.length + 1);
    expect(catalog.contains(const ItemRef('commonAmulet.test')), isFalse);
    expect(extended[const ItemRef('commonAmulet.test')], isNotNull);
  });
}
