import '../domain/equip_slot.dart';
import '../domain/fighting_style.dart';
import '../domain/ids.dart';

/// Something asked of the world.
///
/// ## One door in
///
/// Every change goes through `World.apply`. Nothing outside this
/// package writes a field. That single rule is what makes the HTTP
/// surface, the tests and an undo stack all fall out of the same
/// mechanism: a command is a value, so it can be sent, logged, replayed
/// and asserted on.
///
/// The battle package earned this the same way — inverted control is
/// why a fight can be driven from a terminal, a Flutter screen or a
/// recorded script without the model knowing which.
sealed class WorldCommand {
  const WorldCommand();

  /// The wire name. Explicit, so renaming a Dart class is not an API
  /// change.
  String get kind;

  Map<String, Object?> toJson();
}

/// Take something out of the pack and put it on.
///
/// Displaces whatever was in the slot back into the pack. A two-handed
/// weapon also clears the off hand.
final class EquipFromPack extends WorldCommand {
  const EquipFromPack({
    required this.member,
    required this.slot,
    required this.item,
  });

  final MemberRef member;
  final EquipSlot slot;
  final ItemRef item;

  @override
  String get kind => 'equip';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'member': member.value,
    'slot': slot.name,
    'item': item.value,
  };
}

/// Take a slot off and put its contents in the pack.
final class UnequipToPack extends WorldCommand {
  const UnequipToPack({required this.member, required this.slot});

  final MemberRef member;
  final EquipSlot slot;

  @override
  String get kind => 'unequip';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'member': member.value,
    'slot': slot.name,
  };
}

/// Trade the two hands.
///
/// Its own command rather than two moves through the pack, because two
/// moves can fail halfway when the pack is full and leave a member
/// holding nothing.
final class SwapHands extends WorldCommand {
  const SwapHands({required this.member});

  final MemberRef member;

  @override
  String get kind => 'swapHands';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'member': member.value};
}

/// Put a member on a standing order.
final class SetStyle extends WorldCommand {
  const SetStyle({required this.member, required this.style, this.thrift});

  final MemberRef member;
  final FightingStyle style;

  /// Null leaves the toggle alone.
  final bool? thrift;

  @override
  String get kind => 'setStyle';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'member': member.value,
    'style': style.name,
    if (thrift != null) 'thrift': thrift,
  };
}

/// Put something in the pack.
final class GiveItem extends WorldCommand {
  const GiveItem({required this.item, this.count = 1});

  final ItemRef item;
  final int count;

  @override
  String get kind => 'give';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'item': item.value,
    'count': count,
  };
}

/// Take something out of the pack.
final class TakeItem extends WorldCommand {
  const TakeItem({required this.item, this.count = 1});

  final ItemRef item;
  final int count;

  @override
  String get kind => 'take';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'item': item.value,
    'count': count,
  };
}

/// Put the party in this order. Missing members keep their places at
/// the back.
final class ReorderParty extends WorldCommand {
  const ReorderParty({required this.order});

  final List<MemberRef> order;

  @override
  String get kind => 'reorder';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'order': [for (final m in order) m.value],
  };
}
