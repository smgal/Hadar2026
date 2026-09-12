import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_world/hd_world.dart' as hw;

/// The prefix a consumable's reference carries in the world catalogue.
const String consumablePrefix = 'consumable.';

/// The battle's key for a carried item, or null if it is not something
/// the battle knows how to use.
///
/// ## The reference name is the mapping
///
/// A world reference reads `consumable.potion` and the battle knows it
/// as `potion`. Stripping the prefix is the whole translation — and it
/// is deliberately *not* a field on the catalogue row, because that
/// would put the battle's vocabulary inside a package that must not
/// know the battle exists. A test pins both lists against each other so
/// the convention cannot drift silently.
String? battleKeyOf(hw.ItemRef ref) {
  if (!ref.value.startsWith(consumablePrefix)) return null;
  final key = ref.value.substring(consumablePrefix.length);
  return hb.battleItems.containsKey(key) ? key : null;
}

/// The world reference for a battle key.
hw.ItemRef worldRefOf(String battleKey) =>
    hw.ItemRef('$consumablePrefix$battleKey');

/// The pack projected as `{battle key: count}`.
///
/// A projection, not the pack itself: the battle never touches what the
/// party carries. It reports what it spent and the world removes it.
Map<String, int> heldConsumables(hw.Pack pack) {
  final out = <String, int>{};
  for (final entry in pack.counts.entries) {
    final key = battleKeyOf(entry.key);
    if (key != null) out[key] = entry.value;
  }
  return out;
}

/// Commands that take the spent items out of the pack.
///
/// Returned rather than applied so the caller decides when the world
/// changes — and so a rejection comes back as an event like any other.
List<hw.WorldCommand> spendCommands(Map<String, int> consumed) => [
  for (final entry in consumed.entries)
    if (entry.value > 0)
      hw.TakeItem(item: worldRefOf(entry.key), count: entry.value),
];
