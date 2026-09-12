import 'package:hd_world/hd_world.dart';
import 'package:hd_world_legacy/hd_world_legacy.dart';
import 'package:test/test.dart';

final catalog = ItemCatalog.builtIn;

Member who() => Member(
  ref: const MemberRef('m'),
  name: 'somebody',
  clazz: CharacterClass.knight,
  stats: const BaseStats(strength: 10, agility: 10),
  baseMaxHitPoints: 100,
  accuracy: const Accuracy(physical: 10),
);

void main() {
  group('attribute writes', () {
    test('the ordinary ones land', () {
      final m = who();
      for (final (attribute, value) in const [
        ('hp', 42),
        ('strength', 18),
        ('agility', 7),
        ('level', 5),
        ('accuracy(magic)', 12),
      ]) {
        final r = writeAttribute(m, attribute, value);
        expect(r.verdict, AttributeVerdict.applied, reason: attribute);
      }
      expect(m.hitPoints, 42);
      expect(m.stats.strength, 18);
      expect(m.stats.agility, 7);
      expect(m.levels.physical, 5);
      expect(m.accuracy.magic, 12);
      // The other two accuracies were not disturbed.
      expect(m.accuracy.physical, 10);
    });

    test('a name is a string and a number is not a name', () {
      final m = who();
      expect(
        writeAttribute(m, 'name', 'Atria').verdict,
        AttributeVerdict.applied,
      );
      expect(m.name, 'Atria');
      expect(writeAttribute(m, 'name', 3).verdict, AttributeVerdict.unknown);
      expect(writeAttribute(m, 'hp', 'lots').verdict, AttributeVerdict.unknown);
    });

    test('a misspelled name is reported, never ignored', () {
      // The failure this whole package exists to prevent: the old
      // dispatch ended in a `default:` that did nothing and said
      // nothing.
      final r = writeAttribute(who(), 'strenght', 18);
      expect(r.verdict, AttributeVerdict.unknown);
      expect(r.changed, isFalse);
    });

    test('a derived value refuses and says what to do instead', () {
      for (final attribute in const ['ac', 'max_hp', 'pow_of_weapon']) {
        final r = writeAttribute(who(), attribute, 9);
        expect(r.verdict, AttributeVerdict.derived, reason: attribute);
        expect(r.detail, isNotEmpty, reason: attribute);
      }
    });

    test('the two fields nothing ever read are told apart from those', () {
      for (final attribute in const ['pow_of_shield', 'pow_of_armor']) {
        expect(
          writeAttribute(who(), attribute, 9).verdict,
          AttributeVerdict.dead,
          reason: attribute,
        );
      }
    });

      test('the conditions belong to the party, not to the fight', () {
      // Poison decays with rest and a dead member stays dead between
      // battles, so these are the world's to keep. The battle borrows
      // them and hands them back.
      final m = who();
      for (final (attribute, value) in const [
        ('poison', 2),
        ('unconscious', 1),
        ('dead', 1),
        ('experience', 1500),
      ]) {
        expect(
          writeAttribute(m, attribute, value).verdict,
          AttributeVerdict.applied,
          reason: attribute,
        );
        expect(readAttribute(m, attribute, catalog: catalog), value,
            reason: attribute);
      }
      expect(m.condition, MemberCondition.dead);
      expect(m.isConscious, isFalse);
    });

    test('a class comes in by number and a bad number is refused', () {
      final m = who();
      expect(writeAttribute(m, 'class', 8).verdict, AttributeVerdict.applied);
      expect(m.clazz, CharacterClass.esper);
      expect(
        writeAttribute(m, 'class', 99).verdict,
        AttributeVerdict.unknown,
      );
      expect(m.clazz, CharacterClass.esper, reason: 'and nothing changed');
    });

    test('equipment is a command, so it needs somewhere to send it', () {
      final m = who();
      expect(
        writeAttribute(m, 'weapon', 4).verdict,
        AttributeVerdict.unknown,
        reason: 'no equip callback was given',
      );
      final asked = <(EquipSlot, int)>[];
      final r = writeAttribute(
        m,
        'weapon',
        4,
        equip: (slot, index) {
          asked.add((slot, index));
          return true;
        },
      );
      expect(r.verdict, AttributeVerdict.applied);
      expect(asked, [(EquipSlot.rightHand, 4)]);
    });

    test('a refused slot is reported rather than swallowed', () {
      final r = writeAttribute(
        who(),
        'shield',
        3,
        equip: (_, __) => false,
      );
      expect(r.verdict, AttributeVerdict.dead);
      expect(r.detail, contains('refused'));
    });

    test('every name a shipped script writes is answerable', () {
      // Measured from the shipped scripts: these are the names that
      // actually appear.
      for (final attribute in const [
        'name',
        'weapon',
        'shield',
        'armor',
        'pow_of_weapon',
        'pow_of_shield',
        'pow_of_armor',
        'class',
        'ac',
        'level',
        'endurance',
        'accuracy',
      ]) {
        expect(knownAttributes, contains(attribute), reason: attribute);
        final r = writeAttribute(
          who(),
          attribute,
          attribute == 'name' ? 'x' : 1,
          equip: (_, __) => true,
        );
        expect(
          r.verdict,
          isNot(AttributeVerdict.unknown),
          reason: '$attribute must not be unknown',
        );
      }
    });
  });

  group('attribute reads', () {
    test('the resolved value comes back, not the stored one', () {
      final m = who()
        ..equipment[EquipSlot.body] = const ItemRef('bodyArmour.steel')
        ..equipment[EquipSlot.rightHand] = const ItemRef('weapon.long_sword');
      expect(readAttribute(m, 'ac', catalog: catalog), 3);
      expect(readAttribute(m, 'pow_of_weapon', catalog: catalog), 60);
    });

    test('a name this build does not know answers null, not zero', () {
      // Zero is what the old scripting layer returned for an unknown
      // symbol, and it mis-branched silently for years.
      expect(readAttribute(who(), 'strenght', catalog: catalog), isNull);
      expect(readAttribute(who(), 'hp', catalog: catalog), isNotNull);
    });

    test('a name is a string and the equipment integers come back', () {
      // cm2 reads all four, so all four have to answer.
      final m = who()
        ..name = 'Atria'
        ..equipment[EquipSlot.rightHand] = const ItemRef('weapon.long_sword')
        ..equipment[EquipSlot.body] = const ItemRef('bodyArmour.steel');
      expect(readAttribute(m, 'name', catalog: catalog), 'Atria');
      // The ten-name ladder, not the position among cutting weapons —
      // those are different spaces and only the ladder is what a script
      // means.
      expect(readAttribute(m, 'weapon', catalog: catalog), 4);
      expect(catalog[const ItemRef('weapon.long_sword')]!.legacyIndex, 6);
      expect(readAttribute(m, 'armor', catalog: catalog), 3);
      expect(readAttribute(m, 'shield', catalog: catalog), 0,
          reason: 'an empty slot is zero, as the original had it');
    });

    test('a slot holding something this build invented answers zero', () {
      // A new amulet has no number and never had one, so a script that
      // reads it must not get a position that means a different item.
      final m = who()
        ..equipment[EquipSlot.commonAmulet] =
            const ItemRef('commonAmulet.ward');
      expect(readAttribute(m, 'weapon', catalog: catalog), 0);
    });

    test('a real value that is always zero outside a fight is zero', () {
      for (final attribute in const ['poison', 'unconscious', 'dead']) {
        expect(readAttribute(who(), attribute, catalog: catalog), 0);
      }
    });
  });

  group('the packed integer a script passes', () {
    test('the layout is the previous model\'s, so the constants still work', () {
      // `assets/item4ep1.cm2` is generated with kind << 16 | index, and
      // no shipped script calls the item verbs yet — but the constants
      // exist and have to keep meaning what they say.
      expect(
        itemRefFromWire(0, catalog: catalog)!.value,
        'weapon.fist_cut',
      );
      expect(
        itemRefFromWire(ItemKind.bodyArmour.wire << 16 | 3, catalog: catalog)!
            .value,
        'bodyArmour.steel',
      );
      expect(
        itemRefFromWire(ItemKind.consumable.wire << 16 | 0, catalog: catalog)!
            .value,
        'consumable.potion',
      );
    });

    test('a number that names nothing answers null', () {
      expect(itemRefFromWire(-1, catalog: catalog), isNull);
      expect(itemRefFromWire(0xFF << 16, catalog: catalog), isNull);
      // detail was always zero; a number that sets it is not one of ours.
      expect(itemRefFromWire(1 << 8, catalog: catalog), isNull);
      // A kind that exists with an index that does not.
      expect(
        itemRefFromWire(ItemKind.shield.wire << 16 | 200, catalog: catalog),
        isNull,
      );
    });

    test('the round trip holds for everything numbered', () {
      for (final def in catalog.all) {
        if (def.legacyIndex < 0) continue;
        final wire = itemWireOf(def.ref, catalog: catalog);
        expect(wire, greaterThanOrEqualTo(0), reason: def.ref.value);
        expect(
          itemRefFromWire(wire, catalog: catalog),
          def.ref,
          reason: def.ref.value,
        );
      }
    });

    test('an item this build invented has no number', () {
      // The amulets are ours, so a script cannot name them and must not
      // be given a number that would collide with a ported row.
      expect(
        itemWireOf(const ItemRef('commonAmulet.ward'), catalog: catalog),
        -1,
      );
    });
  });

  group('legacy item numbers', () {
    test('the ten-weapon ladder still means what it meant', () {
      expect(legacyWeapon(0)!.value, 'weapon.fist_cut');
      expect(legacyWeapon(1)!.value, 'weapon.knife');
      expect(legacyWeapon(4)!.value, 'weapon.long_sword');
      expect(legacyWeapon(9)!.value, 'weapon.flamberge');
      expect(legacyWeaponLadder.length, 10);
      for (final ref in legacyWeaponLadder) {
        expect(catalog.contains(ItemRef(ref)), isTrue, reason: ref);
      }
    });

    test('a number that was never there answers null', () {
      expect(legacyWeapon(-1), isNull);
      expect(legacyWeapon(10), isNull);
      // Not bare hands. Answering slot zero is how a script could
      // accidentally unequip somebody.
      expect(legacyWeapon(99), isNull);
    });

    test('shields and armour keep the original 0..5', () {
      for (var i = 0; i <= 5; i++) {
        expect(legacyShield(i, catalog: catalog), isNotNull, reason: 'shield $i');
        expect(legacyArmour(i, catalog: catalog), isNotNull, reason: 'armour $i');
      }
      expect(legacyShield(6, catalog: catalog), isNull);
      expect(legacyArmour(6, catalog: catalog), isNull);
      expect(legacyArmour(3, catalog: catalog)!.value, 'bodyArmour.steel');
    });

    test('the round trip holds for everything that has a number', () {
      for (final def in catalog.all) {
        if (def.legacyIndex < 0) continue;
        final back = legacyIndexOf(def.ref, catalog: catalog);
        expect(back, def.legacyIndex, reason: def.ref.value);
      }
    });
  });
}
