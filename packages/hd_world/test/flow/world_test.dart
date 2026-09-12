import 'package:hd_world/hd_world.dart';
import 'package:test/test.dart';

World build({int capacity = 40, Map<String, int> pack = const {}}) => World(
  members: [for (final t in sampleParty) t.build()],
  pack: Pack(
    capacity: capacity,
    counts: {for (final e in pack.entries) ItemRef(e.key): e.value},
  ),
);

const knight = MemberRef('knight');
const mage = MemberRef('magician');

T only<T extends WorldEvent>(List<WorldEvent> events) {
  expect(events.length, 1, reason: '$events');
  return events.single as T;
}

void main() {
  test('the sample party is five, and every template resolves', () {
    final world = build();
    expect(world.members.length, 5);
    for (final view in world.view.members) {
      expect(view.stats.weaponKind, isNot(WeaponKind.unarmed),
          reason: view.member.ref.value);
    }
  });

  test('a command that works reports what changed', () {
    final world = build(pack: {'weapon.dagger': 1});
    final events = world.apply(
      const EquipFromPack(
        member: knight,
        slot: EquipSlot.leftHand,
        item: ItemRef('weapon.dagger'),
      ),
    );
    // The shield it displaces comes off first, then the dagger goes on.
    expect(events.length, 2);
    expect(events.first, isA<ItemUnequipped>());
    expect((events.first as ItemUnequipped).item.value, 'shield.small_steel');
    expect(events.last, isA<ItemEquipped>());
    expect(world.pack.has(const ItemRef('shield.small_steel')), isTrue);
    expect(world.pack.has(const ItemRef('weapon.dagger')), isFalse);
    final view = MemberView.of(world.memberAt(knight)!, world.catalog);
    expect(view.stats.weaponKind, WeaponKind.dualWield);
  });

  test('apply never throws and always answers', () {
    final world = build();
    final refused = world.apply(
      const EquipFromPack(
        member: MemberRef('nobody'),
        slot: EquipSlot.head,
        item: ItemRef('helmet.hood'),
      ),
    );
    expect(only<CommandRefused>(refused).reason, RefusalReason.noSuchMember);
    expect(
      only<CommandRefused>(
        world.apply(
          const EquipFromPack(
            member: knight,
            slot: EquipSlot.head,
            item: ItemRef('helmet.nonesuch'),
          ),
        ),
      ).reason,
      RefusalReason.noSuchItem,
    );
    expect(
      only<CommandRefused>(
        world.apply(
          const EquipFromPack(
            member: knight,
            slot: EquipSlot.head,
            item: ItemRef('helmet.hood'),
          ),
        ),
      ).reason,
      RefusalReason.notCarried,
    );
  });

  test('a refusal changes nothing', () {
    final world = build(pack: {'classAmulet.oath_crest': 1});
    final before = world.memberAt(mage)!.equipment.length;
    final events = world.apply(
      const EquipFromPack(
        member: mage,
        slot: EquipSlot.classAmulet1,
        item: ItemRef('classAmulet.oath_crest'),
      ),
    );
    expect(only<CommandRefused>(events).reason, RefusalReason.wrongClass);
    expect(world.memberAt(mage)!.equipment.length, before);
    expect(world.pack.countOf(const ItemRef('classAmulet.oath_crest')), 1);
  });

  test('a two-handed weapon clears the off hand and says it did', () {
    final world = build(pack: {'weapon.long_sword': 1});
    final events = world.apply(
      const EquipFromPack(
        member: knight,
        slot: EquipSlot.rightHand,
        item: ItemRef('weapon.long_sword'),
      ),
    );
    expect(events.whereType<OffHandCleared>().length, 1);
    expect(
      (events.whereType<OffHandCleared>().single).item.value,
      'shield.small_steel',
    );
    final m = world.memberAt(knight)!;
    expect(m.at(EquipSlot.leftHand), isNull);
    expect(world.pack.has(const ItemRef('shield.small_steel')), isTrue);
    expect(
      MemberView.of(m, world.catalog).stats.weaponKind,
      WeaponKind.greatSword,
    );
  });

  test('the off-hand slot reports itself shut', () {
    final world = build(pack: {'weapon.long_sword': 1});
    world.apply(
      const EquipFromPack(
        member: knight,
        slot: EquipSlot.rightHand,
        item: ItemRef('weapon.long_sword'),
      ),
    );
    final view = MemberView.of(world.memberAt(knight)!, world.catalog);
    final left = view.slots.firstWhere((s) => s.slot == EquipSlot.leftHand);
    expect(left.locked, isTrue);
    expect(view.stats.offHandLocked, isTrue);
  });

  test('bare hands cannot be taken off', () {
    final world = World(
      members: [
        Member(
          ref: const MemberRef('m'),
          name: 'm',
          equipment: const {EquipSlot.rightHand: ItemRef('weapon.fist_cut')},
        ),
      ],
    );
    expect(
      only<CommandRefused>(
        world.apply(
          const UnequipToPack(
            member: MemberRef('m'),
            slot: EquipSlot.rightHand,
          ),
        ),
      ).reason,
      RefusalReason.cannotRemoveBareHands,
    );
  });

  test('an empty slot says so rather than pretending', () {
    final world = build();
    expect(
      only<CommandRefused>(
        world.apply(
          const UnequipToPack(member: knight, slot: EquipSlot.classAmulet2),
        ),
      ).reason,
      RefusalReason.slotEmpty,
    );
  });

  test('a full pack refuses rather than dropping the item on the floor', () {
    // Capacity counts distinct kinds, so this pack is exactly full.
    final world = build(
      capacity: 1,
      pack: {'weapon.dagger': 1},
    );
    final events = world.apply(
      const UnequipToPack(member: knight, slot: EquipSlot.body),
    );
    expect(only<CommandRefused>(events).reason, RefusalReason.packFull);
    expect(world.memberAt(knight)!.at(EquipSlot.body), isNotNull);
  });

  test('a swap into a full pack still works, because a place is freed', () {
    final world = build(capacity: 1, pack: {'bodyArmour.steel': 1});
    final events = world.apply(
      const EquipFromPack(
        member: knight,
        slot: EquipSlot.body,
        item: ItemRef('bodyArmour.steel'),
      ),
    );
    expect(events.whereType<CommandRefused>(), isEmpty, reason: '$events');
    expect(world.pack.countOf(const ItemRef('bodyArmour.bronze')), 1);
    expect(world.pack.kindCount, 1);
  });

  test('the hands can be traded when both hold a matching pair', () {
    final world = build(pack: {'weapon.dagger': 1});
    world.apply(
      const EquipFromPack(
        member: knight,
        slot: EquipSlot.leftHand,
        item: ItemRef('weapon.dagger'),
      ),
    );
    expect(
      world.apply(const SwapHands(member: knight)),
      [isA<HandsSwapped>()],
    );
    final m = world.memberAt(knight)!;
    expect(m.at(EquipSlot.rightHand)!.value, 'weapon.dagger');
    expect(m.at(EquipSlot.leftHand)!.value, 'weapon.sabre');
  });

  test('a lone weapon cannot be moved to the off hand by trading', () {
    final world = build();
    final events = world.apply(const SwapHands(member: MemberRef('swordman')));
    expect(
      only<CommandRefused>(events).reason,
      RefusalReason.twoHandedInOffHand,
    );
  });

  test('a style can only be one the class is allowed', () {
    final world = build();
    final events = world.apply(
      const SetStyle(member: knight, style: FightingStyle.bulwark, thrift: true),
    );
    final set = only<StyleSet>(events);
    expect(set.style, FightingStyle.bulwark);
    expect(set.thrift, isTrue);
    expect(styleAllowed(world.memberAt(knight)!, FightingStyle.bulwark), isTrue);
    expect(styleAllowed(world.memberAt(knight)!, FightingStyle.mend), isFalse);
  });

  test('giving and taking report the count', () {
    final world = build();
    expect(
      only<ItemGained>(
        world.apply(const GiveItem(item: ItemRef('light.torch'), count: 3)),
      ).count,
      3,
    );
    expect(world.pack.countOf(const ItemRef('light.torch')), 3);
    expect(
      only<ItemLost>(
        world.apply(const TakeItem(item: ItemRef('light.torch'), count: 2)),
      ).count,
      2,
    );
    expect(world.pack.countOf(const ItemRef('light.torch')), 1);
    expect(
      only<CommandRefused>(
        world.apply(const TakeItem(item: ItemRef('light.torch'), count: 5)),
      ).reason,
      RefusalReason.notCarried,
    );
    expect(world.pack.countOf(const ItemRef('light.torch')), 1);
  });

  test('reordering keeps everyone and puts the named ones first', () {
    final world = build();
    final events = world.apply(
      const ReorderParty(order: [mage, knight]),
    );
    expect(only<PartyReordered>(events).order.first, mage);
    expect(world.members.length, 5);
    expect(world.members.first.ref, mage);
    expect(world.members[1].ref, knight);
  });

  test('the sample pack fits in a sample pack', () {
    // Over-filling it would make every displacement fail as packFull,
    // which looks like a rule bug and is not one.
    expect(samplePack.length, lessThanOrEqualTo(40));
  });

  test('the offered list and the command agree, for every slot', () {
    // The property that keeps a screen honest.
    final world = build(
      pack: {
        for (final e in samplePack.entries) e.key: e.value,
      },
    );
    for (final m in world.members) {
      for (final slot in EquipSlot.values) {
        for (final ref in world.pack.refs.toList()) {
          final offered = world.candidates(m.ref, slot).contains(ref);
          final probe = World(
            members: [for (final t in sampleParty) t.build()],
            pack: Pack(capacity: 40, counts: {ref: 1}),
          );
          final events = probe.apply(
            EquipFromPack(member: m.ref, slot: slot, item: ref),
          );
          final accepted = events.whereType<CommandRefused>().isEmpty;
          expect(
            offered,
            accepted,
            reason: '${m.ref.value} ${slot.name} ${ref.value}',
          );
        }
      }
    }
  });

  test('the whole party view serialises without a null hole', () {
    final world = build(pack: {'light.torch': 2});
    final json = world.view.toJson();
    expect((json['members'] as List).length, 5);
    expect(json['party'], isA<Map<String, Object?>>());
    final party = json['party'] as Map<String, Object?>;
    expect(party['sightInDarkness'], 1);
    expect(party['lightBearers'], 0);
  });

  test('two torches change what the party can see', () {
    final world = build(pack: {'light.torch': 2});
    for (final who in const [MemberRef('knight'), MemberRef('hunter')]) {
      // The hunter holds a bow, which is two-handed, so only the knight
      // can take one — and the knight has to drop the shield.
      world.apply(
        EquipFromPack(
          member: who,
          slot: EquipSlot.leftHand,
          item: const ItemRef('light.torch'),
        ),
      );
    }
    final party = world.view.toJson()['party'] as Map<String, Object?>;
    expect(party['lightBearers'], 1);
    expect(party['sightInDarkness'], 3);
  });

  test('an amulet on one member opens ground for everyone', () {
    final world = build(pack: {'commonAmulet.water': 1});
    world.apply(
      const EquipFromPack(
        member: mage,
        slot: EquipSlot.commonAmulet,
        item: ItemRef('commonAmulet.water'),
      ),
    );
    final party = world.view.toJson()['party'] as Map<String, Object?>;
    expect(party['capabilities'], contains('walkOnWater'));
  });
}
