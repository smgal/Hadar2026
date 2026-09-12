import 'package:hd_world/hd_world.dart';

/// A command that could not be read, and why.
///
/// Decoding fails loudly. A request naming a slot that does not exist is
/// the caller's mistake and has to be reported as one — the legacy
/// scripting language returned zero for an unknown symbol and quietly
/// took the wrong branch for years.
class DecodeFailure implements Exception {
  DecodeFailure(this.message, {this.field, this.allowed});

  final String message;
  final String? field;
  final List<String>? allowed;

  Map<String, Object?> toJson() => {
    'error': message,
    if (field != null) 'field': field,
    if (allowed != null) 'allowed': allowed,
  };

  @override
  String toString() => 'DecodeFailure($message)';
}

T _enumByName<T>(
  String? raw,
  List<T> values,
  String Function(T) nameOf,
  String field,
) {
  if (raw == null) throw DecodeFailure('missing', field: field);
  for (final v in values) {
    if (nameOf(v) == raw) return v;
  }
  throw DecodeFailure(
    'unknown value',
    field: field,
    allowed: [for (final v in values) nameOf(v)],
  );
}

String _str(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw DecodeFailure('missing or not a string', field: field);
  }
  return value;
}

int _intOr(Map<String, Object?> json, String field, int fallback) {
  final value = json[field];
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw DecodeFailure('not a number', field: field);
}

EquipSlot _slot(Map<String, Object?> json) => _enumByName(
  json['slot'] as String?,
  EquipSlot.values,
  (s) => s.name,
  'slot',
);

/// Reads a command out of JSON.
///
/// The wire uses the `kind` string each command declares, so renaming a
/// Dart class is never an API change.
WorldCommand decodeCommand(Map<String, Object?> json) {
  final kind = json['kind'];
  if (kind is! String) {
    throw DecodeFailure('missing', field: 'kind', allowed: commandKinds);
  }
  switch (kind) {
    case 'equip':
      return EquipFromPack(
        member: MemberRef(_str(json, 'member')),
        slot: _slot(json),
        item: ItemRef(_str(json, 'item')),
      );
    case 'unequip':
      return UnequipToPack(
        member: MemberRef(_str(json, 'member')),
        slot: _slot(json),
      );
    case 'swapHands':
      return SwapHands(member: MemberRef(_str(json, 'member')));
    case 'setStyle':
      final thrift = json['thrift'];
      if (thrift != null && thrift is! bool) {
        throw DecodeFailure('not a boolean', field: 'thrift');
      }
      return SetStyle(
        member: MemberRef(_str(json, 'member')),
        style: _enumByName(
          json['style'] as String?,
          FightingStyle.values,
          (s) => s.name,
          'style',
        ),
        thrift: thrift as bool?,
      );
    case 'give':
      return GiveItem(
        item: ItemRef(_str(json, 'item')),
        count: _intOr(json, 'count', 1),
      );
    case 'take':
      return TakeItem(
        item: ItemRef(_str(json, 'item')),
        count: _intOr(json, 'count', 1),
      );
    case 'reorder':
      final order = json['order'];
      if (order is! List) throw DecodeFailure('missing', field: 'order');
      return ReorderParty(
        order: [
          for (final o in order)
            if (o is String)
              MemberRef(o)
            else
              throw DecodeFailure('not a string', field: 'order'),
        ],
      );
    default:
      throw DecodeFailure(
        'unknown command',
        field: 'kind',
        allowed: commandKinds,
      );
  }
}

/// Every `kind` the surface accepts. Served by the guide so a client
/// never has to guess.
const List<String> commandKinds = [
  'equip',
  'unequip',
  'swapHands',
  'setStyle',
  'give',
  'take',
  'reorder',
];
