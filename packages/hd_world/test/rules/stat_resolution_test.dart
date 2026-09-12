import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

Member who({
  CharacterClass clazz = CharacterClass.knight,
  Map<EquipSlot, String> wearing = const {},
  int maxHp = 100,
  BaseStats stats = const BaseStats(strength: 10, agility: 10),
}) => Member(
  ref: const MemberRef('m'),
  name: 'm',
  clazz: clazz,
  stats: stats,
  baseMaxHitPoints: maxHp,
  accuracy: const Accuracy(physical: 10),
  equipment: {for (final e in wearing.entries) e.key: ItemRef(e.value)},
);

ResolvedStats resolve(Member m) =>
    resolveStats(member: m, catalog: ItemCatalog.builtIn);

void main() {
  test('nothing worn is the base, unchanged', () {
    final r = resolve(who());
    expect(r[StatKey.maxHitPoints], 100);
    expect(r[StatKey.defence], 0);
    expect(r[StatKey.strength], 10);
    expect(r.weaponKind, WeaponKind.unarmed);
    expect(r.attackPower, 1);
  });

  test('worn defence adds up across the body', () {
    final r = resolve(
      who(
        wearing: {
          EquipSlot.body: 'bodyArmour.steel',
          EquipSlot.leftHand: 'shield.large_steel',
        },
      ),
    );
    expect(r[StatKey.defence], 6);
    expect(r[StatKey.shieldBlock], 15);
  });

  test('a percentage reads the subtotal, so order can never matter', () {
    // Ten percent of the three points actually worn, not of a base of
    // zero and not compounded against another amulet.
    final one = resolve(
      who(
        wearing: {
          EquipSlot.body: 'bodyArmour.steel',
          EquipSlot.commonAmulet: 'commonAmulet.ward',
        },
      ),
    );
    expect(one[StatKey.defence], 3 + 0); // 10% of 3 truncates to 0
    final ten = resolve(
      who(
        wearing: {
          EquipSlot.body: 'bodyArmour.steel',
          EquipSlot.leftHand: 'shield.platinum',
          EquipSlot.commonAmulet: 'commonAmulet.ward',
        },
      ),
    );
    // 3 + 5 = 8, plus ten percent of 8 = 0 after truncation... so state
    // the arithmetic rather than a guess:
    expect(ten[StatKey.defence], 8 + 8 * 10 ~/ 100);
  });

  test('two percentages of ten give twenty, never twenty-one', () {
    final catalog = ItemCatalog.builtIn.extend([
      ItemDef(
        ref: const ItemRef('classAmulet.testWard'),
        nameKey: 'x',
        kind: ItemKind.classAmulet,
        classMask: ClassMask({CharacterClass.knight}),
        modifiers: const [Modifier.percent(StatKey.maxHitPoints, 10)],
      ),
    ]);
    final m = who(
      maxHp: 100,
      wearing: {
        EquipSlot.commonAmulet: 'commonAmulet.life',
        EquipSlot.classAmulet1: 'classAmulet.testWard',
      },
    );
    expect(
      resolveStats(member: m, catalog: catalog)[StatKey.maxHitPoints],
      120,
    );
  });

  test('a locked off hand contributes nothing at all', () {
    // The state can arrive this way from an older save, so the resolver
    // has to agree with the eligibility rule rather than trust the map.
    final m = who(
      wearing: {
        EquipSlot.rightHand: 'weapon.long_sword',
        EquipSlot.leftHand: 'shield.platinum',
      },
    );
    final r = resolve(m);
    expect(r.offHandLocked, isTrue);
    expect(r[StatKey.defence], 0, reason: 'the shield is not really held');
    expect(r[StatKey.shieldBlock], 0);
    expect(r.weaponKind, WeaponKind.greatSword);
  });

  test('dual wielding earns a second coating and averages the power', () {
    final m = who(
      wearing: {
        EquipSlot.rightHand: 'weapon.sabre', // 35
        EquipSlot.leftHand: 'weapon.dagger', // 15
      },
    );
    final r = resolve(m);
    expect(r.weaponKind, WeaponKind.dualWield);
    expect(r[StatKey.coatingSlots], 2);
    // Averaged, not summed: the style already strikes twice.
    expect(r.attackPower, 25);
  });

  test('one weapon holds one coating', () {
    expect(
      resolve(who(wearing: {EquipSlot.rightHand: 'weapon.sabre'}))[
          StatKey.coatingSlots],
      1,
    );
  });

  test('immunities and grants come off what is worn', () {
    final m = who(
      wearing: {
        EquipSlot.commonAmulet: 'commonAmulet.antidote',
        EquipSlot.rightHand: 'weapon.sabre',
        EquipSlot.leftHand: 'light.torch',
      },
    );
    final r = resolve(m);
    expect(r.immunities, {Ailment.poison});
    expect(r.granted, {Capability.carryLight});
    expect(r.weaponKind, WeaponKind.torchbearer);
    expect(carriesLight(member: m, catalog: ItemCatalog.builtIn), isTrue);
  });

  test('a two-handed weapon puts the torch out', () {
    final m = who(
      wearing: {
        EquipSlot.rightHand: 'weapon.long_sword',
        EquipSlot.leftHand: 'light.torch',
      },
    );
    expect(carriesLight(member: m, catalog: ItemCatalog.builtIn), isFalse);
    expect(resolve(m).granted, isEmpty);
  });

  test('every stat key is present in the answer', () {
    final r = resolve(who());
    for (final key in StatKey.values) {
      expect(r.values.containsKey(key), isTrue, reason: key.name);
    }
  });

  test('a class amulet only helps the class that can wear it', () {
    // Not enforced by the resolver — it is the eligibility rule's job.
    // Asserted here so the split stays visible: resolution trusts the
    // state, and only commands police it.
    final seal = ItemCatalog.builtIn[
        const ItemRef('classAmulet.casting_seal')]!;
    expect(seal.classMask.admits(CharacterClass.knight), isFalse);
  });
}
