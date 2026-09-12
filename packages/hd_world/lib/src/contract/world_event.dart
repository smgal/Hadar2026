import '../domain/equip_slot.dart';
import '../domain/fighting_style.dart';
import '../domain/ids.dart';
import '../rules/refusal.dart';

/// Something that happened, or a reason nothing did.
///
/// ## Refusals are events too
///
/// `apply` never throws and never returns empty. A rejected command
/// comes back as [CommandRefused] carrying a [RefusalReason], so the
/// caller gets the same shape whether it worked or not, and a screen
/// can say why.
sealed class WorldEvent {
  const WorldEvent();

  String get kind;

  Map<String, Object?> toJson();
}

final class ItemEquipped extends WorldEvent {
  const ItemEquipped({
    required this.member,
    required this.slot,
    required this.item,
  });

  final MemberRef member;
  final EquipSlot slot;
  final ItemRef item;

  @override
  String get kind => 'equipped';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'member': member.value,
    'slot': slot.name,
    'item': item.value,
  };
}

final class ItemUnequipped extends WorldEvent {
  const ItemUnequipped({
    required this.member,
    required this.slot,
    required this.item,
  });

  final MemberRef member;
  final EquipSlot slot;
  final ItemRef item;

  @override
  String get kind => 'unequipped';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'member': member.value,
    'slot': slot.name,
    'item': item.value,
  };
}

/// A two-handed weapon went on, so the off hand had to be emptied.
///
/// Its own event rather than a second [ItemUnequipped], because the
/// player did not ask for it and a screen should say so.
final class OffHandCleared extends WorldEvent {
  const OffHandCleared({required this.member, required this.item});

  final MemberRef member;
  final ItemRef item;

  @override
  String get kind => 'offHandCleared';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'member': member.value,
    'item': item.value,
  };
}

final class HandsSwapped extends WorldEvent {
  const HandsSwapped({required this.member});

  final MemberRef member;

  @override
  String get kind => 'handsSwapped';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'member': member.value};
}

final class StyleSet extends WorldEvent {
  const StyleSet({
    required this.member,
    required this.style,
    required this.thrift,
  });

  final MemberRef member;
  final FightingStyle style;
  final bool thrift;

  @override
  String get kind => 'styleSet';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'member': member.value,
    'style': style.name,
    'thrift': thrift,
  };
}

final class ItemGained extends WorldEvent {
  const ItemGained({required this.item, required this.count});

  final ItemRef item;
  final int count;

  @override
  String get kind => 'gained';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'item': item.value,
    'count': count,
  };
}

final class ItemLost extends WorldEvent {
  const ItemLost({required this.item, required this.count});

  final ItemRef item;
  final int count;

  @override
  String get kind => 'lost';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'item': item.value,
    'count': count,
  };
}

final class PartyReordered extends WorldEvent {
  const PartyReordered({required this.order});

  final List<MemberRef> order;

  @override
  String get kind => 'reordered';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'order': [for (final m in order) m.value],
  };
}

/// Nothing happened, and this is why.
final class CommandRefused extends WorldEvent {
  const CommandRefused({
    required this.reason,
    this.member,
    this.slot,
    this.item,
  });

  final RefusalReason reason;
  final MemberRef? member;
  final EquipSlot? slot;
  final ItemRef? item;

  @override
  String get kind => 'refused';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'reason': reason.name,
    if (member != null) 'member': member!.value,
    if (slot != null) 'slot': slot!.name,
    if (item != null) 'item': item!.value,
  };
}
