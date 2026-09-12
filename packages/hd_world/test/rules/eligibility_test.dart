import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

ItemDef def(String ref) => ItemCatalog.builtIn[ItemRef(ref)]!;

Member who({
  CharacterClass clazz = CharacterClass.knight,
  Map<EquipSlot, String> wearing = const {},
}) => Member(
  ref: const MemberRef('m'),
  name: 'm',
  clazz: clazz,
  equipment: {for (final e in wearing.entries) e.key: ItemRef(e.value)},
);

RefusalReason? check(Member m, EquipSlot slot, String item) => checkEquip(
  member: m,
  slot: slot,
  item: def(item),
  catalog: ItemCatalog.builtIn,
);

void main() {
  test('the right kind in the right slot is allowed', () {
    expect(check(who(), EquipSlot.rightHand, 'weapon.sabre'), isNull);
    expect(check(who(), EquipSlot.body, 'bodyArmour.bronze'), isNull);
    expect(check(who(), EquipSlot.commonAmulet, 'commonAmulet.ward'), isNull);
  });

  test('a shield does not go in the main hand', () {
    expect(
      check(who(), EquipSlot.rightHand, 'shield.leather'),
      RefusalReason.wrongSlot,
    );
    expect(
      check(who(), EquipSlot.head, 'bodyArmour.bronze'),
      RefusalReason.wrongSlot,
    );
  });

  test('a one-handed weapon goes in either hand', () {
    // The single change that admits dual wielding: the kind answers with
    // a set of slots, not one.
    expect(def('weapon.sabre').allowedSlots, {
      EquipSlot.rightHand,
      EquipSlot.leftHand,
    });
  });

  test('a class amulet refuses the wrong class, and says so distinctly', () {
    final knight = who();
    final mage = who(clazz: CharacterClass.magician);
    expect(
      check(knight, EquipSlot.classAmulet1, 'classAmulet.oath_crest'),
      isNull,
    );
    expect(
      check(mage, EquipSlot.classAmulet1, 'classAmulet.oath_crest'),
      RefusalReason.wrongClass,
    );
    // Wrong place and wrong class are different sentences.
    expect(
      check(knight, EquipSlot.commonAmulet, 'classAmulet.oath_crest'),
      RefusalReason.wrongSlot,
    );
  });

  test('the same class amulet does not go in both slots', () {
    final m = who(
      wearing: {EquipSlot.classAmulet2: 'classAmulet.oath_crest'},
    );
    expect(
      check(m, EquipSlot.classAmulet1, 'classAmulet.oath_crest'),
      RefusalReason.duplicateAmulet,
    );
  });

  test('a two-handed weapon shuts the off hand', () {
    final m = who(wearing: {EquipSlot.rightHand: 'weapon.long_sword'});
    expect(isOffHandLocked(m, ItemCatalog.builtIn), isTrue);
    expect(
      check(m, EquipSlot.leftHand, 'shield.leather'),
      RefusalReason.offHandLocked,
    );
    expect(
      check(m, EquipSlot.leftHand, 'light.torch'),
      RefusalReason.offHandLocked,
    );
  });

  test('a two-handed weapon never goes in the off hand', () {
    final m = who(wearing: {EquipSlot.rightHand: 'weapon.sabre'});
    expect(
      check(m, EquipSlot.leftHand, 'weapon.long_sword'),
      RefusalReason.twoHandedInOffHand,
    );
  });

  test('an off-hand weapon needs a main hand of the same class', () {
    expect(
      check(who(), EquipSlot.leftHand, 'weapon.dagger'),
      RefusalReason.noMainHandToPairWith,
    );
    final blade = who(wearing: {EquipSlot.rightHand: 'weapon.sabre'});
    expect(check(blade, EquipSlot.leftHand, 'weapon.dagger'), isNull);
    expect(
      check(blade, EquipSlot.leftHand, 'weapon.hand_axe'),
      RefusalReason.mismatchedPair,
    );
  });

  test('a shield and a torch are fine beside a one-handed weapon', () {
    final m = who(wearing: {EquipSlot.rightHand: 'weapon.sabre'});
    expect(check(m, EquipSlot.leftHand, 'shield.leather'), isNull);
    expect(check(m, EquipSlot.leftHand, 'light.torch'), isNull);
  });

  test('the offered list is exactly what would be accepted', () {
    // One filter, so a screen and a command can never disagree.
    final m = who(wearing: {EquipSlot.rightHand: 'weapon.sabre'});
    final carried = [
      for (final ref in const [
        'weapon.dagger',
        'weapon.hand_axe',
        'weapon.long_sword',
        'shield.leather',
        'light.torch',
        'bodyArmour.bronze',
        'classAmulet.casting_seal',
      ])
        ItemRef(ref),
    ];
    final offered = candidatesFor(
      member: m,
      slot: EquipSlot.leftHand,
      carried: carried,
      catalog: ItemCatalog.builtIn,
    );
    expect(offered.map((r) => r.value), [
      'weapon.dagger',
      'shield.leather',
      'light.torch',
    ]);
    for (final ref in carried) {
      final accepted = check(m, EquipSlot.leftHand, ref.value) == null;
      expect(offered.contains(ref), accepted, reason: ref.value);
    }
  });
}
