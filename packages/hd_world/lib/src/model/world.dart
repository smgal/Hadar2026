import '../contract/views.dart';
import '../contract/world_command.dart';
import '../contract/world_event.dart';
import '../data/item_catalog.dart';
import '../domain/equip_slot.dart';
import '../domain/fighting_style.dart';
import '../domain/ids.dart';
import '../domain/member.dart';
import '../domain/pack.dart';
import '../rules/eligibility.dart';
import '../rules/party_capability.dart';
import '../rules/refusal.dart';

/// The party, its pack, and the one door through which either changes.
///
/// ## Everything a caller can do is a command
///
/// [apply] is the only mutating method. It never throws, always returns
/// at least one event, and reports a rejection as [CommandRefused]
/// rather than as an exception or a bare false. So the same call shape
/// serves a terminal, a browser, a test and a replay log.
///
/// ## Nothing derived is stored
///
/// The fighting style, the final defence number, what the party can
/// walk on, how far it sees — all of it is computed on read from the
/// members plus the catalogue. There is no cache and therefore no
/// invalidation.
class World {
  World({
    required List<Member> members,
    Pack? pack,
    ItemCatalog? catalog,
    this.magicLight = false,
  }) : _members = [...members],
       pack = pack ?? Pack(),
       catalog = catalog ?? ItemCatalog.builtIn;

  final List<Member> _members;
  final Pack pack;
  final ItemCatalog catalog;

  /// Whether a spell is currently lighting the way. Set from outside —
  /// spell durations are not this package's business.
  bool magicLight;

  List<Member> get members => List.unmodifiable(_members);

  Member? memberAt(MemberRef ref) {
    for (final m in _members) {
      if (m.ref == ref) return m;
    }
    return null;
  }

  /// Everything a screen needs, resolved.
  WorldView get view {
    final abilities = readAbilities(
      members: _members,
      catalog: catalog,
      magicLight: magicLight,
    );
    return WorldView(
      members: [for (final m in _members) MemberView.of(m, catalog)],
      pack: pack.counts,
      abilities: abilities,
      light: lightInDarkness(abilities),
    );
  }

  /// What could go into that slot for that member, right now.
  List<ItemRef> candidates(MemberRef ref, EquipSlot slot) {
    final m = memberAt(ref);
    if (m == null) return const [];
    return candidatesFor(
      member: m,
      slot: slot,
      carried: pack.refs.toList(),
      catalog: catalog,
    );
  }

  /// The one door.
  List<WorldEvent> apply(WorldCommand command) => switch (command) {
    EquipFromPack() => _equip(command),
    UnequipToPack() => _unequip(command),
    SwapHands() => _swapHands(command),
    SetStyle() => _setStyle(command),
    GiveItem() => _give(command),
    TakeItem() => _take(command),
    ReorderParty() => _reorder(command),
  };

  // --- equipping ----------------------------------------------------

  List<WorldEvent> _equip(EquipFromPack c) {
    final m = memberAt(c.member);
    if (m == null) {
      return [
        CommandRefused(reason: RefusalReason.noSuchMember, member: c.member),
      ];
    }
    final def = catalog[c.item];
    if (def == null) {
      return [CommandRefused(reason: RefusalReason.noSuchItem, item: c.item)];
    }
    if (!pack.has(c.item)) {
      return [
        CommandRefused(
          reason: RefusalReason.notCarried,
          member: c.member,
          slot: c.slot,
          item: c.item,
        ),
      ];
    }
    final refusal = checkEquip(
      member: m,
      slot: c.slot,
      item: def,
      catalog: catalog,
    );
    if (refusal != null) {
      return [
        CommandRefused(
          reason: refusal,
          member: c.member,
          slot: c.slot,
          item: c.item,
        ),
      ];
    }

    // What has to come off, in the order a reader would expect.
    final displaced = <({EquipSlot slot, ItemRef ref})>[];
    if (c.slot == EquipSlot.rightHand && def.isTwoHanded) {
      final off = m.at(EquipSlot.leftHand);
      if (off != null) displaced.add((slot: EquipSlot.leftHand, ref: off));
    }
    final occupant = m.at(c.slot);
    if (occupant != null) displaced.add((slot: c.slot, ref: occupant));

    if (!_hasRoomFor(taking: c.item, returning: displaced.map((d) => d.ref))) {
      return [
        CommandRefused(
          reason: RefusalReason.packFull,
          member: c.member,
          slot: c.slot,
          item: c.item,
        ),
      ];
    }

    final events = <WorldEvent>[];
    pack.remove(c.item);
    for (final d in displaced) {
      m.equipment.remove(d.slot);
      final returned = catalog[d.ref];
      // Bare hands are not put in the pack; they are not an object the
      // party carries around.
      if (returned == null || returned.removable) pack.add(d.ref);
      events.add(
        d.slot == EquipSlot.leftHand && d.slot != c.slot
            ? OffHandCleared(member: c.member, item: d.ref)
            : ItemUnequipped(member: c.member, slot: d.slot, item: d.ref),
      );
    }
    m.equipment[c.slot] = c.item;
    events.add(ItemEquipped(member: c.member, slot: c.slot, item: c.item));
    return events;
  }

  List<WorldEvent> _unequip(UnequipToPack c) {
    final m = memberAt(c.member);
    if (m == null) {
      return [
        CommandRefused(reason: RefusalReason.noSuchMember, member: c.member),
      ];
    }
    final ref = m.at(c.slot);
    if (ref == null) {
      return [
        CommandRefused(
          reason: RefusalReason.slotEmpty,
          member: c.member,
          slot: c.slot,
        ),
      ];
    }
    final def = catalog[ref];
    if (def != null && !def.removable) {
      return [
        CommandRefused(
          reason: RefusalReason.cannotRemoveBareHands,
          member: c.member,
          slot: c.slot,
          item: ref,
        ),
      ];
    }
    if (!_hasRoomFor(taking: null, returning: [ref])) {
      return [
        CommandRefused(
          reason: RefusalReason.packFull,
          member: c.member,
          slot: c.slot,
          item: ref,
        ),
      ];
    }
    m.equipment.remove(c.slot);
    pack.add(ref);
    return [ItemUnequipped(member: c.member, slot: c.slot, item: ref)];
  }

  List<WorldEvent> _swapHands(SwapHands c) {
    final m = memberAt(c.member);
    if (m == null) {
      return [
        CommandRefused(reason: RefusalReason.noSuchMember, member: c.member),
      ];
    }
    final right = m.at(EquipSlot.rightHand);
    final left = m.at(EquipSlot.leftHand);
    if (right == null && left == null) {
      return [
        CommandRefused(
          reason: RefusalReason.slotEmpty,
          member: c.member,
          slot: EquipSlot.rightHand,
        ),
      ];
    }
    // Validate the arrangement it would produce rather than reasoning
    // about the swap, so the answer can never disagree with `checkEquip`.
    final probe = Member(
      ref: m.ref,
      name: m.name,
      clazz: m.clazz,
      equipment: {
        for (final slot in EquipSlot.values)
          if (slot != EquipSlot.rightHand && slot != EquipSlot.leftHand)
            if (m.at(slot) != null) slot: m.at(slot)!,
        if (left != null) EquipSlot.rightHand: left,
      },
    );
    for (final (slot, ref) in [
      (EquipSlot.rightHand, left),
      (EquipSlot.leftHand, right),
    ]) {
      if (ref == null) continue;
      final def = catalog[ref];
      if (def == null) {
        return [CommandRefused(reason: RefusalReason.noSuchItem, item: ref)];
      }
      final refusal = checkEquip(
        member: probe,
        slot: slot,
        item: def,
        catalog: catalog,
      );
      if (refusal != null) {
        return [
          CommandRefused(
            reason: refusal,
            member: c.member,
            slot: slot,
            item: ref,
          ),
        ];
      }
    }
    m.equipment.remove(EquipSlot.rightHand);
    m.equipment.remove(EquipSlot.leftHand);
    if (left != null) m.equipment[EquipSlot.rightHand] = left;
    if (right != null) m.equipment[EquipSlot.leftHand] = right;
    return [HandsSwapped(member: c.member)];
  }

  // --- the rest -----------------------------------------------------

  List<WorldEvent> _setStyle(SetStyle c) {
    final m = memberAt(c.member);
    if (m == null) {
      return [
        CommandRefused(reason: RefusalReason.noSuchMember, member: c.member),
      ];
    }
    m.style = c.style;
    if (c.thrift != null) m.thrift = c.thrift!;
    return [
      StyleSet(member: c.member, style: m.style, thrift: m.thrift),
    ];
  }

  List<WorldEvent> _give(GiveItem c) {
    if (!catalog.contains(c.item)) {
      return [CommandRefused(reason: RefusalReason.noSuchItem, item: c.item)];
    }
    if (!pack.add(c.item, c.count)) {
      return [CommandRefused(reason: RefusalReason.packFull, item: c.item)];
    }
    return [ItemGained(item: c.item, count: c.count)];
  }

  List<WorldEvent> _take(TakeItem c) {
    if (!pack.remove(c.item, c.count)) {
      return [CommandRefused(reason: RefusalReason.notCarried, item: c.item)];
    }
    return [ItemLost(item: c.item, count: c.count)];
  }

  List<WorldEvent> _reorder(ReorderParty c) {
    final wanted = <Member>[];
    for (final ref in c.order) {
      final m = memberAt(ref);
      if (m == null) {
        return [CommandRefused(reason: RefusalReason.noSuchMember, member: ref)];
      }
      if (!wanted.contains(m)) wanted.add(m);
    }
    for (final m in _members) {
      if (!wanted.contains(m)) wanted.add(m);
    }
    _members
      ..clear()
      ..addAll(wanted);
    return [PartyReordered(order: [for (final m in _members) m.ref])];
  }

  /// Whether the pack can take [returning] once [taking] has left it.
  ///
  /// Capacity counts distinct kinds, so removing the last of a stack
  /// frees a place and adding to an existing stack needs none.
  bool _hasRoomFor({
    required ItemRef? taking,
    required Iterable<ItemRef> returning,
  }) {
    var kinds = pack.kindCount;
    if (taking != null && pack.countOf(taking) == 1) kinds--;
    final incoming = <ItemRef>{};
    for (final ref in returning) {
      final def = catalog[ref];
      if (def != null && !def.removable) continue;
      if (pack.countOf(ref) > 0 && ref != taking) continue;
      if (ref == taking && pack.countOf(ref) > 1) continue;
      incoming.add(ref);
    }
    return kinds + incoming.length <= pack.capacity;
  }
}

/// Whether that class may be put on that posture.
bool styleAllowed(Member member, FightingStyle style) =>
    MemberView.of(member, ItemCatalog.builtIn).allowedStyles.contains(style);
